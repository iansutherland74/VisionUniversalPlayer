import Foundation
import VideoToolbox
import CoreMedia

protocol VideoDecoderDelegate: AnyObject {
    func decoderDidProducePixelBuffer(_ pixelBuffer: CVPixelBuffer, pts: CMTime)
    func decoderDidUpdatePixelDimensions(width: Int32, height: Int32)
    func decoderDidEncounterError(_ error: Error)
}

final class VideoDecoder {
    weak var delegate: VideoDecoderDelegate?

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMFormatDescription?
    private var spsBuffer: Data?
    private var ppsBuffer: Data?
    private var vpsBuffer: Data?
    private var lastDimensions: (width: Int32, height: Int32)?

    private let nalParser = NALParser()
    private let queue = DispatchQueue(label: "com.visionuniversalplayer.decoder", qos: .userInitiated)
    private var loggedH264Ready = false
    private var loggedHEVCReady = false

    private static let vtParameterError: OSStatus = -12899

    deinit {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
        }
    }

    func decodeAnnexBH264(_ data: Data, pts: CMTime) {
        queue.async { [weak self] in
            self?.decodeH264Internal(data, pts: pts)
        }
    }

    private func decodeH264Internal(_ data: Data, pts: CMTime) {
        for unit in nalParser.parseAnnexBStream(data) {
            switch unit.type {
            case .sps:
                spsBuffer = unit.data
                recreateH264DecompressionSessionIfReady()
            case .pps:
                ppsBuffer = unit.data
                recreateH264DecompressionSessionIfReady()
            case .codeIDRSlice, .codeNonIDRSlice:
                decodeSlice(unit.data, pts: pts)
            default:
                break
            }
        }
    }

    private func recreateH264DecompressionSessionIfReady() {
        guard let spsData = spsBuffer, let ppsData = ppsBuffer else { return }

        var formatDesc: CMFormatDescription?
        let status: OSStatus = withUnsafeDataBytes([spsData, ppsData]) { ptrs, sizes in
            CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: ptrs.count,
                parameterSetPointers: ptrs.baseAddress!,
                parameterSetSizes: sizes,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDesc
            )
        }

        guard status == noErr, let formatDesc else {
            emitDecoderError(status)
            Task {
                await DebugCategory.decoder.errorLog(
                    "Failed to create H264 format description",
                    context: ["status": String(status)]
                )
            }
            return
        }

        createDecompressionSession(formatDesc: formatDesc, codecTag: "H264")
        if !loggedH264Ready {
            loggedH264Ready = true
            Task { await DebugCategory.decoder.infoLog("H264 decompression session ready") }
        }
    }

    func decodeAnnexBHEVC(_ data: Data, pts: CMTime) {
        queue.async { [weak self] in
            self?.decodeHEVCInternal(data, pts: pts)
        }
    }

    private func decodeHEVCInternal(_ data: Data, pts: CMTime) {
        for unit in nalParser.parseHEVCAnnexBStream(data) {
            switch unit.type {
            case .codeVps:
                vpsBuffer = unit.data
                recreateHEVCDecompressionSessionIfReady()
            case .codeSps:
                spsBuffer = unit.data
                recreateHEVCDecompressionSessionIfReady()
            case .codePps:
                ppsBuffer = unit.data
                recreateHEVCDecompressionSessionIfReady()
            case .codeTrailN, .codeTrailR, .codeIslN, .codeIslR,
                 .codeBlaWLP, .codeBlaWRadl, .codeBlaIdrWRadl, .codeIdrWRadl, .codeIdrNLP:
                decodeSlice(unit.data, pts: pts)
            default:
                break
            }
        }
    }

    private func recreateHEVCDecompressionSessionIfReady() {
        guard let spsData = spsBuffer, let ppsData = ppsBuffer else { return }

        var parameterSets: [Data] = []
        if let vpsData = vpsBuffer {
            parameterSets.append(vpsData)
        }
        parameterSets.append(spsData)
        parameterSets.append(ppsData)

        var formatDesc: CMFormatDescription?
        let status: OSStatus = withUnsafeDataBytes(parameterSets) { ptrs, sizes in
            CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: ptrs.count,
                parameterSetPointers: ptrs.baseAddress!,
                parameterSetSizes: sizes,
                nalUnitHeaderLength: 4,
                extensions: nil,
                formatDescriptionOut: &formatDesc
            )
        }

        guard status == noErr, let formatDesc else {
            emitDecoderError(status)
            Task {
                await DebugCategory.decoder.errorLog(
                    "Failed to create HEVC format description",
                    context: ["status": String(status)]
                )
            }
            return
        }

        createDecompressionSession(formatDesc: formatDesc, codecTag: "HEVC")
        if !loggedHEVCReady {
            loggedHEVCReady = true
            Task { await DebugCategory.decoder.infoLog("HEVC decompression session ready") }
        }
    }

    private func createDecompressionSession(formatDesc: CMFormatDescription, codecTag: String) {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
        if lastDimensions?.width != dimensions.width || lastDimensions?.height != dimensions.height {
            lastDimensions = (width: dimensions.width, height: dimensions.height)
            delegate?.decoderDidUpdatePixelDimensions(width: dimensions.width, height: dimensions.height)
        }

        self.formatDescription = formatDesc

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: Int(dimensions.width),
            kCVPixelBufferHeightKey as String: Int(dimensions.height)
        ]

        let callback: VTDecompressionOutputCallback = { refCon, _, status, _, imageBuffer, presentationTimeStamp, _ in
            guard status == noErr, let imageBuffer, let refCon else { return }
            let decoder = Unmanaged<VideoDecoder>.fromOpaque(refCon).takeUnretainedValue()
            decoder.delegate?.decoderDidProducePixelBuffer(imageBuffer, pts: presentationTimeStamp)
        }

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: nil,
            imageBufferAttributes: attributes as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            emitDecoderError(status)
            Task {
                await DebugCategory.decoder.errorLog(
                    "Failed to create \(codecTag) decompression session",
                    context: ["status": String(status)]
                )
            }
            return
        }

        decompressionSession = session
    }

    private func decodeSlice(_ data: Data, pts: CMTime) {
        guard let session = decompressionSession else { return }

        var sampleBuffer: CMSampleBuffer?
        let status = createSampleBuffer(&sampleBuffer, data: data, pts: pts, dts: pts)
        guard status == noErr, let sampleBuffer else {
            emitDecoderError(status)
            return
        }

        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            frameRefcon: nil,
            infoFlagsOut: nil
        )

        if decodeStatus != noErr {
            emitDecoderError(decodeStatus)
        }
    }

    private func createSampleBuffer(
        _ sampleBuffer: inout CMSampleBuffer?,
        data: Data,
        pts: CMTime,
        dts: CMTime
    ) -> OSStatus {
        guard let formatDesc = formatDescription else { return Self.vtParameterError }

        var nalData = Data(capacity: data.count + 4)
        var nalSize = UInt32(data.count).bigEndian
        nalData.append(Data(bytes: &nalSize, count: 4))
        nalData.append(data)

        var blockBuffer: CMBlockBuffer?
        let blockStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: nalData.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: nalData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == noErr, let blockBuffer else { return blockStatus }

        nalData.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(
                with: raw.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: nalData.count
            )
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1001, timescale: 30000),
            presentationTimeStamp: pts,
            decodeTimeStamp: dts
        )

        return CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
    }

    private func emitDecoderError(_ status: OSStatus) {
        delegate?.decoderDidEncounterError(NSError(domain: "VideoDecoder", code: Int(status), userInfo: nil))
    }

    func flush() {
        queue.async { [weak self] in
            if let session = self?.decompressionSession {
                VTDecompressionSessionFinishDelayedFrames(session)
            }
            Task { await DebugCategory.decoder.traceLog("Decoder flush invoked") }
        }
    }

    func reset() {
        queue.async { [weak self] in
            if let session = self?.decompressionSession {
                VTDecompressionSessionInvalidate(session)
            }
            self?.decompressionSession = nil
            self?.formatDescription = nil
            self?.spsBuffer = nil
            self?.ppsBuffer = nil
            self?.vpsBuffer = nil
            self?.lastDimensions = nil
            self?.loggedH264Ready = false
            self?.loggedHEVCReady = false
            Task { await DebugCategory.decoder.infoLog("Decoder reset") }
        }
    }
}

private func withUnsafeDataBytes<T>(
    _ dataList: [Data],
    _ body: (UnsafeBufferPointer<UnsafePointer<UInt8>>, [Int]) -> T
) -> T {
    let byteArrays = dataList.map { Array($0) }
    let sizes = byteArrays.map { $0.count }

    func recurse(_ index: Int, _ acc: [UnsafePointer<UInt8>]) -> T {
        if index == byteArrays.count {
            var ptrs = acc
            return ptrs.withUnsafeBufferPointer { body($0, sizes) }
        }

        return byteArrays[index].withUnsafeBufferPointer { bp in
            recurse(index + 1, acc + [bp.baseAddress!])
        }
    }

    return recurse(0, [])
}
