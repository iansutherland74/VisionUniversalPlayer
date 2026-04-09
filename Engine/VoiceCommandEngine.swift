import Foundation
import Combine

@MainActor
final class VoiceCommandEngine: ObservableObject {
    enum Command: String, CaseIterable, Identifiable {
        case playPause = "Play or pause"
        case seekForward = "Seek forward"
        case seekBackward = "Seek backward"
        case louder = "Volume up"
        case softer = "Volume down"
        case toggleHUD = "Toggle HUD"
        case toggleSubtitles = "Toggle subtitles"
        case nextTrack = "Next track"

        var id: String { rawValue }
    }

    @Published var isListening = false
    @Published var statusMessage = "Voice commands idle"
    @Published var lastTranscript = ""

    let supportedPhrases: [String] = [
        "play",
        "pause",
        "skip forward",
        "skip back",
        "volume up",
        "volume down",
        "show hud",
        "hide subtitles",
        "next audio"
    ]

    func startListening() {
        isListening = true
        statusMessage = "Listening for on-device command phrases"
        
        Task {
            await DebugEventBus.shared.post(
                category: .voice,
                severity: .info,
                message: "Voice listening started"
            )
        }
    }

    func stopListening() {
        isListening = false
        statusMessage = "Voice commands idle"
        Task {
            await DebugEventBus.shared.post(
                category: .voice,
                severity: .info,
                message: "Voice listening stopped"
            )
        }
    }

    func parse(transcript: String) -> Command? {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return nil }

        lastTranscript = normalized

        if normalized.contains("play") || normalized.contains("pause") {
            statusMessage = "Matched play/pause"
            Task {
                await DebugEventBus.shared.post(
                    category: .voice,
                    severity: .info,
                    message: "Voice command recognized",
                    context: ["command": "playPause", "transcript": normalized]
                )
            }
            return .playPause
        }
        if normalized.contains("forward") || normalized.contains("ahead") {
            statusMessage = "Matched seek forward"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "seekForward", "transcript": normalized]
                )
            }
            return .seekForward
        }
        if normalized.contains("back") || normalized.contains("rewind") {
            statusMessage = "Matched seek backward"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "seekBackward", "transcript": normalized]
                )
            }
            return .seekBackward
        }
        if normalized.contains("volume up") || normalized.contains("louder") {
            statusMessage = "Matched volume up"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "louder", "transcript": normalized]
                )
            }
            return .louder
        }
        if normalized.contains("volume down") || normalized.contains("quieter") || normalized.contains("softer") {
            statusMessage = "Matched volume down"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "softer", "transcript": normalized]
                )
            }
            return .softer
        }
        if normalized.contains("hud") || normalized.contains("stats") {
            statusMessage = "Matched HUD toggle"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "toggleHUD", "transcript": normalized]
                )
            }
            return .toggleHUD
        }
        if normalized.contains("subtitle") {
            statusMessage = "Matched subtitle toggle"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "toggleSubtitles", "transcript": normalized]
                )
            }
            return .toggleSubtitles
        }
        if normalized.contains("next audio") || normalized.contains("audio track") {
            statusMessage = "Matched next audio track"
            Task {
                await DebugCategory.voice.infoLog(
                    "Voice command recognized",
                    context: ["command": "nextTrack", "transcript": normalized]
                )
            }
            return .nextTrack
        }

        statusMessage = "No mapped voice command"
        Task {
            await DebugCategory.voice.traceLog(
                "No mapped voice command",
                context: ["transcript": normalized]
            )
        }
        return nil
    }
}
