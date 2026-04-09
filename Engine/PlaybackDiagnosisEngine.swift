import Foundation

enum DiagnosisSeverity: String {
    case info
    case warning
    case critical
}

struct PlaybackDiagnosis {
    let severity: DiagnosisSeverity
    let summary: String
    let recommendation: String
    let confidence: Double

    static let stable = PlaybackDiagnosis(
        severity: .info,
        summary: "Playback stable",
        recommendation: "No action needed",
        confidence: 0.9
    )
}

struct PlaybackObservation {
    let isBuffering: Bool
    let transportStatus: TransportStatus
    let stallRiskScore: Double
    let adaptiveThresholdSeconds: TimeInterval
}

protocol PlaybackDiagnosing {
    func diagnose(_ observation: PlaybackObservation) -> PlaybackDiagnosis
}

final class PlaybackDiagnosisEngine: PlaybackDiagnosing {
    func diagnose(_ observation: PlaybackObservation) -> PlaybackDiagnosis {
        switch observation.transportStatus {
        case .failed(let message):
            let diagnosis = PlaybackDiagnosis(
                severity: .critical,
                summary: "Transport failure",
                recommendation: "Verify stream URL or credentials. Last error: \(message)",
                confidence: 0.96
            )
            Task {
                await DebugCategory.network.errorLog(
                    "Playback diagnosis: transport failure",
                    context: ["message": message, "confidence": String(format: "%.2f", diagnosis.confidence)]
                )
            }
            return diagnosis

        case .reconnecting(let attempt, let maxAttempts, _):
            let diagnosis = PlaybackDiagnosis(
                severity: .warning,
                summary: "Reconnecting stream (\(attempt)/\(maxAttempts))",
                recommendation: "Wait briefly. If retries continue, switch source or lower stream quality.",
                confidence: min(0.6 + observation.stallRiskScore * 0.3, 0.92)
            )
            Task {
                await DebugCategory.network.warningLog(
                    "Playback diagnosis: reconnecting",
                    context: [
                        "attempt": String(attempt),
                        "maxAttempts": String(maxAttempts),
                        "confidence": String(format: "%.2f", diagnosis.confidence)
                    ]
                )
            }
            return diagnosis

        case .connecting:
            return PlaybackDiagnosis(
                severity: .info,
                summary: "Connecting",
                recommendation: "Handshake in progress.",
                confidence: 0.7
            )

        case .idle, .connected, .stopped:
            break
        }

        if observation.isBuffering {
            if observation.stallRiskScore >= 0.7 {
                let diagnosis = PlaybackDiagnosis(
                    severity: .critical,
                    summary: "Sustained buffering",
                    recommendation: "Lower quality or change source. Network throughput likely below stream demand.",
                    confidence: min(0.7 + observation.stallRiskScore * 0.25, 0.95)
                )
                Task {
                    await DebugCategory.hls.errorLog(
                        "Playback diagnosis: sustained buffering",
                        context: ["stallRisk": String(format: "%.3f", observation.stallRiskScore)]
                    )
                }
                return diagnosis
            }

            let diagnosis = PlaybackDiagnosis(
                severity: .warning,
                summary: "Transient buffering",
                recommendation: "Hold for recovery. Adaptive threshold is \(String(format: "%.2f", observation.adaptiveThresholdSeconds))s.",
                confidence: min(0.55 + observation.stallRiskScore * 0.25, 0.88)
            )
            Task {
                await DebugCategory.hls.warningLog(
                    "Playback diagnosis: transient buffering",
                    context: ["stallRisk": String(format: "%.3f", observation.stallRiskScore)]
                )
            }
            return diagnosis
        }

        if observation.stallRiskScore >= 0.7 {
            return PlaybackDiagnosis(
                severity: .warning,
                summary: "High stall risk",
                recommendation: "Preemptively reduce bitrate/resolution to avoid upcoming stalls.",
                confidence: min(0.6 + observation.stallRiskScore * 0.3, 0.9)
            )
        }

        if observation.stallRiskScore >= 0.4 {
            return PlaybackDiagnosis(
                severity: .info,
                summary: "Elevated stall risk",
                recommendation: "Monitor conditions. Keep current settings unless stutter appears.",
                confidence: 0.65
            )
        }

        return .stable
    }
}

final class PlaybackDiagnosisEngineMock: PlaybackDiagnosing {
    private(set) var diagnoseCalls: [PlaybackObservation] = []
    var stubbedResults: [PlaybackDiagnosis] = []
    var defaultResult: PlaybackDiagnosis = .stable

    func diagnose(_ observation: PlaybackObservation) -> PlaybackDiagnosis {
        diagnoseCalls.append(observation)
        if !stubbedResults.isEmpty {
            return stubbedResults.removeFirst()
        }
        return defaultResult
    }
}