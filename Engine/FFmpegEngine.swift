import Foundation
import Combine
import CoreVideo
import CoreMedia

enum TransportStatus: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int, nextDelaySeconds: TimeInterval)
    case failed(message: String)
    case stopped
}

protocol VideoOutputEngine: AnyObject {
    var pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never> { get }
    var dimensionPublisher: AnyPublisher<(width: Int32, height: Int32), Never> { get }
    var playbackTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    var transportStatusPublisher: AnyPublisher<TransportStatus, Never> { get }
    func start(item: MediaItem, startAtSeconds: TimeInterval?) async
    func stop()
    func setPlaybackRate(_ rate: Double)
    func setVolume(_ value: Float)
    func setMuted(_ muted: Bool)
    func setAudioEffects(_ effects: AudioEffectsProfile)
    func availableAudioTracks() -> [MediaTrackOption]
    func availableSubtitleTracks() -> [MediaTrackOption]
    func selectAudioTrack(id: String?)
    func selectSubtitleTrack(id: String?)
}

extension VideoOutputEngine {
    func setPlaybackRate(_ rate: Double) {
        _ = rate
    }

    func setVolume(_ value: Float) {
        _ = value
    }

    func setMuted(_ muted: Bool) {
        _ = muted
    }

    func setAudioEffects(_ effects: AudioEffectsProfile) {
        _ = effects
    }

    func availableAudioTracks() -> [MediaTrackOption] {
        []
    }

    func availableSubtitleTracks() -> [MediaTrackOption] {
        []
    }

    func selectAudioTrack(id: String?) {
        _ = id
    }

    func selectSubtitleTrack(id: String?) {
        _ = id
    }
}

class FFmpegEngine: NSObject, VideoOutputEngine, VideoDecoderDelegate {
    private var demuxer: FFmpegDemuxer?
    private let decoder = VideoDecoder()
    
    private let pixelBufferSubject = PassthroughSubject<CVPixelBuffer, Never>()
    private let dimensionSubject = PassthroughSubject<(width: Int32, height: Int32), Never>()
    private let playbackTimeSubject = PassthroughSubject<TimeInterval, Never>()
    private let transportStatusSubject = CurrentValueSubject<TransportStatus, Never>(.idle)
    
    var pixelBufferPublisher: AnyPublisher<CVPixelBuffer, Never> {
        return pixelBufferSubject.eraseToAnyPublisher()
    }
    
    var dimensionPublisher: AnyPublisher<(width: Int32, height: Int32), Never> {
        return dimensionSubject.eraseToAnyPublisher()
    }

    var playbackTimePublisher: AnyPublisher<TimeInterval, Never> {
        playbackTimeSubject.eraseToAnyPublisher()
    }

    var transportStatusPublisher: AnyPublisher<TransportStatus, Never> {
        transportStatusSubject.eraseToAnyPublisher()
    }
    
    private var decodingTask: Task<Void, Never>?
    private var isRunning = false
    private let playbackRateLock = NSLock()
    private var playbackRate: Double = 1.0
    
    override init() {
        super.init()
        decoder.delegate = self
    }
    
    deinit {
        stop()
    }
    
    func start(item: MediaItem, startAtSeconds: TimeInterval?) async {
        isRunning = true
        transportStatusSubject.send(.connecting)
        await DebugCategory.demuxer.infoLog(
            "Starting FFmpeg engine",
            context: [
                "url": item.url.absoluteString,
                "codec": item.codec.rawValue,
                "startAt": startAtSeconds.map { String(format: "%.3f", $0) } ?? "0"
            ]
        )
        
        do {
            demuxer = try FFmpegDemuxer(url: item.url, codec: item.codec)
            if let startAtSeconds, startAtSeconds > 0 {
                try demuxer?.seek(to: startAtSeconds)
            }
            transportStatusSubject.send(.connected)
            await DebugCategory.demuxer.infoLog("FFmpeg demuxer connected")
        } catch {
            await DebugCategory.demuxer.errorLog(
                "Failed to create FFmpeg demuxer",
                context: ["error": error.localizedDescription]
            )
            transportStatusSubject.send(.failed(message: error.localizedDescription))
            isRunning = false
            return
        }
        
        decodingTask = Task {
            await decodingLoop()
        }
    }
    
    func stop() {
        isRunning = false
        decodingTask?.cancel()
        decodingTask = nil
        demuxer?.close()
        demuxer = nil
        decoder.reset()
        transportStatusSubject.send(.stopped)
        Task {
            await DebugCategory.demuxer.infoLog("FFmpeg engine stopped")
        }
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRateLock.lock()
        playbackRate = max(0.25, min(rate, 4.0))
        playbackRateLock.unlock()
    }

    private func currentPlaybackRate() -> Double {
        playbackRateLock.lock()
        let current = playbackRate
        playbackRateLock.unlock()
        return current
    }
    
    private func decodingLoop() async {
        var lastPTSSeconds: Double?
        while isRunning {
            do {
                guard let (nalData, pts) = try await demuxer?.nextPacket() else {
                    isRunning = false
                    break
                }

                if pts.isValid {
                    let ptsSeconds = pts.seconds
                    if let lastPTSSeconds {
                        let mediaDelta = max(0, min(1.0, ptsSeconds - lastPTSSeconds))
                        if mediaDelta > 0 {
                            let rate = currentPlaybackRate()
                            let wallDelta = mediaDelta / max(rate, 0.25)
                            let nanos = UInt64(max(0, wallDelta) * 1_000_000_000)
                            if nanos > 0 {
                                try? await Task.sleep(nanoseconds: nanos)
                            }
                        }
                    }
                    lastPTSSeconds = ptsSeconds
                }
                
                let codec = demuxer?.codec ?? .h264
                switch codec {
                case .h264:
                    decoder.decodeAnnexBH264(nalData, pts: pts)
                case .hevc:
                    decoder.decodeAnnexBHEVC(nalData, pts: pts)
                case .av1, .vp9, .vp8, .mpeg2:
                    await DebugCategory.decoder.errorLog(
                        "Unsupported codec for FFmpeg engine",
                        context: ["codec": codec.rawValue]
                    )
                    transportStatusSubject.send(.failed(message: "Codec \(codec.rawValue) requires AVFoundation fallback engine"))
                    isRunning = false
                }
            } catch {
                await DebugCategory.decoder.errorLog(
                    "Decoding loop error",
                    context: ["error": error.localizedDescription]
                )
                transportStatusSubject.send(.failed(message: error.localizedDescription))
                isRunning = false
                break
            }
        }
        
        decoder.flush()
    }
    
    // MARK: - VideoDecoderDelegate
    
    func decoderDidProducePixelBuffer(_ pixelBuffer: CVPixelBuffer, pts: CMTime) {
        if isRunning {
            DispatchQueue.main.async {
                self.pixelBufferSubject.send(pixelBuffer)
                if pts.isValid {
                    self.playbackTimeSubject.send(pts.seconds)
                }
            }
        }
    }
    
    func decoderDidUpdatePixelDimensions(width: Int32, height: Int32) {
        DispatchQueue.main.async {
            self.dimensionSubject.send((width: width, height: height))
        }
    }
    
    func decoderDidEncounterError(_ error: Error) {
        Task {
            await DebugCategory.decoder.errorLog(
                "Decoder callback error",
                context: ["error": error.localizedDescription]
            )
        }
    }
}
