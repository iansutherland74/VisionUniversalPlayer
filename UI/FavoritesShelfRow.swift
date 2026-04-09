import SwiftUI

struct FavoritesShelfRow: View {
    let items: [MediaItem]
    let onItemSelected: (MediaItem) -> Void
    let onAddToQueue: ((MediaItem) -> Void)?
    let onPlayNext: ((MediaItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorites Shelf")
                    .font(.headline)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let timestamp = timeline.date.timeIntervalSinceReferenceDate
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(destination: DetailView(item: item, onPlay: onItemSelected)) {
                                FavoriteShelfCard(
                                    item: item,
                                    angle: shelfAngle(timestamp: timestamp, index: index)
                                )
                                .frame(width: 190)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Add to Queue") {
                                    onAddToQueue?(item)
                                }

                                Button("Play Next") {
                                    onPlayNext?(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func shelfAngle(timestamp: TimeInterval, index: Int) -> Double {
        let base = timestamp * 22.0
        let offset = Double(index) * 13.0
        return sin((base + offset) * .pi / 180.0) * 9.0
    }
}

private struct FavoriteShelfCard: View {
    let item: MediaItem
    let angle: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let thumbnailURL = item.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.25)
                        }
                    }
                    .frame(height: 118)
                    .clipped()
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.25))
                        .frame(height: 118)
                }

                Image(systemName: "heart.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Color.red.opacity(0.85), in: Circle())
                    .padding(8)
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(item.vrFormat.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        FavoritesShelfRow(items: Array(MediaItem.samples.prefix(3)), onItemSelected: { _ in }, onAddToQueue: nil, onPlayNext: nil)
    }
}
