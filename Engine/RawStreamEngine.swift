import Foundation
import Combine
import CoreVideo
import CoreMedia

class RawStreamEngine: NSObject, VideoOutputEngine, VideoDecoderDelegate {
    private enum StreamConnectionError: LocalizedError {
        case invalidHTTPStatus(Int)
        case streamEnded
        case firstFrameTimeout

        var errorDescription: String? {
            switch self {
            case .invalidHTTPStatus(let statusCode):
                return "Invalid HTTP status: \(statusCode)"
            case .streamEnded:
                return "Stream ended unexpectedly"
            case .firstFrameTimeout:
                return "Timed out waiting for first decoded frame"
            }
        }
    }

    private let decoder = VideoDecoder()
    private let nalParser = NALParser()
    
    private let pixelBufferSubject = PassthroughSubject<CVPixelBuffer, Never>()
    private let dimensionSubject = PassthroughSubject<(width: Int32, height: Int32), Never>()
    private let playbackTimeSubject = PassthroughSubject<TimeInterval, Never>()
    private let transportStatusSubject = CurrentValueSubject<TransportStatus, Never>(.idle)
    
    var pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never> {
        return pixelBufferSubject.eraseToAnyPublisher()
    }
    
    var dimensionPublisher: AnyPublisher<(width: Int32, height: Int32), Never> {
        return dimensionSubject.eraseToAnyPublisher()
    }

    var playbackTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimeSubject.eraseToAnyPublisher()
    }

    var transportStatusPublisher: AnyPublisher<TransportStatus, Never> {
        transportStatusSubject.eraseToAnyPublisher()
    }
    
    private var urlSession: URLSession?
    private var decodingTask: Task<Void, Never>?
    private var isRunning = false
    private let playbackRateLock = NSLock()
    private var playbackRate: Double = 1.0
    private let reconnectBaseDelaySeconds: Double = 0.35
    private let reconnectMaxDelaySeconds: Double = 6.0
    private let firstFrameTimeoutSeconds: TimeInterval = 8.0
    private var hasEmittedConnected = false
    
    override init() {
        super.init()
        decoder.delegate = self
    }
    
    deinit {
        stop()
    }
    
    func start(item: MediaItem, startAtSeconds: TimeInterval?) async {
        isRunning = true
        hasEmittedConnected = false
        transportStatusSubject.send(.connecting)
        await DebugCategory.network.infoLog(
            "Starting raw stream engine",
            context: [
                "url": item.url.absoluteString,
                "codec": item.codec.rawValue,
                "startAt": startAtSeconds.map { String(format: "%.3f", $0) } ?? "0"
            ]
        )
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
        
        decodingTask = Task {
            await streamingLoop(item: item)
        }
    }
    
    func stop() {
        isRunning = false
        decodingTask?.cancel()
        decodingTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        decoder.reset()
        transportStatusSubject.send(.stopped)
        Task {
            await DebugCategory.network.infoLog("Raw stream engine stopped")
        }
    }

    func setPlaybackRate(_ rate: Double) {
        // Raw network stream pacing is source-driven; keep value for future
        // decoder-side frame dropping/duplication strategies.
        playbackRateLock.lock()
        playbackRate = max(0.25, min(rate, 4.0))
        playbackRateLock.unlock()
    }
    
    private func streamingLoop(item: MediaItem) async {
        var frameCounter = 0
        var reconnectAttempt = 0
        let maxReconnectAttempts = item.duration == nil ? 14 : 2
        var reachedFailure = false

        while isRunning {
            do {
                guard let urlSession else { break }

                let buffer = StreamBuffer(chunkSize: 64 * 1024)
                let (asyncData, response) = try await urlSession.bytes(from: item.url)

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw StreamConnectionError.invalidHTTPStatus(httpResponse.statusCode)
                }

                reconnectAttempt = 0
                await DebugCategory.network.infoLog(
                    "Raw stream transport connected (awaiting first frame)",
                    context: ["url": item.url.absoluteString]
                )
                var currentPTS: CMTime = .zero
                let connectionStartedAt = Date()

                for try await byte in asyncData {
                    if !isRunning { break }

                    if frameCounter == 0,
                       Date().timeIntervalSince(connectionStartedAt) > firstFrameTimeoutSeconds {
                        throw StreamConnectionError.firstFrameTimeout
                    }

                    buffer.append(byte)

                    if let nalUnits = try buffer.extractCompleteNALUnits() {
                        for nalUnit in nalUnits {
                            currentPTS = CMTime(
                                value: CMTimeValue(frameCounter * 1001),
                                timescale: 30000
                            )

                            switch item.codec {
                            case .h264:
                                decoder.decodeAnnexBH264(nalUnit.data, pts: currentPTS)
                            case .hevc:
                                decoder.decodeAnnexBHEVC(nalUnit.data, pts: currentPTS)
                            case .av1, .vp9, .vp8, .mpeg2:
                                await DebugCategory.decoder.errorLog(
                                    "Unsupported codec for raw engine",
                                    context: ["codec": item.codec.rawValue]
                                )
                                transportStatusSubject.send(.failed(message: "Raw Annex-B engine currently supports only H.264/HEVC"))
                                isRunning = false
                                break
                            }

                            if !isRunning { break }

                            frameCounter += 1
                        }
                    }
                }

                if isRunning {
                    throw StreamConnectionError.streamEnded
                }
            } catch is CancellationError {
                break
            } catch {
                if !isRunning { break }

                reconnectAttempt += 1
                if reconnectAttempt > maxReconnectAttempts {
                    await DebugCategory.network.errorLog(
                        "Streaming stopped after retries",
                        context: [
                            "attempts": String(reconnectAttempt - 1),
                            "maxAttempts": String(maxReconnectAttempts),
                            "error": error.localizedDescription
                        ]
                    )
                    transportStatusSubject.send(.failed(message: error.localizedDescription))
                    reachedFailure = true
                    break
                }

                let delaySeconds = reconnectDelaySeconds(forAttempt: reconnectAttempt)
                transportStatusSubject.send(
                    .reconnecting(
                        attempt: reconnectAttempt,
                        maxAttempts: maxReconnectAttempts,
                        nextDelaySeconds: delaySeconds
                    )
                )
                await DebugCategory.network.warningLog(
                    "Streaming reconnect scheduled",
                    context: [
                        "error": error.localizedDescription,
                        "delaySeconds": String(format: "%.2f", delaySeconds),
                        "attempt": String(reconnectAttempt),
                        "maxAttempts": String(maxReconnectAttempts)
                    ]
                )

                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        if isRunning {
            decoder.flush()
        }

        isRunning = false
        if !reachedFailure {
            transportStatusSubject.send(.stopped)
        }
    }

    private func reconnectDelaySeconds(forAttempt attempt: Int) -> Double {
        let exponential = reconnectBaseDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))
        let jitter = Double.random(in: 0.0...0.25)
        return min(reconnectMaxDelaySeconds, exponential) + jitter
    }
    
    // MARK: - VideoDecoderDelegate
    
    func decoderDidProducePixelBuffer(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        if isRunning {
            DispatchQueue.main.async {
                if !self.hasEmittedConnected {
                    self.hasEmittedConnected = true
                    self.transportStatusSubject.send(.connected)
                }
                self.pixelBufferSubject.send(pixelBuffer)
                if pts.isValid {
                    self.playbackTimeSubject.send(pts.seconds)
                }
            }
        }
    }
    
    func decoderDidUpdatePixelDimensions(width: Int32, height: Int32) {
        DispatchQueue.main.async {
            self.dimensionSubject.send((width: width, height: height))
        }
    }
    
    func decoderDidEncounterError(_ error: Error) {
        Task {
            await DebugCategory.decoder.errorLog(
                "Decoder callback error",
                context: ["error": error.localizedDescription]
            )
        }
    }
}

// MARK: - Stream Buffer

private class StreamBuffer {
    private var buffer: Data
    private let chunkSize: Int
    
    init(chunkSize: Int = 64 * 1024) {
        self.buffer = Data(capacity: chunkSize)
        self.chunkSize = chunkSize
    }
    
    func append(_ byte: UInt8) {
        buffer.append(byte)
    }
    
    func extractCompleteNALUnits() throws -> [NALUnit]? {
        guard buffer.count >= 4 else {
            return nil
        }
        
        let parser = NALParser()
        let units = parser.parseAnnexBStream(buffer)
        
        if units.isEmpty {
            return nil
        }
        
        // Find the last complete NAL unit and keep incomplete data
        var lastCompleteIndex = -1
        for (index, unit) in units.enumerated() {
            let endOfUnit = unit.startCodeLength + unit.data.count
            if endOfUnit <= buffer.count {
                lastCompleteIndex = index
            }
        }
        
        if lastCompleteIndex >= 0 {
            let completedUnits = Array(units[0...lastCompleteIndex])
            
            if let lastComplete = completedUnits.last {
                let lastCompleteEnd = lastComplete.startCodeLength + lastComplete.data.count
                buffer = Data(buffer.dropFirst(lastCompleteEnd))
            }
            
            return completedUnits
        }
        
        return nil
    }
}
