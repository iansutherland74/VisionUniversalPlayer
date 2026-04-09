import Foundation
import Combine
import CoreVideo

final class FFmpegSoftwareEngine: VideoOutputEngine {
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

    private var decodingTask: Task<Void, Never>?
    private var isRunning = false
    private var handle: Int32 = -1
    private var pendingStartAtSeconds: TimeInterval?

    private let playbackRateLock = NSLock()
    private var playbackRate: Double = 1.0

    deinit {
        stop()
    }

    func start(item: MediaItem, startAtSeconds: TimeInterval?) async {
        stop()
        isRunning = true
        pendingStartAtSeconds = startAtSeconds
        transportStatusSubject.send(.connecting)
        await DebugCategory.demuxer.infoLog(
            "Starting FFmpeg software engine",
            context: [
                "url": item.url.absoluteString,
                "startAt": startAtSeconds.map { String(format: "%.3f", $0) } ?? "0"
            ]
        )

        decodingTask = Task { [weak self] in
            await self?.decodeLoop(item: item)
        }
    }

    func stop() {
        isRunning = false
        decodingTask?.cancel()
        decodingTask = nil

        if handle >= 0 {
            ffmpeg_sw_close(handle)
            handle = -1
        }

        transportStatusSubject.send(.stopped)
        Task {
            await DebugCategory.demuxer.infoLog("FFmpeg software engine stopped")
        }
    }

    func setPlaybackRate(_ rate: Double) {
        playbackRateLock.lock()
        playbackRate = max(0.5, min(rate, 2.0))
        playbackRateLock.unlock()
    }

    private func currentPlaybackRate() -> Double {
        playbackRateLock.lock()
        let current = playbackRate
        playbackRateLock.unlock()
        return current
    }

    private func decodeLoop(item: MediaItem) async {
        let openHandle = item.url.absoluteString.withCString { cString in
            ffmpeg_sw_open(cString)
        }

        guard openHandle >= 0 else {
            transportStatusSubject.send(.failed(message: "FFmpeg software decoder failed to open source"))
            await DebugCategory.demuxer.errorLog("FFmpeg software decoder failed to open source")
            isRunning = false
            return
        }

        handle = openHandle

        if let pendingStartAtSeconds, pendingStartAtSeconds > 0 {
            _ = ffmpeg_sw_seek_seconds(handle, pendingStartAtSeconds)
        }

        transportStatusSubject.send(.connected)
        await DebugCategory.demuxer.infoLog("FFmpeg software engine connected")

        var sentDimensions = false
        var lastPTS: Double?

        while isRunning, !Task.isCancelled {
            var dataPtr: UnsafeMutablePointer<UInt8>?
            var size: Int32 = 0
            var width: Int32 = 0
            var height: Int32 = 0
            var ptsSeconds: Double = 0

            let result = ffmpeg_sw_read_frame(
                handle,
                &dataPtr,
                &size,
                &width,
                &height,
                &ptsSeconds
            )

            if result < 0 {
                if result == -4 {
                    transportStatusSubject.send(.stopped)
                    await DebugCategory.demuxer.infoLog("FFmpeg software stream reached end")
                } else {
                    transportStatusSubject.send(.failed(message: "FFmpeg software decoder read failure (code: \(result))"))
                    await DebugCategory.decoder.errorLog(
                        "FFmpeg software decoder read failure",
                        context: ["code": String(result)]
                    )
                }
                isRunning = false
                break
            }

            guard let dataPtr, size > 0, width > 0, height > 0 else {
                continue
            }

            defer {
                ffmpeg_sw_free_frame(dataPtr)
            }

            if !sentDimensions {
                sentDimensions = true
                dimensionSubject.send((width: width, height: height))
            }

            if let pixelBuffer = makePixelBufferFromBGRA(
                bytes: dataPtr,
                width: Int(width),
                height: Int(height),
                byteCount: Int(size)
            ) {
                pixelBufferSubject.send(pixelBuffer)
            }

            playbackTimeSubject.send(ptsSeconds)

            if let lastPTS {
                let mediaDelta = max(0, min(1.0, ptsSeconds - lastPTS))
                if mediaDelta > 0 {
                    let rate = currentPlaybackRate()
                    let wallDelta = mediaDelta / max(rate, 0.5)
                    let nanos = UInt64(wallDelta * 1_000_000_000)
                    if nanos > 0 {
                        try? await Task.sleep(nanoseconds: nanos)
                    }
                }
            }
            lastPTS = ptsSeconds
        }

        if handle >= 0 {
            ffmpeg_sw_close(handle)
            handle = -1
        }
    }

    private func makePixelBufferFromBGRA(
        bytes: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        byteCount: Int
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let srcBytesPerRow = width * 4

        if bytesPerRow == srcBytesPerRow {
            memcpy(baseAddress, bytes, min(byteCount, bytesPerRow * height))
        } else {
            for row in 0..<height {
                let src = bytes.advanced(by: row * srcBytesPerRow)
                let dst = baseAddress.advanced(by: row * bytesPerRow)
                memcpy(dst, src, min(srcBytesPerRow, bytesPerRow))
            }
        }

        return pixelBuffer
    }
}
