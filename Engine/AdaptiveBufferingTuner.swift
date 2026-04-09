import Foundation

final class AdaptiveBufferingTuner {
    private var previousFrameTime: Date?
    private var intervalEMA: Double = 1.0 / 30.0
    private var jitterEMA: Double = 0.0
    private var bufferingMoments: Int = 0

    func reset() {
        previousFrameTime = nil
        intervalEMA = 1.0 / 30.0
        jitterEMA = 0.0
        bufferingMoments = 0
        Task {
            await DebugCategory.hls.traceLog("Adaptive buffering tuner reset")
        }
    }

    func recordFrameArrival(at timestamp: Date) {
        if let previousFrameTime {
            let interval = timestamp.timeIntervalSince(previousFrameTime)
            let clampedInterval = min(max(interval, 1.0 / 120.0), 0.5)
            let deviation = abs(clampedInterval - intervalEMA)

            intervalEMA = (intervalEMA * 0.9) + (clampedInterval * 0.1)
            jitterEMA = (jitterEMA * 0.85) + (deviation * 0.15)
        }

        previousFrameTime = timestamp
    }

    func thresholdSeconds(isTransportRecovering: Bool) -> TimeInterval {
        let cadenceTerm = intervalEMA * 6.2
        let jitterTerm = jitterEMA * 4.5
        let adaptiveBase = max(0.45, cadenceTerm + jitterTerm)
        let repeatedBufferingLift = min(Double(bufferingMoments) * 0.05, 0.35)
        let recoveryLift = isTransportRecovering ? 0.2 : 0.0

        return min(1.8, adaptiveBase + repeatedBufferingLift + recoveryLift)
    }

    func recordBufferingStateChange(isBuffering: Bool) {
        if isBuffering {
            bufferingMoments = min(bufferingMoments + 1, 8)
        } else {
            bufferingMoments = max(bufferingMoments - 1, 0)
        }
        Task {
            await DebugCategory.hls.traceLog(
                "Buffering state changed",
                context: [
                    "isBuffering": isBuffering ? "true" : "false",
                    "bufferingMoments": String(bufferingMoments)
                ]
            )
        }
    }
}