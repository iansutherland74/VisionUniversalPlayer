#if os(visionOS)
import ARKit
import RealityKit
import SwiftUI

@available(visionOS 1.0, *)
final class HeadTracker {
    enum State {
        case stopped
        case starting
        case running
    }

    private(set) var state: State = .stopped

    var transform: simd_float4x4? {
        guard state == .running,
              let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            return nil
        }
        return deviceAnchor.originFromAnchorTransform
    }

    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private var subscription: EventSubscription?

    func start(content: RealityViewContent, _ handler: @escaping (SceneEvents.Update) -> Void) {
        guard state == .stopped else { return }
        state = .starting
        Task {
            await DebugCategory.immersive.infoLog("HeadTracker starting")
        }

        Task {
            do {
                try await session.run([worldTracking])
                state = .running
                subscription = content.subscribe(to: SceneEvents.Update.self, handler)
                await DebugCategory.immersive.infoLog("HeadTracker running")
            } catch {
                state = .stopped
                await DebugCategory.immersive.errorLog(
                    "HeadTracker failed to start",
                    context: ["error": error.localizedDescription]
                )
            }
        }
    }

    func stop() {
        guard state != .stopped else { return }
        state = .stopped
        session.stop()
        subscription?.cancel()
        subscription = nil
        Task {
            await DebugCategory.immersive.infoLog("HeadTracker stopped")
        }
    }
}
#endif
