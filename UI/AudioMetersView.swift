import SwiftUI

struct AudioMetersView: View {
    @ObservedObject var mixer: AudioMixer
    var showsNumbers = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12)) { timeline in
            let sample = mixer.sample(at: timeline.date)

            VStack(alignment: .leading, spacing: 12) {
                MeterRow(title: "Left", rms: sample.leftRMS, peak: sample.leftPeak)
                MeterRow(title: "Right", rms: sample.rightRMS, peak: sample.rightPeak)

                if showsNumbers {
                    HStack {
                        metricChip("Atmos", value: mixer.prefersDolbyAtmos ? "Preferred" : "Off")
                        metricChip("Mode", value: mixer.downmixMode.rawValue)
                        metricChip("Dialog", value: mixer.dialogEnhancementEnabled ? "Boost" : "Flat")
                    }
                }
            }
        }
    }

    private func metricChip(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MeterRow: View {
    let title: String
    let rms: Double
    let peak: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "RMS %.0f%%", rms * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 999)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.yellow, Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * rms))

                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 3, height: 20)
                        .offset(x: max(0, min(geometry.size.width - 3, geometry.size.width * peak)))
                }
            }
            .frame(height: 20)
        }
    }
}
