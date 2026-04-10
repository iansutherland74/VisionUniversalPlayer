import Foundation
import AVFoundation
import Combine
import QuartzCore

final class AVFoundationEngine: NSObject, VideoOutputEngine {
    private enum TrackSelectionID {
        static let auto = "__auto__"
        static let off = "__off__"
    }

    var pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never> {
        pixelBufferSubject.eraseToAnyPublisher()
    }

    var dimensionPublisher: AnyPublisher<(width: Int32, height: Int32), Never> {
        dimensionSubject.eraseToAnyPublisher()
    }

    var playbackTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimeSubject.eraseToAnyPublisher()
    }

    var transportStatusPublisher: AnyPublisher<TransportStatus, Never> {
        transportStatusSubject.eraseToAnyPublisher()
    }

    private let pixelBufferSubject = PassthroughSubject<CVPixelBuffer, Never>()
    private let dimensionSubject = PassthroughSubject<(width: Int32, height: Int32), Never>()
    private let playbackTimeSubject = PassthroughSubject<TimeInterval, Never>()
    private let transportStatusSubject = CurrentValueSubject<TransportStatus, Never>(.idle)

    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var playbackTask: Task<Void, Never>?
    private var endObserver: NSObjectProtocol?
    private let playbackRateLock = NSLock()
    private var playbackRate: Double = 1.0
    private var baseVolume: Float = 1.0
    private var effectsProfile: AudioEffectsProfile = .flat
    private var audioTrackOptionsCache: [MediaTrackOption] = []
    private var subtitleTrackOptionsCache: [MediaTrackOption] = []
    private var audioOptionsByID: [String: AVMediaSelectionOption] = [:]
    private var subtitleOptionsByID: [String: AVMediaSelectionOption] = [:]

    deinit {
        stop()
    }

    func start(item: MediaItem, startAtSeconds: TimeInterval?) async {
        stop()
        transportStatusSubject.send(.connecting)
        await DebugCategory.decoder.infoLog(
            "Starting AVFoundation engine",
            context: [
                "url": item.url.absoluteString,
                "startAt": startAtSeconds.map { String(format: "%.3f", $0) } ?? "0"
            ]
        )

        let playerItem = AVPlayerItem(url: item.url)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: [
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        playerItem.add(output)

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true

        self.player = player
        self.videoOutput = output

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.transportStatusSubject.send(.stopped)
            Task {
                await DebugCategory.decoder.infoLog("AVFoundation playback reached end")
            }
        }

        playbackTask = Task { [weak self] in
            await self?.runPlaybackLoop(item: playerItem, player: player, output: output, startAtSeconds: startAtSeconds)
        }
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        player?.pause()
        player = nil
        videoOutput = nil
        transportStatusSubject.send(.stopped)
        Task {
            await DebugCategory.decoder.infoLog("AVFoundation engine stopped")
        }
    }

    func setPlaybackRate(_ rate: Double) {
        let clamped = Float(max(0.5, min(rate, 2.0)))
        playbackRateLock.lock()
        playbackRate = Double(clamped)
        playbackRateLock.unlock()

        if let player {
            player.rate = clamped
        }
        Task {
            await DebugCategory.decoder.traceLog(
                "Playback rate changed",
                context: ["rate": String(format: "%.2f", Double(clamped))]
            )
        }
    }

    func setVolume(_ value: Float) {
        baseVolume = max(0, min(value, 1))
        applyEffectiveVolume()
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }

    func setAudioEffects(_ effects: AudioEffectsProfile) {
        effectsProfile = effects.clamped()
        applyEffectiveVolume()
    }

    func availableAudioTracks() -> [MediaTrackOption] {
        audioTrackOptionsCache
    }

    func availableSubtitleTracks() -> [MediaTrackOption] {
        subtitleTrackOptionsCache
    }

    func selectAudioTrack(id: String?) {
        // mediaSelectionGroup(forMediaCharacteristic:) is unavailable on visionOS
        #if !os(visionOS)
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        else { return }

        if id == nil || id == TrackSelectionID.auto {
            item.selectMediaOptionAutomatically(in: group)
            Task {
                await DebugCategory.audioEngine.infoLog("Selected audio track: auto")
            }
            return
        }

        if let id, let option = audioOptionsByID[id] {
            item.select(option, in: group)
            Task {
                await DebugCategory.audioEngine.infoLog("Selected audio track", context: ["id": id])
            }
        }
        #endif
    }

    func selectSubtitleTrack(id: String?) {
        #if !os(visionOS)
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { return }

        if id == nil || id == TrackSelectionID.auto {
            item.selectMediaOptionAutomatically(in: group)
            Task {
                await DebugCategory.settings.infoLog("Selected subtitle track: auto")
            }
            return
        }

        if id == TrackSelectionID.off {
            item.select(nil, in: group)
            Task {
                await DebugCategory.settings.infoLog("Selected subtitle track: off")
            }
            return
        }

        if let id, let option = subtitleOptionsByID[id] {
            item.select(option, in: group)
            Task {
                await DebugCategory.settings.infoLog("Selected subtitle track", context: ["id": id])
            }
        }
        #endif
    }

    private func currentPlaybackRate() -> Float {
        playbackRateLock.lock()
        let value = Float(playbackRate)
        playbackRateLock.unlock()
        return value
    }

    private func applyEffectiveVolume() {
        guard let player else { return }

        let preampGain = powf(10.0, effectsProfile.preampDB / 20.0)
        var effective = baseVolume * preampGain

        if effectsProfile.normalizationEnabled {
            let target: Float = 0.82
            effective = (effective * 0.65) + (target * 0.35)
        }

        if effectsProfile.limiterEnabled {
            effective = min(effective, 0.92)
        }

        player.volume = max(0, min(effective, 1))
    }

    private func runPlaybackLoop(
        item: AVPlayerItem,
        player: AVPlayer,
        output: AVPlayerItemVideoOutput,
        startAtSeconds: TimeInterval?
    ) async {
        var sentDimensions = false
        var sentInitialConnected = false
        var lastTimeControlStatus: AVPlayer.TimeControlStatus?
        var stallAttempt = 0
        var readyStateStartHostTime: CFTimeInterval?
        let startupHostTime = CACurrentMediaTime()
        // Track the last status we emitted so we only send on change.
        var emittedStatus: TransportStatus = .connecting

        if let startAtSeconds, startAtSeconds > 0 {
            let start = CMTime(seconds: startAtSeconds, preferredTimescale: 600)
            await player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        player.play()
        player.rate = currentPlaybackRate()

        while !Task.isCancelled {
            switch item.status {
            case .unknown:
                // Some network streams can remain unknown indefinitely on visionOS.
                // Fail fast so decoder fallback can continue instead of infinite buffering.
                if !sentInitialConnected,
                   CACurrentMediaTime() - startupHostTime > 10.0 {
                    let message = "Timed out preparing stream"
                    transportStatusSubject.send(.failed(message: message))
                    await DebugCategory.decoder.errorLog(
                        "AVFoundation startup timeout",
                        context: ["timeoutSeconds": "10"]
                    )
                    return
                }
                break
            case .readyToPlay:
                if readyStateStartHostTime == nil {
                    readyStateStartHostTime = CACurrentMediaTime()
                }
                // item.status == readyToPlay means metadata is loaded; track
                // timeControlStatus changes to reflect real playback/buffering.
                let timeControlStatus = player.timeControlStatus
                if timeControlStatus != lastTimeControlStatus {
                    lastTimeControlStatus = timeControlStatus
                    switch timeControlStatus {
                    case .playing:
                        // Do not emit connected until first decoded frame arrives.
                        if sentInitialConnected && emittedStatus != .connected {
                            stallAttempt = 0
                            emittedStatus = .connected
                            transportStatusSubject.send(.connected)
                            await DebugCategory.decoder.infoLog("AVFoundation transport connected")
                        }
                    case .waitingToPlayAtSpecifiedRate:
                        if sentInitialConnected {
                            stallAttempt += 1
                            let nextDelay = min(2.0, 0.5 * Double(stallAttempt))
                            let reconnecting = TransportStatus.reconnecting(
                                attempt: stallAttempt,
                                maxAttempts: 8,
                                nextDelaySeconds: nextDelay
                            )
                            if emittedStatus != reconnecting {
                                emittedStatus = reconnecting
                                transportStatusSubject.send(reconnecting)
                            }
                        }
                    case .paused:
                        break
                    @unknown default:
                        break
                    }
                }

                // If no first frame appears after item is ready, fail fast so
                // PlayerViewModel can move to the next decoder candidate.
                if !sentInitialConnected,
                   let readyStateStartHostTime,
                   CACurrentMediaTime() - readyStateStartHostTime > 8.0 {
                    let message = "Timed out waiting for first video frame"
                    transportStatusSubject.send(.failed(message: message))
                    await DebugCategory.decoder.errorLog(
                        "AVFoundation first-frame timeout",
                        context: ["timeoutSeconds": "8"]
                    )
                    return
                }
            case .failed:
                let message = item.error?.localizedDescription ?? "AVPlayer item failed"
                transportStatusSubject.send(.failed(message: message))
                await DebugCategory.decoder.errorLog("AVFoundation item failed", context: ["error": message])
                return
            @unknown default:
                break
            }

            let currentTime = player.currentTime()
            if currentTime.isNumeric {
                playbackTimeSubject.send(currentTime.seconds)
            }

                // Use the host-clock-aligned item time so the output vends the frame
                // that should be displayed RIGHT NOW, not the raw playback position.
                let hostTime = CACurrentMediaTime()
                let displayItemTime = output.itemTime(forHostTime: hostTime)
                let queryTime = displayItemTime.isValid ? displayItemTime : currentTime
                if output.hasNewPixelBuffer(forItemTime: queryTime),
                   let pixelBuffer = output.copyPixelBuffer(forItemTime: queryTime, itemTimeForDisplay: nil) {
                    if !sentInitialConnected {
                        sentInitialConnected = true
                        stallAttempt = 0
                        refreshMediaSelectionCaches(for: item)
                        emittedStatus = .connected
                        transportStatusSubject.send(.connected)
                        await DebugCategory.decoder.infoLog("AVFoundation transport connected")
                    }
                if !sentDimensions {
                    sentDimensions = true
                    dimensionSubject.send((
                        width: Int32(CVPixelBufferGetWidth(pixelBuffer)),
                        height: Int32(CVPixelBufferGetHeight(pixelBuffer))
                    ))
                }
                pixelBufferSubject.send(pixelBuffer)
            }

            try? await Task.sleep(nanoseconds: 16_666_667)
        }
    }

    private func refreshMediaSelectionCaches(for item: AVPlayerItem) {
        audioTrackOptionsCache = [MediaTrackOption(id: TrackSelectionID.auto, title: "Audio: Auto")]
        subtitleTrackOptionsCache = [
            MediaTrackOption(id: TrackSelectionID.off, title: "Subtitles: Off"),
            MediaTrackOption(id: TrackSelectionID.auto, title: "Subtitles: Auto")
        ]
        audioOptionsByID = [:]
        subtitleOptionsByID = [:]

        #if !os(visionOS)
        if let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            for (index, option) in audioGroup.options.enumerated() {
                let title = option.displayName.isEmpty ? "Audio \(index + 1)" : option.displayName
                let id = "aud:\(index):\(title)"
                audioTrackOptionsCache.append(MediaTrackOption(id: id, title: title))
                audioOptionsByID[id] = option
            }
        }

        if let subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            for (index, option) in subtitleGroup.options.enumerated() {
                let title = option.displayName.isEmpty ? "Subtitle \(index + 1)" : option.displayName
                let id = "sub:\(index):\(title)"
                subtitleTrackOptionsCache.append(MediaTrackOption(id: id, title: title))
                subtitleOptionsByID[id] = option
            }
        }
        #endif
    }
}
