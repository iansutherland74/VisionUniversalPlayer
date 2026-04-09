import SwiftUI

struct CinemaModeSettingsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Cinema Mode", isOn: Binding(
                        get: { playerViewModel.cinemaModeSettings.isEnabled },
                        set: { playerViewModel.setCinemaModeEnabled($0) }
                    ))
                }

                Section("Presentation") {
                    settingsSlider(
                        title: "Ambient Lighting",
                        value: Binding(
                            get: { playerViewModel.cinemaModeSettings.ambientLighting },
                            set: { playerViewModel.setCinemaAmbientLighting($0) }
                        ),
                        valueLabel: String(format: "%.0f%%", playerViewModel.cinemaModeSettings.ambientLighting * 100)
                    )

                    settingsSlider(
                        title: "Seat Distance",
                        value: Binding(
                            get: { playerViewModel.cinemaModeSettings.seatDistance },
                            set: { playerViewModel.setCinemaSeatDistance($0) }
                        ),
                        valueLabel: String(format: "%.0f%%", playerViewModel.cinemaModeSettings.seatDistance * 100)
                    )

                    settingsSlider(
                        title: "Screen Scale",
                        value: Binding(
                            get: { playerViewModel.cinemaModeSettings.screenScale },
                            set: { playerViewModel.setCinemaScreenScale($0) }
                        ),
                        range: 0.8...1.4,
                        valueLabel: String(format: "%.2fx", playerViewModel.cinemaModeSettings.screenScale)
                    )

                    settingsSlider(
                        title: "Screen Curvature",
                        value: Binding(
                            get: { playerViewModel.cinemaModeSettings.screenCurvature },
                            set: { playerViewModel.setCinemaScreenCurvature($0) }
                        ),
                        valueLabel: String(format: "%.0f%%", playerViewModel.cinemaModeSettings.screenCurvature * 100)
                    )

                    settingsSlider(
                        title: "Environment Dimming",
                        value: Binding(
                            get: { playerViewModel.cinemaModeSettings.environmentDimming },
                            set: { playerViewModel.setCinemaEnvironmentDimming($0) }
                        ),
                        valueLabel: String(format: "%.0f%%", playerViewModel.cinemaModeSettings.environmentDimming * 100)
                    )
                }

                Section {
                    Button("Reset Cinema Preset") {
                        playerViewModel.resetCinemaModeSettings()
                    }
                }
            }
            .navigationTitle("Cinema Mode")
        }
    }

    private func settingsSlider(title: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1, valueLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
