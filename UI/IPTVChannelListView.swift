import SwiftUI

struct IPTVChannelListView: View {
    @ObservedObject var store: IPTVStore
    let onPlayChannel: (IPTVChannel) -> Void

    var body: some View {
        List {
            if store.isLoading && store.channels.isEmpty {
                ForEach(0..<8, id: \.self) { _ in
                    loadingRow
                }
            } else {
                ForEach(store.channels) { channel in
                    IPTVChannelRowView(store: store, channel: channel, onPlayChannel: onPlayChannel)
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.35))
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 140, height: 10)
            }

            Spacer()

            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 18, height: 18)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

private struct IPTVChannelRowView: View {
    @ObservedObject var store: IPTVStore
    let channel: IPTVChannel
    let onPlayChannel: (IPTVChannel) -> Void

    @State private var favoriteBurstTrigger = 0

    var body: some View {
        Button {
            store.selectedChannel = channel
            onPlayChannel(channel)
        } label: {
            HStack(spacing: 10) {
                AsyncImage(url: channel.logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.gray.opacity(0.35)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.body)
                        .lineLimit(1)

                    if channel.hasArchive {
                        Text(channel.archiveDays.map { "Archive \($0)d" } ?? "Archive")
                            .font(.caption2)
                            .foregroundStyle(.teal)
                    }

                    if let now = store.timeline().currentProgram(for: channel) {
                        Text(now.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    let isAddingFavorite = store.isFavorite(channel) == false
                    store.toggleFavorite(channel)
                    if isAddingFavorite {
                        favoriteBurstTrigger += 1
                    }
                } label: {
                    Image(systemName: store.isFavorite(channel) ? "star.fill" : "star")
                        .foregroundStyle(store.isFavorite(channel) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .particleBurstEffect(
                    trigger: favoriteBurstTrigger,
                    symbols: ["star", "sparkles", "circle.hexagongrid"],
                    tint: .yellow,
                    particleCount: 12
                )
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Stream URL") {
                Clipboard.copy(channel.streamURL.absoluteString)
            }
        }
    }
}
