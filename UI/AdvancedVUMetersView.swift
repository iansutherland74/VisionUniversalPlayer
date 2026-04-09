import SwiftUI

/// Comprehensive stereo/surround VU meter display with per-channel visualization.
struct AdvancedVUMetersView: View {
    @ObservedObject var mixer: AudioMixer
    let showChannelLabels: Bool
    let showPeakHold: Bool

    @State private var leftPeakHoldValue: Double = 0
    @State private var rightPeakHoldValue: Double = 0
    @State private var centerPeakHoldValue: Double = 0
    @State private var surroundPeakHoldValue: Double = 0
    @State private var lastPeakUpdateTime = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let sample = mixer.sample(at: timeline.date)
            let timeSinceLastPeak = timeline.date.timeIntervalSince(lastPeakUpdateTime)

            VStack(alignment: .leading, spacing: 16) {
                Text("Audio Output")
                    .font(.headline)
                    .padding(.bottom, 4)

                // Stereo pair
                VStack(spacing: 12) {
                    channelMeterRow(
                        title: "Left",
                        rms: sample.leftRMS,
                        peak: sample.leftPeak,
                        peakHold: $leftPeakHoldValue,
                        showLabel: showChannelLabels,
                        showPeak: showPeakHold,
                        holdDuration: timeSinceLastPeak > 3 ? 0 : leftPeakHoldValue
                    )

                    channelMeterRow(
                        title: "Right",
                        rms: sample.rightRMS,
                        peak: sample.rightPeak,
                        peakHold: $rightPeakHoldValue,
                        showLabel: showChannelLabels,
                        showPeak: showPeakHold,
                        holdDuration: timeSinceLastPeak > 3 ? 0 : rightPeakHoldValue
                    )
                }

                // Center + Surround (if metadata indicates)
                if mixer.atmosMetadata.isAtmos {
                    Divider().opacity(0.2)

                    VStack(spacing: 12) {
                        channelMeterRow(
                            title: "Center",
                            rms: sample.centerRMS,
                            peak: sample.leftPeak * 0.8,
                            peakHold: $centerPeakHoldValue,
                            showLabel: showChannelLabels,
                            showPeak: showPeakHold,
                            holdDuration: timeSinceLastPeak > 3 ? 0 : centerPeakHoldValue
                        )

                        channelMeterRow(
                            title: "Surround",
                            rms: sample.surroundRMS,
                            peak: sample.rightPeak * 0.7,
                            peakHold: $surroundPeakHoldValue,
                            showLabel: showChannelLabels,
                            showPeak: showPeakHold,
                            holdDuration: timeSinceLastPeak > 3 ? 0 : surroundPeakHoldValue
                        )
                    }
                }

                // Atmos indicator
                if mixer.atmosMetadata.isAtmos {
                    Divider().opacity(0.2)
                    AtmosIndicator(metadata: mixer.atmosMetadata)
                }
            }
            .onChange(of: sample.leftPeak) { _, newValue in
                if newValue > leftPeakHoldValue {
                    withAnimation {
                        leftPeakHoldValue = newValue
                    }
                    lastPeakUpdateTime = timeline.date
                }
            }
            .onChange(of: sample.rightPeak) { _, newValue in
                if newValue > rightPeakHoldValue {
                    withAnimation {
                        rightPeakHoldValue = newValue
                    }
                    lastPeakUpdateTime = timeline.date
                }
            }
        }
    }

    @ViewBuilder
    private func channelMeterRow(
        title: String,
        rms: Double,
        peak: Double,
        peakHold: Binding<Double>,
        showLabel: Bool,
        showPeak: Bool,
        holdDuration: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if showLabel {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .frame(width: 48, alignment: .leading)
                }
                Spacer()
                Text(String(format: "%.0f%%", rms * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geometry.size.width * rms))

                    if showPeak && holdDuration > 0 {
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 2, height: 16)
                            .offset(x: max(0, min(geometry.size.width - 2, geometry.size.width * peakHold.wrappedValue)))
                    }
                }
            }
            .frame(height: 16)
        }
    }
}

/// Dolby Atmos indicator with metadata display.
struct AtmosIndicator: View {
    let metadata: AudioMixer.DolbyAtmosMetadata

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.circle.fill")
                    .font(.caption)
                Text("Atmos")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.3), in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(metadata.channelLayoutDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let objectCount = metadata.objectCount {
                    Text("Objects: \(objectCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AdvancedVUMetersView(
            mixer: AudioEngine().mixer,
            showChannelLabels: true,
            showPeakHold: true
        )
        .padding()
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
    .foregroundStyle(.white)
    .padding()
    .background(Color.black)
}
