import SwiftUI

struct HUDSettingsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Visible Sections") {
                    Toggle("Video Stats", isOn: Binding(
                        get: { playerViewModel.hudSettings.showVideoStats },
                        set: { playerViewModel.setHUDShowVideoStats($0) }
                    ))
                    Toggle("Playback Diagnosis", isOn: Binding(
                        get: { playerViewModel.hudSettings.showPlaybackDiagnosis },
                        set: { playerViewModel.setHUDShowPlaybackDiagnosis($0) }
                    ))
                    Toggle("Audio Meters", isOn: Binding(
                        get: { playerViewModel.hudSettings.showAudioMeters },
                        set: { playerViewModel.setHUDShowAudioMeters($0) }
                    ))
                    Toggle("Spatial Details", isOn: Binding(
                        get: { playerViewModel.hudSettings.showSpatialDetails },
                        set: { playerViewModel.setHUDShowSpatialDetails($0) }
                    ))
                    Toggle("Pipeline Status", isOn: Binding(
                        get: { playerViewModel.hudSettings.showPipelineStatus },
                        set: { playerViewModel.setHUDShowPipelineStatus($0) }
                    ))
                    Toggle("Recommendations", isOn: Binding(
                        get: { playerViewModel.hudSettings.showRecommendations },
                        set: { playerViewModel.setHUDShowRecommendations($0) }
                    ))
                }

                Section("Presentation") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text(String(format: "%.0f%%", playerViewModel.hudSettings.opacity * 100))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { playerViewModel.hudSettings.opacity },
                                set: { playerViewModel.setHUDOpacity($0) }
                            ),
                            in: 0.25...1.0
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto-Hide")
                            Spacer()
                            Text(String(format: "%.0fs", playerViewModel.hudSettings.autoHideInterval))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { playerViewModel.hudSettings.autoHideInterval },
                                set: { playerViewModel.setHUDAutoHideInterval($0) }
                            ),
                            in: 2...12,
                            step: 1
                        )
                    }
                }
            }
            .navigationTitle("HUD Settings")
        }
    }
}
