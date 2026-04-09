import SwiftUI

struct IPTVPlayerOverlay: View {
    let channel: IPTVChannel
    let program: EPGProgram?
    let use24HourTime: Bool

    var body: some View {
        VisionUIContainer(title: channel.name, subtitle: channel.groupTitle) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    AsyncImage(url: channel.logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Color.white.opacity(0.15)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Spacer()
                }

                if let program {
                    Text(program.title)
                        .font(.caption)
                        .lineLimit(1)
                    Text("\(formatTime(program.startDate)) - \(formatTime(program.endDate))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    WaveformProgressView(
                        progress: progress(for: program),
                        seed: channel.id + program.id,
                        barCount: 48
                    )
                    .frame(height: 18)
                }
            }
        }
    }

    private func progress(for program: EPGProgram) -> Double {
        let total = program.endDate.timeIntervalSince(program.startDate)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(program.startDate)
        return max(0, min(elapsed / total, 1))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .none
        formatter.dateStyle = .none
        formatter.dateFormat = use24HourTime ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}
