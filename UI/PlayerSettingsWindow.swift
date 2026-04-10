import SwiftUI

/// Standalone settings window that floats independently of the player,
/// so the movie stays fully visible while settings are open.
struct PlayerSettingsWindow: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var sceneCoordinator: SceneCoordinator

    #if os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section("Playback") {
                    Picker("Mode", selection: $playerViewModel.selectedMode) {
                        ForEach(PlayerViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: playerViewModel.selectedMode) { _, newValue in
                        playerViewModel.switchMode(newValue)
                    }

                    Picker("Surface", selection: $playerViewModel.renderSurface) {
                        ForEach(VisionUIRenderSurface.allCases) { surface in
                            Text(surface.rawValue.capitalized).tag(surface)
                        }
                    }
                    .onChange(of: playerViewModel.renderSurface) { _, newSurface in
                        playerViewModel.switchRenderSurface(newSurface)
                    }
                }

                Section("Quick Toggles") {
                    Toggle("Show Subtitles", isOn: Binding(
                        get: { playerViewModel.subtitlesVisible },
                        set: { _ in playerViewModel.toggleSubtitlesVisible() }
                    ))

                    Toggle("Show HUD", isOn: $playerViewModel.isHUDVisible)

                    Toggle("Shuffle", isOn: Binding(
                        get: { playerViewModel.shuffleEnabled },
                        set: { _ in playerViewModel.toggleShuffleEnabled() }
                    ))

                    Toggle("Repeat All", isOn: Binding(
                        get: { playerViewModel.repeatAllEnabled },
                        set: { _ in playerViewModel.toggleRepeatAllEnabled() }
                    ))
                }

                Section("Panels") {
                    #if os(visionOS)
                    if supportsMultipleWindows {
                        Button("VR / 3D Controls") {
                            openWindow(id: SceneCoordinator.vrControlsWindowID)
                        }
                    } else {
                        NavigationLink("VR / 3D Controls") {
                            VRControlsView(playerModel: playerViewModel)
                        }
                    }
                    #endif

                    NavigationLink("Audio Settings") {
                        AudioSettingsView(playerViewModel: playerViewModel)
                    }

                    NavigationLink("HUD Settings") {
                        HUDSettingsView(playerViewModel: playerViewModel)
                    }

                    NavigationLink("Cinema Settings") {
                        CinemaModeSettingsView(playerViewModel: playerViewModel)
                    }

                    NavigationLink("Subtitle Search & Download") {
                        SubtitleWorkflowView(playerViewModel: playerViewModel)
                    }

                    NavigationLink("Queue / Playlist") {
                        QueueManagerView(playerViewModel: playerViewModel)
                    }
                    .disabled(!playerViewModel.canManageQueue)
                }

                Section("Voice Commands") {
                    Button(playerViewModel.voiceCommandEngine.isListening ? "Stop Listening" : "Start Listening") {
                        if playerViewModel.voiceCommandEngine.isListening {
                            playerViewModel.voiceCommandEngine.stopListening()
                        } else {
                            playerViewModel.voiceCommandEngine.startListening()
                        }
                    }

                    Text(playerViewModel.voiceCommandEngine.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        #if os(visionOS)
                        dismissWindow(id: SceneCoordinator.playerSettingsWindowID)
                        #endif
                    }
                }
            }
        }
    }
}
