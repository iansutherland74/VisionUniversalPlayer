import SwiftUI

@main
struct VisionUniversalPlayerApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var sceneCoordinator = SceneCoordinator()
    
    // Initialize debug WebSocket server in DEBUG builds
    @State private var debugServer = {
        #if DEBUG
        _ = DebugWebSocketServer.shared // Trigger initialization
        #endif
        return ()
    }()

    var body: some Scene {
        WindowGroup {
            RootView(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
                #if os(visionOS)
                .windowGeometryPreferences(
                    minimumSize: CGSize(width: 480, height: 320),
                    resizingRestrictions: .uniform
                )
                #endif
        }

        #if os(visionOS)
        ImmersiveSpace(id: SceneCoordinator.immersivePlayerID) {
            ImmersivePlayerScene(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }

        WindowGroup(id: SceneCoordinator.spotlightWindowID, for: MediaItem.self) { $mediaItem in
            if let mediaItem {
                FavoriteSpotlightView(item: mediaItem, playerViewModel: playerViewModel)
                    .environmentObject(sceneCoordinator)
            } else {
                ContentUnavailableView("No media selected", systemImage: "rectangle.slash")
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.55, depth: 0.35, in: .meters)
        #endif
    }
}

