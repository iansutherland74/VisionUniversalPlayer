import Foundation

enum StallRiskLevel: String {
    case low
    case elevated
    case high
}

final class PlaybackStallPredictor {
    private var smoothedScore: Double = 0.0
    private var estimatedFrameIntervalSeconds: Double = 1.0 / 30.0
    private var previousFrameTime: Date?
    private var lastLoggedRiskLevel: StallRiskLevel = .low

    func reset() {
        smoothedScore = 0.0
        estimatedFrameIntervalSeconds = 1.0 / 30.0
        previousFrameTime = nil
        lastLoggedRiskLevel = .low
        Task {
            await DebugCategory.hls.traceLog("Playback stall predictor reset")
        }
    }

    func recordFrame(at timestamp: Date) {
        if let previousFrameTime {
            let frameInterval = timestamp.timeIntervalSince(previousFrameTime)
            let clamped = min(max(frameInterval, 1.0 / 120.0), 0.5)
            estimatedFrameIntervalSeconds = estimatedFrameIntervalSeconds * 0.9 + clamped * 0.1
        }
        previousFrameTime = timestamp
    }

    func score(now: Date, isBuffering: Bool, transportStatus: TransportStatus) -> Double {
        let sinceLastFrame: Double
        if let previousFrameTime {
            sinceLastFrame = now.timeIntervalSince(previousFrameTime)
        } else {
            sinceLastFrame = 0.0
        }

        let baselineInterval = max(estimatedFrameIntervalSeconds, 1.0 / 60.0)
        let frameGapFeature = min(max((sinceLastFrame / baselineInterval) - 1.0, 0.0), 4.0)
        let bufferingFeature = isBuffering ? 1.0 : 0.0

        let reconnectFeature: Double
        let failureFeature: Double
        switch transportStatus {
        case .reconnecting(let attempt, let maxAttempts, _):
            reconnectFeature = min(max(Double(attempt) / Double(max(maxAttempts, 1)), 0.1), 1.0)
            failureFeature = 0.0
        case .failed:
            reconnectFeature = 0.0
            failureFeature = 1.0
        case .connecting:
            reconnectFeature = 0.2
            failureFeature = 0.0
        case .idle, .connected, .stopped:
            reconnectFeature = 0.0
            failureFeature = 0.0
        }

        let logit = -2.1 + (0.72 * frameGapFeature) + (1.45 * bufferingFeature) + (1.25 * reconnectFeature) + (1.3 * failureFeature)
        let probability = 1.0 / (1.0 + exp(-logit))

        smoothedScore = (smoothedScore * 0.76) + (probability * 0.24)
        let clamped = min(max(smoothedScore, 0.0), 1.0)
        let currentLevel = level(for: clamped)
        if currentLevel != lastLoggedRiskLevel {
            lastLoggedRiskLevel = currentLevel
            Task {
                await DebugCategory.hls.infoLog(
                    "Playback stall risk level changed",
                    context: [
                        "level": currentLevel.rawValue,
                        "score": String(format: "%.3f", clamped)
                    ]
                )
            }
        }
        return clamped
    }

    func level(for score: Double) -> StallRiskLevel {
        if score >= 0.7 {
            return .high
        }
        if score >= 0.4 {
            return .elevated
        }
        return .low
    }
}