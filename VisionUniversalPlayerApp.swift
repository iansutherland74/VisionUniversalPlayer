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
        WindowGroup(id: SceneCoordinator.mainWindowID) {
            RootView(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }
        #if os(visionOS)
        .defaultSize(width: 1200, height: 800)
        #endif

        #if os(visionOS)
        WindowGroup(id: SceneCoordinator.playerWindowID) {
            PlayerWindowContainer(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }
        .defaultSize(width: 1680, height: 1080)

        ImmersiveSpace(id: SceneCoordinator.immersivePlayerID) {
            ImmersivePlayerScene(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }

        WindowGroup(id: SceneCoordinator.spotlightWindowID, for: MediaItem.self) { $mediaItem in
            SpotlightWindowContainer(playerViewModel: playerViewModel, mediaItem: $mediaItem)
                .environmentObject(sceneCoordinator)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.8, height: 0.55, depth: 0.35, in: .meters)

        WindowGroup(id: SceneCoordinator.playerSettingsWindowID) {
            PlayerSettingsWindowContainer(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }
        .defaultSize(width: 480, height: 560)

        WindowGroup(id: SceneCoordinator.snapshotWindowID) {
            SnapshotGalleryWindowContainer(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }
        .defaultSize(width: 920, height: 680)

        WindowGroup(id: SceneCoordinator.vrControlsWindowID) {
            VRControlsWindowContainer(playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        }
        .defaultSize(width: 380, height: 640)
        #endif
    }
}

#if os(visionOS)
/// Reactive wrapper so the player window responds to SceneCoordinator changes.
/// The scene closure in WindowGroup is NOT reactive; a SwiftUI View body IS.
struct PlayerWindowContainer: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        if sceneCoordinator.shouldShowPlayerWindow, let item = sceneCoordinator.selectedPlayerItem {
            PlayerScreen(item: item, playerViewModel: playerViewModel)
                .onAppear {
                    sceneCoordinator.playerWindowVisible = true
                    DebugCategory.navigation.infoLog(
                        "PlayerWindowContainer showing PlayerScreen",
                        context: ["title": item.title]
                    )
                }
                .onDisappear {
                    sceneCoordinator.playerWindowVisible = false
                    sceneCoordinator.shouldShowPlayerWindow = false
                    sceneCoordinator.selectedPlayerItem = nil
                    DebugCategory.navigation.infoLog("PlayerWindowContainer PlayerScreen disappeared")
                }
        } else {
            EmptyView()
                .onAppear {
                    // During open-window transitions, selectedPlayerItem can lag one render pass.
                    // Never dismiss in that transient state or the player window may close immediately.
                    if sceneCoordinator.shouldShowPlayerWindow {
                        DebugCategory.navigation.infoLog(
                            "PlayerWindowContainer waiting for selected item during open transition"
                        )
                        return
                    }

                    sceneCoordinator.playerWindowVisible = false
                    if !sceneCoordinator.hasInitializedWindows {
                        sceneCoordinator.hasInitializedWindows = true
                    } else {
                        dismissWindow(id: SceneCoordinator.playerWindowID)
                        DebugCategory.navigation.warningLog(
                            "PlayerWindowContainer auto-dismissed empty player window"
                        )
                    }
                }
        }
    }
}

struct PlayerSettingsWindowContainer: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        if sceneCoordinator.shouldShowPlayerWindow {
            PlayerSettingsWindow(playerViewModel: playerViewModel)
                .onAppear {
                    DebugCategory.navigation.infoLog("PlayerSettingsWindowContainer appearing - showing settings")
                }
        } else {
            EmptyView()
                .onAppear {
                    // On first app launch, aggressively dismiss any restored windows
                    if !sceneCoordinator.hasInitializedWindows {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            DebugCategory.navigation.infoLog("PlayerSettingsWindowContainer - dismissing restored window on startup")
                            dismissWindow(id: SceneCoordinator.playerSettingsWindowID)
                            sceneCoordinator.hasInitializedWindows = true
                        }
                    }
                }
        }
    }
}

struct SnapshotGalleryWindowContainer: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        if sceneCoordinator.shouldShowPlayerWindow {
            SnapshotGalleryView(playerViewModel: playerViewModel)
                .onAppear {
                    DebugCategory.navigation.infoLog("SnapshotGalleryWindowContainer appearing - showing snapshots")
                }
        } else {
            EmptyView()
                .onAppear {
                    // On first app launch, aggressively dismiss any restored windows
                    if !sceneCoordinator.hasInitializedWindows {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            DebugCategory.navigation.infoLog("SnapshotGalleryWindowContainer - dismissing restored window on startup")
                            dismissWindow(id: SceneCoordinator.snapshotWindowID)
                        }
                    }
                }
        }
    }
}

struct VRControlsWindowContainer: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        if sceneCoordinator.shouldShowPlayerWindow {
            VRControlsWindow(playerViewModel: playerViewModel)
                .onAppear {
                    DebugCategory.navigation.infoLog("VRControlsWindowContainer appearing - showing VR controls")
                }
        } else {
            EmptyView()
                .onAppear {
                    // On first app launch, aggressively dismiss any restored windows
                    if !sceneCoordinator.hasInitializedWindows {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            DebugCategory.navigation.infoLog("VRControlsWindowContainer - dismissing restored window on startup")
                            dismissWindow(id: SceneCoordinator.vrControlsWindowID)
                        }
                    }
                }
        }
    }
}

struct SpotlightWindowContainer: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @Environment(\.dismissWindow) private var dismissWindow
    @Binding var mediaItem: MediaItem?

    var body: some View {
        if sceneCoordinator.shouldShowPlayerWindow, let mediaItem {
            FavoriteSpotlightView(item: mediaItem, playerViewModel: playerViewModel)
                .environmentObject(sceneCoordinator)
        } else {
            EmptyView()
        }
    }
}
#endif

