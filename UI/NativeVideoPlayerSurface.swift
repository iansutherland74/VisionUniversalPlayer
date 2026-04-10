import SwiftUI
import AVKit

final class NativePlayerController: ObservableObject {
    let player: AVPlayer

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying = false
    @Published var isMuted = false

    private var timeObserver: Any?
    private var isSeeking = false
    private var pendingSeekTarget: TimeInterval?
    private var shouldResumeAfterSeek = false

    init(url: URL) {
        self.player = AVPlayer(url: url)
        self.player.automaticallyWaitsToMinimizeStalling = true
        self.isMuted = player.isMuted
        attachTimeObserver()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: TimeInterval) {
        let maxDuration = duration > 0 ? duration : .greatestFiniteMagnitude
        let target = min(max(0, seconds), maxDuration)
        let time = CMTime(seconds: target, preferredTimescale: 600)
        let wasPlaying = isPlaying || player.timeControlStatus == .playing
        isSeeking = true
        pendingSeekTarget = target
        shouldResumeAfterSeek = wasPlaying
        currentTime = target

        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self else { return }
            DispatchQueue.main.async {
                if finished, let target = self.pendingSeekTarget {
                    self.currentTime = target
                }

                let shouldResume = self.shouldResumeAfterSeek
                self.pendingSeekTarget = nil
                self.isSeeking = false
                self.shouldResumeAfterSeek = false

                if shouldResume {
                    self.player.play()
                }

                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }

    func seekBy(delta seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    func toggleMute() {
        player.isMuted.toggle()
        isMuted = player.isMuted
    }

    private func attachTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if isSeeking == false, seconds.isFinite, seconds >= 0 {
                currentTime = seconds
            }

            if let item = player.currentItem {
                let durationSeconds = item.duration.seconds
                if durationSeconds.isFinite, durationSeconds >= 0 {
                    duration = durationSeconds
                }
            }

            isPlaying = player.timeControlStatus == .playing
            isMuted = player.isMuted
        }
    }
}

struct NativeVideoPlayerSurface: View {
    @ObservedObject var controller: NativePlayerController
    let shouldFillScreen: Bool

    var body: some View {
        NativeVideoPlayerLayerView(player: controller.player, shouldFillScreen: shouldFillScreen)
            .onAppear {
                controller.play()
            }
            .onDisappear {
                controller.pause()
            }
    }
}

#if os(visionOS)
private struct NativeVideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let shouldFillScreen: Bool

    func makeUIView(context: Context) -> PlayerLayerContainerView {
        let view = PlayerLayerContainerView()
        view.playerLayer.videoGravity = shouldFillScreen ? .resizeAspectFill : .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = shouldFillScreen ? .resizeAspectFill : .resizeAspect
    }
}

private final class PlayerLayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
#else
private struct NativeVideoPlayerLayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
    }
}
#endif
