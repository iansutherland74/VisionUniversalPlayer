import SwiftUI

struct PlayerHUD: View {
    let stats: PlayerStats
    let settings: HUDSettings
    let audioMixer: AudioMixer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Playback HUD")
                    .font(.headline)

                Spacer()

                Image(systemName: "info.circle")
                    .font(.caption)
            }

            if settings.showVideoStats {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    statRow("Codec", stats.codecName)
                    statRow("Resolution", stats.resolutionString)
                    statRow("FPS", stats.fpsString)
                    statRow("Bitrate", stats.bitrateString)
                    statRow("Buffer", stats.bufferString)
                    statRow("Adaptive Threshold", stats.adaptiveBufferingThresholdString)
                    statRow("Decode Path", stats.decodePathDisplay)
                    statRow("Speed", stats.playbackRateDisplay)
                    statRow("Volume", stats.volumeDisplay)
                    statRow("EQ", stats.equalizerDisplay)
                    statRow("Preamp", stats.preampDisplay)
                    statRow("Loudness", stats.loudnessDisplay)
                    statRow("Normalize", stats.normalizationDisplay)
                    statRow("Limiter", stats.limiterDisplay)
                    statRow("Subtitle Delay", stats.subtitleDelayDisplay)
                    statRow("Repeat One", stats.repeatOneDisplay)
                    statRow("Bookmarks", stats.bookmarkCountDisplay)
                }
            }

            if settings.showPlaybackDiagnosis {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    statRow("Diagnosis", stats.diagnosisSummary)
                    statRow("Confidence", stats.diagnosisConfidenceString)
                    statRow("Advisor Segments", stats.advisorySegmentCountString)
                }
            }

            if settings.showSpatialDetails {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    statRow("Audio Spatial", stats.audioSpatialDisplay, accent: .cyan)
                    statRow("Audio Sync", stats.audioSyncDisplay)
                    statRow("Lip Sync", stats.lipSyncDisplay)

                    if !stats.spatialProbeDisplay.isEmpty {
                        statRow("Video Spatial", stats.spatialProbeDisplay, accent: .cyan)
                    }
                }
            }

            if settings.showPipelineStatus, !stats.pipelineStageDisplay.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    statRow("Pipeline", stats.pipelineStageDisplay, accent: .orange)
                }
            }

            if settings.showAudioMeters {
                AudioMetersView(mixer: audioMixer)
            }

            if settings.showRecommendations {
                Text(stats.diagnosisRecommendation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = stats.error {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.6 * settings.opacity))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statRow(_ title: String, _ value: String, accent: Color? = nil) -> some View {
        GridRow {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(accent)
        }
    }
}

#Preview {
    let stats = PlayerStats()
    stats.videoWidth = 1920
    stats.videoHeight = 1080
    stats.codecName = "HEVC"
    stats.framesPerSecond = 60
    stats.bitrate = 8_000_000

    return PlayerHUD(stats: stats, settings: .default, audioMixer: AudioEngine().mixer)
}
