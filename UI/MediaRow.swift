import SwiftUI

struct MediaRow: View {
    let title: String
    let items: [MediaItem]
    let onItemSelected: (MediaItem) -> Void
    let onAddToQueue: ((MediaItem) -> Void)?
    let onPlayNext: ((MediaItem) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(destination: DetailView(item: item, onPlay: onItemSelected)) {
                            MediaCard(item: item)
                                .frame(width: 200)
                        }
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

#Preview {
    MediaRow(
        title: "Featured",
        items: Array(MediaItem.samples.prefix(3)),
        onItemSelected: { _ in },
        onAddToQueue: nil,
        onPlayNext: nil
    )
}
