import SwiftUI

@MainActor
final class SceneCoordinator: ObservableObject {
    enum ImmersiveState: String {
        case closed
        case inTransition
        case open
    }

    static let immersivePlayerID = "ImmersivePlayer"
    static let spotlightWindowID = "FavoriteSpotlight"

    @Published private(set) var immersiveState: ImmersiveState = .closed

    var isImmersiveOpen: Bool {
        immersiveState == .open
    }

    var isImmersiveTransitioning: Bool {
        immersiveState == .inTransition
    }

    func openImmersiveSpace(using action: @escaping () async -> Bool) async {
        guard immersiveState == .closed else { return }
        immersiveState = .inTransition
        await DebugCategory.immersive.infoLog("Opening immersive space")

        let opened = await action()
        if immersiveState == .inTransition {
            immersiveState = opened ? .open : .closed
            await DebugCategory.immersive.infoLog(
                "Open immersive space result",
                context: ["opened": opened ? "true" : "false"]
            )
        }
    }

    func dismissImmersiveSpace(using action: @escaping () async -> Void) async {
        guard immersiveState == .open else { return }
        immersiveState = .inTransition
        await DebugCategory.immersive.infoLog("Dismissing immersive space")
        await action()

        if immersiveState == .inTransition {
            immersiveState = .closed
            await DebugCategory.immersive.infoLog("Immersive space dismissed")
        }
    }

    func toggleImmersiveSpace(
        open openAction: @escaping () async -> Bool,
        dismiss dismissAction: @escaping () async -> Void
    ) async {
        switch immersiveState {
        case .closed:
            await openImmersiveSpace(using: openAction)
        case .open:
            await dismissImmersiveSpace(using: dismissAction)
        case .inTransition:
            break
        }
    }

    func immersiveSceneDidAppear() {
        immersiveState = .open
        Task {
            await DebugCategory.immersive.infoLog("Immersive scene appeared")
        }
    }

    func immersiveSceneDidDisappear() {
        immersiveState = .closed
        Task {
            await DebugCategory.immersive.infoLog("Immersive scene disappeared")
        }
    }
}
