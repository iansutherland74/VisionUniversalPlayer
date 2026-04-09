import Foundation

struct AdvisorySegment: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
}

struct AdvisoryStreamUpdate {
    let partialText: String
    let finalizedSegment: AdvisorySegment?
}

protocol PlaybackAdvisoryStreaming: AnyObject {
    func reset()
    func update(text: String, now: Date) -> AdvisoryStreamUpdate
}

final class PlaybackAdvisoryStreamer: PlaybackAdvisoryStreaming {
    private var activeText: String = ""
    private var partialLength: Int = 0
    private var hasCommittedActiveText = false

    func reset() {
        activeText = ""
        partialLength = 0
        hasCommittedActiveText = false
        Task {
            await DebugCategory.hud.traceLog("Playback advisory streamer reset")
        }
    }

    func update(text: String, now: Date) -> AdvisoryStreamUpdate {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            reset()
            return AdvisoryStreamUpdate(partialText: "", finalizedSegment: nil)
        }

        if normalized != activeText {
            activeText = normalized
            partialLength = 0
            hasCommittedActiveText = false
        }

        // Reveal text progressively to emulate real-time token streaming.
        let step = max(3, min(8, activeText.count / 8))
        partialLength = min(activeText.count, partialLength + step)
        let partial = String(activeText.prefix(partialLength))

        if partialLength == activeText.count, !hasCommittedActiveText {
            hasCommittedActiveText = true
            Task {
                await DebugCategory.hud.infoLog(
                    "Playback advisory finalized",
                    context: ["length": String(activeText.count)]
                )
            }
            return AdvisoryStreamUpdate(
                partialText: partial,
                finalizedSegment: AdvisorySegment(timestamp: now, text: activeText)
            )
        }

        return AdvisoryStreamUpdate(partialText: partial, finalizedSegment: nil)
    }
}

final class PlaybackAdvisoryStreamerMock: PlaybackAdvisoryStreaming {
    private(set) var resetCallCount = 0
    private(set) var updateCalls: [(text: String, now: Date)] = []
    var nextUpdates: [AdvisoryStreamUpdate] = []

    func reset() {
        resetCallCount += 1
    }

    func update(text: String, now: Date) -> AdvisoryStreamUpdate {
        updateCalls.append((text, now))
        if !nextUpdates.isEmpty {
            return nextUpdates.removeFirst()
        }
        return AdvisoryStreamUpdate(partialText: text, finalizedSegment: nil)
    }
}