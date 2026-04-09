import Foundation
import CoreMedia

final class PlayerStats: ObservableObject {
    @Published var videoWidth: Int = 0
    @Published var videoHeight: Int = 0
    @Published var codecName: String = "Unknown"
    @Published var bitrate: Int = 0
    @Published var framesPerSecond: Double = 0
    @Published var bufferedDuration: TimeInterval = 0
    @Published var adaptiveBufferingThreshold: TimeInterval = 0.7
    @Published var currentPTS: CMTime = .zero
    @Published var isPlaying: Bool = false
    @Published var diagnosisSummary: String = "Playback stable"
    @Published var diagnosisRecommendation: String = "No action needed"
    @Published var diagnosisConfidence: Double = 0.9
    @Published var advisoryLiveText: String = ""
    @Published var advisoryLastFinalText: String = ""
    @Published var advisoryFinalSegmentCount: Int = 0
    @Published var spatialProbeDisplay: String = ""
    @Published var audioSpatialDisplay: String = "Spatial + Head Tracking"
    @Published var audioSyncDisplay: String = "+0 ms"
    @Published var lipSyncDisplay: String = "+0 ms"
    @Published var pipelineStageDisplay: String = ""
    @Published var decodePathDisplay: String = "-"
    @Published var playbackRateDisplay: String = "1.00x"
    @Published var volumeDisplay: String = "100%"
    @Published var subtitleDelayDisplay: String = "+0 ms"
    @Published var repeatOneDisplay: String = "Off"
    @Published var bookmarkCountDisplay: String = "0"
    @Published var equalizerDisplay: String = "Flat"
    @Published var preampDisplay: String = "+0.0 dB"
    @Published var loudnessDisplay: String = "+0.0 dB"
    @Published var normalizationDisplay: String = "Off"
    @Published var limiterDisplay: String = "On"
    @Published var error: String?

    var resolutionString: String {
        (videoWidth > 0 && videoHeight > 0) ? "\(videoWidth)x\(videoHeight)" : "-"
    }

    var fpsString: String {
        framesPerSecond > 0 ? String(format: "%.1f fps", framesPerSecond) : "-"
    }

    var bitrateString: String {
        bitrate > 0 ? String(format: "%.2f Mbps", Double(bitrate) / 1_000_000.0) : "-"
    }

    var bufferString: String {
        String(format: "%.2fs", bufferedDuration)
    }

    var adaptiveBufferingThresholdString: String {
        String(format: "%.2fs", adaptiveBufferingThreshold)
    }

    var diagnosisConfidenceString: String {
        String(format: "%.0f%%", diagnosisConfidence * 100)
    }

    var advisorySegmentCountString: String {
        "\(advisoryFinalSegmentCount)"
    }

    func reset() {
        videoWidth = 0
        videoHeight = 0
        codecName = "Unknown"
        bitrate = 0
        framesPerSecond = 0
        bufferedDuration = 0
        adaptiveBufferingThreshold = 0.7
        currentPTS = .zero
        isPlaying = false
        diagnosisSummary = "Playback stable"
        diagnosisRecommendation = "No action needed"
        diagnosisConfidence = 0.9
        advisoryLiveText = ""
        advisoryLastFinalText = ""
        advisoryFinalSegmentCount = 0
        spatialProbeDisplay = ""
        audioSpatialDisplay = "Spatial + Head Tracking"
        audioSyncDisplay = "+0 ms"
        lipSyncDisplay = "+0 ms"
        pipelineStageDisplay = ""
        decodePathDisplay = "-"
        playbackRateDisplay = "1.00x"
        volumeDisplay = "100%"
        subtitleDelayDisplay = "+0 ms"
        repeatOneDisplay = "Off"
        bookmarkCountDisplay = "0"
        equalizerDisplay = "Flat"
        preampDisplay = "+0.0 dB"
        loudnessDisplay = "+0.0 dB"
        normalizationDisplay = "Off"
        limiterDisplay = "On"
        error = nil
    }
}
