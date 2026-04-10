import SwiftUI

struct FavoriteSpotlightView: View {
    let item: MediaItem
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator

    #if os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.09, blue: 0.16),
                            Color(red: 0.08, green: 0.18, blue: 0.26),
                            Color(red: 0.16, green: 0.29, blue: 0.23)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 18) {
                Text("Spotlight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                if let thumbnailURL = item.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(0.08))
                        }
                    }
                    .frame(width: 340, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                }

                VStack(spacing: 8) {
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)

                    HStack(spacing: 8) {
                        badge(item.codec.rawValue.uppercased())
                        badge(item.vrFormat.description)
                        if let duration = item.duration {
                            badge(formatDuration(duration))
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        DebugCategory.navigation.infoLog(
                            "Play tapped in FavoriteSpotlightView",
                            context: ["title": item.title]
                        )
                        Task {
                            await playerViewModel.playMedia(item)
                            DebugCategory.navigation.infoLog(
                                "FavoriteSpotlightView playMedia completed",
                                context: ["title": item.title]
                            )
                        }
                        #if os(visionOS)
                        sceneCoordinator.selectedPlayerItem = item
                        sceneCoordinator.shouldShowPlayerWindow = true
                        openWindow(id: SceneCoordinator.playerWindowID)
                        #endif
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)

                    #if os(visionOS)
                    Button {
                        dismissWindow(id: SceneCoordinator.spotlightWindowID)
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    #endif
                }
            }
            .padding(28)
        }
        .padding(20)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    FavoriteSpotlightView(item: MediaItem.samples[0], playerViewModel: PlayerViewModel())
}
