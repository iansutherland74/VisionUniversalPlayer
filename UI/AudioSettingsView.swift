import SwiftUI

struct AudioSettingsView: View {
    @ObservedObject var playerViewModel: PlayerViewModel

    private let eqStepValues: [Float] = [-12, -9, -6, -3, 0, 3, 6, 9, 12]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Audio")
                        .font(.largeTitle.bold())

                    Text("Control spatial audio, Dolby Atmos preference, level metering, sync offsets, and the current DSP preset from one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Output Mode")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AudioMixer.DolbyAtmosMode.allCases) { mode in
                                AudioModeButton(
                                    title: mode.rawValue,
                                    systemImage: icon(for: mode),
                                    isSelected: playerViewModel.audioEngine.mixer.downmixMode == mode
                                ) {
                                    playerViewModel.setDolbyAtmosDownmixMode(mode)
                                }
                            }
                        }

                        Toggle("Prefer Dolby Atmos When Available", isOn: Binding(
                            get: { playerViewModel.audioEngine.mixer.prefersDolbyAtmos },
                            set: { playerViewModel.setPrefersDolbyAtmos($0) }
                        ))

                        Toggle("Dialog Enhancement", isOn: Binding(
                            get: { playerViewModel.audioEngine.mixer.dialogEnhancementEnabled },
                            set: { playerViewModel.setDialogEnhancementEnabled($0) }
                        ))
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meters")
                            .font(.headline)
                        AudioMetersView(mixer: playerViewModel.audioEngine.mixer)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("DSP")
                            .font(.headline)

                        Picker("Preset", selection: Binding(
                            get: { currentAudioPreset },
                            set: { playerViewModel.applyAudioEffectsPreset($0) }
                        )) {
                            ForEach(AudioEffectsPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preamp")
                                Spacer()
                                Text(String(format: "%+.1f dB", playerViewModel.audioEffectsProfile.preampDB))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(playerViewModel.audioEffectsProfile.preampDB) },
                                    set: { playerViewModel.setPreampDB(Float($0)) }
                                ),
                                in: -12...12,
                                step: 1
                            )
                        }

                        ForEach(Array(AudioEffectsProfile.bandFrequenciesHz.enumerated()), id: \.offset) { index, frequency in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(eqFrequencyLabel(frequency))
                                    Spacer()
                                    Text(String(format: "%+.0f dB", playerViewModel.audioEffectsProfile.bandGainsDB[index]))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(playerViewModel.audioEffectsProfile.bandGainsDB[index]) },
                                        set: { playerViewModel.setEqualizerBand(at: index, db: Float($0)) }
                                    ),
                                    in: -12...12,
                                    step: 1
                                )
                            }
                        }

                        HStack(spacing: 12) {
                            Toggle("Normalization", isOn: Binding(
                                get: { playerViewModel.audioEffectsProfile.normalizationEnabled },
                                set: { _ in playerViewModel.toggleNormalization() }
                            ))
                            Toggle("Limiter", isOn: Binding(
                                get: { playerViewModel.audioEffectsProfile.limiterEnabled },
                                set: { _ in playerViewModel.toggleLimiter() }
                            ))
                        }

                        Menu("Loudness Memory") {
                            Button("-2 dB") { playerViewModel.adjustLoudnessCompensation(by: -2) }
                            Button("-1 dB") { playerViewModel.adjustLoudnessCompensation(by: -1) }
                            Button("+1 dB") { playerViewModel.adjustLoudnessCompensation(by: 1) }
                            Button("+2 dB") { playerViewModel.adjustLoudnessCompensation(by: 2) }
                            Button("Reset for This Media") { playerViewModel.resetLoudnessCompensationForCurrentMedia() }
                            Button("Clear All Saved", role: .destructive) { playerViewModel.clearAllStoredLoudnessCompensation() }
                        }

                        Button("Reset EQ") {
                            playerViewModel.resetEqualizer()
                        }
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spatial Audio")
                            .font(.headline)
                        AudioSpatialControls(playerViewModel: playerViewModel)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 18) {
                        AudioSyncView(playerViewModel: playerViewModel)
                        Divider()
                        LipSyncCalibrationView(playerViewModel: playerViewModel)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .padding()
            }
            .navigationTitle("Audio Settings")
        }
    }

    private var currentAudioPreset: AudioEffectsPreset {
        AudioEffectsPreset.allCases.first(where: { preset in
            preset.profile.bandGainsDB == playerViewModel.audioEffectsProfile.bandGainsDB
        }) ?? .flat
    }

    private func icon(for mode: AudioMixer.DolbyAtmosMode) -> String {
        switch mode {
        case .auto:
            return "waveform.badge.magnifyingglass"
        case .native:
            return "hifispeaker.2"
        case .multichannelPCM:
            return "square.split.2x2"
        case .stereoDownmix:
            return "speaker.wave.2"
        }
    }

    private func eqFrequencyLabel(_ frequency: Int) -> String {
        if frequency >= 1000 {
            return String(format: "%.1fkHz", Double(frequency) / 1000.0)
        }
        return "\(frequency)Hz"
    }
}
