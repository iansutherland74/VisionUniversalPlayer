import SwiftUI

struct DetailView: View {
    let item: MediaItem
    let onPlay: (MediaItem) -> Void
    @EnvironmentObject private var favoritesStore: MediaFavoritesStore
    #if os(visionOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    #endif
    
    var body: some View {
        VStack(spacing: 24) {
            if let thumbnailURL = item.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(height: 280)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                        Text(item.codec.rawValue.uppercased())
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                    
                    if let duration = item.duration {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                            Text(formatDuration(duration))
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            Button(action: { onPlay(item) }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play Now")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()

            Button {
                favoritesStore.toggle(item)
            } label: {
                HStack {
                    Image(systemName: favoritesStore.isFavorite(item) ? "heart.fill" : "heart")
                    Text(favoritesStore.isFavorite(item) ? "Remove Favorite" : "Add to Favorites")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            #if os(visionOS)
            if favoritesStore.isFavorite(item) {
                Button {
                    if supportsMultipleWindows {
                        openWindow(id: SceneCoordinator.spotlightWindowID, value: item)
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles.tv")
                        Text(supportsMultipleWindows ? "Open Spotlight Window" : "Spotlight Requires Multi-Window")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!supportsMultipleWindows)
                .padding(.horizontal)
            }
            #endif
            
            Spacer()
        }
        .navigationTitle("Details")
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

#Preview {
    NavigationStack {
        DetailView(item: MediaItem.samples[0], onPlay: { _ in })
            .environmentObject(MediaFavoritesStore())
    }
}
