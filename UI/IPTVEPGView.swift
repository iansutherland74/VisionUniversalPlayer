import SwiftUI

struct IPTVEPGView: View {
    @ObservedObject var store: IPTVStore
    let use24HourTime: Bool
    let onPlayChannel: (IPTVChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EPG Timeline")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if let channel = store.selectedChannel {
                let now = Date()
                let channelPrograms = store.timeline().programs(for: channel)
                let recentPrograms = store.timeline().recentPrograms(for: channel, count: 8, before: now)
                let upcomingPrograms = store.timeline().upcomingPrograms(for: channel, count: 8, from: now)

                List {
                    if store.isEPGLoading && channelPrograms.isEmpty {
                        Section("Loading Guide") {
                            ForEach(0..<6, id: \.self) { _ in
                                epgLoadingRow
                            }
                        }
                    } else {
                        if recentPrograms.isEmpty == false {
                            Section("Recent") {
                                ForEach(recentPrograms) { program in
                                    row(channel: channel, program: program)
                                }
                            }
                        }

                        if upcomingPrograms.isEmpty == false {
                            Section("Upcoming") {
                                ForEach(upcomingPrograms) { program in
                                    row(channel: channel, program: program)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Select a Channel", systemImage: "tv", description: Text("Choose a channel to see its EPG timeline."))
            }
        }
    }

    private var epgLoadingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 220, height: 14)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.25))
                .frame(width: 170, height: 11)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 10)
        }
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
        .shimmering()
    }

    @ViewBuilder
    private func row(channel: IPTVChannel, program: EPGProgram) -> some View {
        let isPast = program.endDate <= Date()

        VStack(alignment: .leading, spacing: 6) {
            Text(program.title)
                .font(.subheadline)

            Text("\(formatTime(program.startDate)) - \(formatTime(program.endDate))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if program.details.isEmpty == false {
                Text(program.details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if isPast && store.canPlayCatchup(for: channel, program: program) {
                Button("Play Catchup") {
                    guard let catchup = store.catchupChannel(for: channel, program: program) else { return }
                    store.selectedChannel = catchup
                    onPlayChannel(catchup)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else if isPast, let reason = store.catchupUnavailableReason(for: channel, program: program) {
                Label(reason, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
