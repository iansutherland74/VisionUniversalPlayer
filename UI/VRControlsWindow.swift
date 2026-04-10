import SwiftUI

/// Standalone floating window for VR/3D controls so it doesn't overlap the movie.
struct VRControlsWindow: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var sceneCoordinator: SceneCoordinator

    #if os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VRControlsView(playerModel: playerViewModel)
                    .padding()
            }
            .navigationTitle("VR / 3D Controls")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        #if os(visionOS)
                        dismissWindow(id: SceneCoordinator.vrControlsWindowID)
                        #endif
                    }
                }
            }
        }
    }
}
