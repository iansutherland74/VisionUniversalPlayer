import SwiftUI

struct IPTVFavoritesView: View {
    @ObservedObject var store: IPTVStore
    let onPlayChannel: (IPTVChannel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            if store.favoriteChannels.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Star channels to keep them here for quick access."))
            } else {
                List(store.favoriteChannels) { channel in
                    Button {
                        store.selectedChannel = channel
                        onPlayChannel(channel)
                    } label: {
                        HStack {
                            Text(channel.name)
                            if channel.hasArchive {
                                Text(channel.archiveDays.map { "\($0)d" } ?? "ARCH")
                                    .font(.caption2)
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Copy Stream URL") {
                            Clipboard.copy(channel.streamURL.absoluteString)
                        }
                    }
                }
            }
        }
    }
}
