import Foundation
import Combine

/// WebSocket server that broadcasts debug events to connected clients.
/// Uses the VS Code extension relay on localhost:9002 in DEBUG builds.
/// The app sends structured debug events to the extension websocket server.
@MainActor
final class DebugWebSocketServer: DebugObserver {
    static let relayPort: UInt16 = 9002
    static let shared = DebugWebSocketServer()
    
    private var isRunning = false
    private var relaySocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let queue = DispatchQueue(label: "com.vision.websocket", qos: .default)
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private static let maxReconnectAttempts = 5
    
    private init() {
        #if DEBUG
        startServer()
        #endif
    }
    
    #if DEBUG
    private func startServer() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.isRunning = true
            DispatchQueue.main.async {
                DebugEventBus.shared.addObserver(self)
            }
            self.connectToExtensionRelay()
            
            DispatchQueue.main.async {
                DebugCategory.system.infoLog(
                    "Debug WebSocket relay started on ws://localhost:\(Self.relayPort)",
                    context: ["relayPort": "\(Self.relayPort)"]
                )
            }
        }
    }

    private func connectToExtensionRelay() {
        guard isRunning else { return }
        guard reconnectAttempts < Self.maxReconnectAttempts else {
            // Relay unreachable (physical device without tunnel). Stop trying.
            isRunning = false
            return
        }

        urlSession?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        urlSession = session

        guard let relayURL = URL(string: "ws://localhost:\(Self.relayPort)") else { return }

        let socket = session.webSocketTask(with: relayURL)
        relaySocket = socket
        reconnectAttempts += 1
        socket.resume()
    }

    private func reconnectRelay() {
        // Serialize all reconnect attempts on queue; skip if one is already pending.
        guard !isReconnecting else { return }
        isReconnecting = true
        let task = relaySocket
        relaySocket = nil
        task?.cancel(with: .goingAway, reason: nil)
        // Back off with a 3-second delay before retrying.
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            self.isReconnecting = false
            self.connectToExtensionRelay()
        }
    }
    #endif
    
    /// Send a debug event to the VS Code extension relay.
    nonisolated func onDebugEvent(_ event: DebugEvent) {
        queue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let json = event.toJSON()
            let message = URLSessionWebSocketTask.Message.string(json)

            guard let relaySocket = self.relaySocket else {
                self.connectToExtensionRelay()
                return
            }
            
            relaySocket.send(message) { [weak self] error in
                if let error {
                    DispatchQueue.main.async {
                        DebugCategory.system.warningLog(
                            "WebSocket relay send failed",
                            context: ["error": error.localizedDescription]
                        )
                    }
                    // Dispatch reconnect onto the serial queue to avoid races.
                    self?.queue.async { self?.reconnectRelay() }
                }
            }
        }
    }
    
    /// Stop the server (only used in shutdown scenarios).
    func stop() {
        isRunning = false
        queue.async { [weak self] in
            self?.relaySocket?.cancel(with: .goingAway, reason: nil)
            self?.relaySocket = nil
            self?.urlSession?.invalidateAndCancel()
            self?.urlSession = nil
        }
    }
}

// MARK: - Mock WebSocket Server for Testing

#if DEBUG
/// Lightweight HTTP + WebSocket server for development.
/// This runs in the background and accepts WebSocket connections on port 9001.
actor DebugWebSocketServerActor {
    static let shared = DebugWebSocketServerActor()
    
    nonisolated private let urlSession = URLSession(configuration: .default)
    private var listener: URLSessionWebSocketTask?
    
    /// Attempt to establish a WebSocket connection to the debug server.
    /// Used internally by VS Code extensions and debug tools.
    static func connectToRelayServer() -> URLSessionWebSocketTask? {
        let url = URL(string: "ws://localhost:\(DebugWebSocketServer.relayPort)")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 30
        
        let session = URLSession(configuration: config)
        let webSocket = session.webSocketTask(with: url)
        webSocket.resume()
        
        return webSocket
    }
}
#endif
