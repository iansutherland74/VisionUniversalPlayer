import AVFoundation
import Combine
import CoreMedia
import VideoToolbox

// Ported from sturmen/SpatialMediaKit — MV-HEVC stereo-tagged CMSampleBuffer demux.
// Key pattern: request both MVHEVC video layer IDs via
// kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs, then extract
// .stereoView(.leftEye) / .stereoView(.rightEye) from CMSampleBuffer.taggedBuffers.
//
// This engine is used for local MV-HEVC files (SourceKind.mvhevcLocal).
// It emits the left-eye CVPixelBuffer via pixelBufferPublisher (used by the 2D renderer)
// and left+right pairs via stereoPairPublisher (used by APMPFrameInjector for native stereo).

final class MVHEVCLocalEngine: VideoOutputEngine {

    // MARK: - VideoOutputEngine

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

    // MARK: - Stereo pair publisher (SpatialMediaKit-ported pattern)

    /// Emits (left, right) CVPixelBuffer pairs decoded from MV-HEVC tagged sample buffers.
    var stereoPairPublisher: AnyPublisher<(CVPixelBuffer, CVPixelBuffer), Never> {
        stereoPairSubject.eraseToAnyPublisher()
    }

    // MARK: - Private subjects

    private let pixelBufferSubject   = PassthroughSubject<CVPixelBuffer, Never>()
    private let dimensionSubject     = PassthroughSubject<(width: Int32, height: Int32), Never>()
    private let playbackTimeSubject  = PassthroughSubject<TimeInterval, Never>()
    private let transportStatusSubject = CurrentValueSubject<TransportStatus, Never>(.idle)
    private let stereoPairSubject    = PassthroughSubject<(CVPixelBuffer, CVPixelBuffer), Never>()

    private var readingTask: Task<Void, Never>?
    private let playbackRateLock = NSLock()
    private var playbackRate: Double = 1.0

    // MARK: - Start / Stop

    func start(item: MediaItem, startAtSeconds: TimeInterval?) async {
        transportStatusSubject.send(.connecting)
        await DebugCategory.decoder.infoLog(
            "Starting MV-HEVC local engine",
            context: [
                "url": item.url.absoluteString,
                "startAt": String(format: "%.3f", startAtSeconds ?? 0)
            ]
        )

        let url = item.url
        let startTime = startAtSeconds ?? 0

        readingTask = Task { [weak self] in
            await self?.read(url: url, startAt: startTime)
        }
    }

    func stop() {
        readingTask?.cancel()
        readingTask = nil
        transportStatusSubject.send(.stopped)
        Task {
            await DebugCategory.decoder.infoLog("MV-HEVC local engine stopped")
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

    // MARK: - AVAssetReader loop

    private func read(url: URL, startAt startSeconds: TimeInterval) async {
        let asset = AVURLAsset(url: url)

        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            transportStatusSubject.send(.failed(message: "No video track in MV-HEVC file"))
            await DebugCategory.decoder.errorLog("No video track in MV-HEVC file")
            return
        }

        // SpatialMediaKit key: request both MV-HEVC layer IDs so the decoder produces
        // tagged sample buffers containing both eye views.
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            AVVideoDecompressionPropertiesKey: [
                kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs: [0, 1] as CFArray
            ]
        ]

        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false

        guard let reader = try? AVAssetReader(asset: asset) else {
            transportStatusSubject.send(.failed(message: "Could not create AVAssetReader"))
            await DebugCategory.decoder.errorLog("Could not create AVAssetReader for MV-HEVC")
            return
        }

        // Seek to resume position if needed.
        if startSeconds > 0 {
            let startCMTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
            reader.timeRange = CMTimeRange(start: startCMTime, end: .positiveInfinity)
        }

        reader.add(trackOutput)

        guard reader.startReading() else {
            let reason = reader.error?.localizedDescription ?? "unknown"
            transportStatusSubject.send(.failed(message: "AVAssetReader failed to start: \(reason)"))
            await DebugCategory.decoder.errorLog("MV-HEVC reader failed to start", context: ["error": reason])
            return
        }

        // Emit dimensions from track
        let naturalSize = track.naturalSize
        dimensionSubject.send((width: Int32(naturalSize.width), height: Int32(naturalSize.height)))

        // Compute nominal frame interval for pacing (default 1/30s)
        let nominalFPS = track.nominalFrameRate
        let frameNanos: UInt64 = nominalFPS > 0
            ? UInt64(1_000_000_000.0 / Double(nominalFPS))
            : 33_333_333   // 30 fps fallback

        transportStatusSubject.send(.connected)
        await DebugCategory.decoder.infoLog("MV-HEVC engine connected")

        while reader.status == .reading {
            if Task.isCancelled { break }

            guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
                break
            }

            let pts = sampleBuffer.presentationTimeStamp
            if pts.isValid {
                playbackTimeSubject.send(CMTimeGetSeconds(pts))
            }

            // SpatialMediaKit demux: extract left and right eye from tagged buffers.
            if let left = pixelBuffer(sampleBuffer, eye: .leftEye),
               let right = pixelBuffer(sampleBuffer, eye: .rightEye) {
                pixelBufferSubject.send(left)
                stereoPairSubject.send((left, right))
            } else if let imageBuffer = sampleBuffer.imageBuffer {
                // Non-stereo file or undecoded stereo — emit single buffer.
                pixelBufferSubject.send(imageBuffer)
            }

            // Pace playback to wall clock (avoid reading at full decoder speed).
            let rate = currentPlaybackRate()
            let adjustedNanos = UInt64(Double(frameNanos) / max(rate, 0.25))
            try? await Task.sleep(nanoseconds: adjustedNanos)
        }

        if Task.isCancelled {
            transportStatusSubject.send(.stopped)
            await DebugCategory.decoder.infoLog("MV-HEVC read cancelled")
        } else if reader.status == .completed {
            transportStatusSubject.send(.stopped)
            await DebugCategory.decoder.infoLog("MV-HEVC read completed")
        } else if let err = reader.error {
            transportStatusSubject.send(.failed(message: err.localizedDescription))
            await DebugCategory.decoder.errorLog("MV-HEVC reader error", context: ["error": err.localizedDescription])
        }
    }

    // MARK: - Tagged buffer extraction (SpatialMediaKit pattern)

    /// Extract a CVPixelBuffer for the specified stereo eye from CMSampleBuffer.taggedBuffers.
    private func pixelBuffer(_ sampleBuffer: CMSampleBuffer, eye: CMStereoViewComponents) -> CVPixelBuffer? {
        guard let taggedBuffers = sampleBuffer.taggedBuffers else { return nil }

        let match = taggedBuffers.first { tagged in
            tagged.tags.first(matchingCategory: .stereoView) == .stereoView(eye)
        }

        guard let match else { return nil }
        if case .pixelBuffer(let pb) = match.buffer { return pb }
        return nil
    }
}
