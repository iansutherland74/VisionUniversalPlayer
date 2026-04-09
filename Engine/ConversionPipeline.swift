import Foundation
import Combine

// MARK: - BD_to_AVP port: named stage pipeline with start-stage resume
//
// Adapted from cbusillo/BD_to_AVP's 9-stage MV-HEVC conversion pipeline.
// Each stage is identified by name and raw integer value so the pipeline can
// be resumed from any point — mirroring BD_to_AVP's `--start-stage` flag.

/// Processing stages for video playback initialization.
/// Ordered by rawValue; the pipeline skips any stage whose rawValue is less
/// than the requested `startFrom` stage (BD_to_AVP `--start-stage` pattern).
enum ConversionStage: Int, CaseIterable, Sendable {
    case probeMetadata     = 1
    case resolveManifest   = 2
    case configureRenderer = 3
    case scheduleStereo    = 4
    case applyColorProfile = 5
    case initializeAudio   = 6
    case startEngine       = 7
    case beginStreaming     = 8

    var displayName: String {
        switch self {
        case .probeMetadata:     return "Probe Metadata"
        case .resolveManifest:   return "Resolve Manifest"
        case .configureRenderer: return "Configure Renderer"
        case .scheduleStereo:    return "Schedule Stereo"
        case .applyColorProfile: return "Apply Color Profile"
        case .initializeAudio:   return "Initialize Audio"
        case .startEngine:       return "Start Engine"
        case .beginStreaming:     return "Begin Streaming"
        }
    }
}

/// Events emitted by `ConversionPipeline` as each stage starts, completes,
/// or fails. Mirrors BD_to_AVP's stage-status reporting.
enum ConversionPipelineEvent {
    case started(ConversionStage)
    case completed(ConversionStage)
    case failed(ConversionStage, Error)
    case allComplete
}

/// A single step in the pipeline, binding a `ConversionStage` to an async
/// throwing closure. No-op closures are valid — some stages are structural
/// markers (analogous to BD_to_AVP stages that are skipped by config flags).
struct ConversionPipelineStep {
    let stage: ConversionStage
    let action: () async throws -> Void
}

/// Sequential named-stage pipeline. Stages with `rawValue` below `startFrom`
/// are skipped, enabling resume-from-stage (BD_to_AVP `--start-stage` flag).
/// Publishes `ConversionPipelineEvent` values for each stage transition.
@MainActor
final class ConversionPipeline {
    private let eventSubject = PassthroughSubject<ConversionPipelineEvent, Never>()
    private(set) var activeStage: ConversionStage?

    var events: AnyPublisher<ConversionPipelineEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Run `steps` in order. Steps before `startFrom` are skipped.
    /// Stops on the first failure and emits `.failed`; emits `.allComplete` if
    /// all applicable steps succeed.
    func run(steps: [ConversionPipelineStep], startFrom: ConversionStage = .probeMetadata) async {
        for step in steps {
            guard step.stage.rawValue >= startFrom.rawValue else { continue }
            activeStage = step.stage
            eventSubject.send(.started(step.stage))
            await DebugCategory.system.infoLog(
                "Conversion stage started",
                context: ["stage": step.stage.displayName, "stageValue": String(step.stage.rawValue)]
            )
            do {
                try await step.action()
                eventSubject.send(.completed(step.stage))
                await DebugCategory.system.infoLog(
                    "Conversion stage completed",
                    context: ["stage": step.stage.displayName, "stageValue": String(step.stage.rawValue)]
                )
            } catch {
                eventSubject.send(.failed(step.stage, error))
                await DebugCategory.system.errorLog(
                    "Conversion stage failed",
                    context: [
                        "stage": step.stage.displayName,
                        "stageValue": String(step.stage.rawValue),
                        "error": error.localizedDescription
                    ]
                )
                activeStage = nil
                return
            }
        }
        activeStage = nil
        eventSubject.send(.allComplete)
        await DebugCategory.system.infoLog("Conversion pipeline complete")
    }
}
