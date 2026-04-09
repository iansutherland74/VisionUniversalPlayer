import SwiftUI

struct YouTubePlayerSurface: View {
    let url: URL

    var body: some View {
        #if canImport(YouTubePlayerKit)
        YouTubePlayerSurfaceImplementation(url: url)
        #else
        ContentUnavailableView(
            "YouTube Playback Unavailable",
            systemImage: "play.rectangle",
            description: Text("Add YouTubePlayerKit as a Swift Package dependency to enable native YouTube playback.")
        )
        #endif
    }
}

#if canImport(YouTubePlayerKit)
import YouTubePlayerKit

private struct YouTubePlayerSurfaceImplementation: View {
    @StateObject private var player: YouTubePlayer

    init(url: URL) {
        let source = YouTubePlayer.Source(urlString: url.absoluteString)
            ?? YouTubeURL.videoID(from: url).map { .video(id: $0) }
            ?? .video(id: "dQw4w9WgXcQ")

        _player = StateObject(wrappedValue: YouTubePlayer(source: source))
    }

    var body: some View {
        YouTubePlayerView(player) { state in
            switch state {
            case .idle:
                ProgressView()
            case .ready:
                EmptyView()
            case .error(let error):
                ContentUnavailableView(
                    "YouTube Error",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text("\(error.localizedDescription)")
                )
            }
        }
    }
}
#endif
