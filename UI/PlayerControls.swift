import SwiftUI

struct PlayerControls: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    let abRepeatStartSeconds: TimeInterval?
    let abRepeatEndSeconds: TimeInterval?
    let abRepeatEnabled: Bool
    let abLoopSlots: [ABLoopSlot]
    let repeatOneEnabled: Bool
    let repeatAllEnabled: Bool
    let shuffleEnabled: Bool
    let canStepQueue: Bool
    let isMuted: Bool
    let volume: Float
    let playbackRate: Double
    let subtitleDelaySeconds: TimeInterval
    let subtitlesVisible: Bool
    let bookmarks: [TimeInterval]
    let hasAudioTracks: Bool
    let hasSubtitleTracks: Bool
    let audioTrackLabel: String
    let subtitleTrackLabel: String
    let snapshotStatusMessage: String
    let totalDuration: TimeInterval?
    let onPlayPauseToggle: () -> Void
    let onPlayPrevious: () -> Void
    let onPlayNext: () -> Void
    let onSeekBackward: () -> Void
    let onSeekForward: () -> Void
    let onMarkABStart: () -> Void
    let onMarkABEnd: () -> Void
    let onToggleABRepeat: () -> Void
    let onClearABRepeat: () -> Void
    let onSetPlaybackRate: (Double) -> Void
    let onAdjustSubtitleDelay: (TimeInterval) -> Void
    let onResetSubtitleDelay: () -> Void
    let onStepFrame: () -> Void
    let onCaptureSnapshot: () -> Void
    let onToggleMute: () -> Void
    let onSetVolume: (Float) -> Void
    let onToggleRepeatOne: () -> Void
    let onToggleRepeatAll: () -> Void
    let onToggleShuffle: () -> Void
    let onToggleSubtitles: () -> Void
    let onCycleAudioTrack: () -> Void
    let onCycleSubtitleTrack: () -> Void
    let onOpenSnapshotGallery: () -> Void
    let onAddBookmark: () -> Void
    let onSeekBookmark: (Int) -> Void
    let onRemoveBookmark: (Int) -> Void
    let onSelectABLoopSlot: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let duration = totalDuration, duration > 0 {
                VStack(spacing: 8) {
                    CompactValueSlider(
                        value: $currentTime,
                        range: 0...duration,
                        accentColor: .cyan,
                        valueLabel: { formatTime($0) }
                    )

                    if !abLoopSlots.isEmpty {
                        GeometryReader { proxy in
                            let width = max(proxy.size.width, 1)

                            ZStack(alignment: .leading) {
                                ForEach(Array(abLoopSlots.enumerated()), id: \.element.id) { index, slot in
                                    let startX = markerX(for: slot.startSeconds, duration: duration, width: width)
                                    let endX = markerX(for: slot.endSeconds, duration: duration, width: width)
                                    let bandWidth = max(endX - startX, 7)

                                    Button {
                                        onSelectABLoopSlot(index)
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(Color.mint.opacity(0.35))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                        .stroke(Color.mint.opacity(0.72), lineWidth: 1)
                                                }

                                            if bandWidth >= 40 {
                                                Text(slot.name)
                                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(.white.opacity(0.92))
                                                    .lineLimit(1)
                                                    .padding(.horizontal, 3)
                                            }
                                        }
                                        .frame(width: bandWidth, height: 8)
                                    }
                                    .buttonStyle(.plain)
                                    .help("\(slot.name): \(formatTime(slot.startSeconds)) - \(formatTime(slot.endSeconds))")
                                    .position(
                                        x: (startX + endX) / 2,
                                        y: 6
                                    )
                                }
                            }
                        }
                        .frame(height: 12)
                    }

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            HStack(spacing: 32) {
                Spacer()

                Button(action: onPlayPrevious) {
                    Image(systemName: "backward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .disabled(!canStepQueue)
                .opacity(canStepQueue ? 1.0 : 0.5)

                Button(action: onSeekBackward) {
                    Label("10s", systemImage: "gobackward.10")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }

                Button(action: onPlayPauseToggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }

                Button(action: onSeekForward) {
                    Label("10s", systemImage: "goforward.10")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }

                Button(action: onStepFrame) {
                    Label("Frame", systemImage: "forward.frame")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }

                Button(action: onPlayNext) {
                    Image(systemName: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                .disabled(!canStepQueue)
                .opacity(canStepQueue ? 1.0 : 0.5)

                Spacer()
            }
            .padding()

            HStack(spacing: 8) {
                Button(action: onToggleMute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                CompactValueSlider(
                    value: Binding(
                        get: { Double(volume) },
                        set: { onSetVolume(Float($0)) }
                    ),
                    range: 0...1,
                    accentColor: .blue,
                    valueLabel: { "\(Int($0 * 100))%" }
                )
                .frame(width: 110)

                Menu {
                    Button("0.50x") { onSetPlaybackRate(0.5) }
                    Button("0.75x") { onSetPlaybackRate(0.75) }
                    Button("1.00x") { onSetPlaybackRate(1.0) }
                    Button("1.25x") { onSetPlaybackRate(1.25) }
                    Button("1.50x") { onSetPlaybackRate(1.5) }
                    Button("2.00x") { onSetPlaybackRate(2.0) }
                } label: {
                    Label(String(format: "%.2fx", playbackRate), systemImage: "speedometer")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                HStack(spacing: 4) {
                    Button("-50ms") { onAdjustSubtitleDelay(-0.05) }
                        .buttonStyle(.bordered)
                    Text(formatDelay(subtitleDelaySeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 62)
                    Button("+50ms") { onAdjustSubtitleDelay(0.05) }
                        .buttonStyle(.bordered)
                    Button {
                        onResetSubtitleDelay()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: onToggleRepeatOne) {
                    Label("Loop 1", systemImage: repeatOneEnabled ? "repeat.1.circle.fill" : "repeat.1.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(repeatOneEnabled ? .green : .gray)

                Button(action: onToggleRepeatAll) {
                    Label("Loop All", systemImage: repeatAllEnabled ? "repeat.circle.fill" : "repeat.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(repeatAllEnabled ? .green : .gray)

                Button(action: onToggleShuffle) {
                    Label("Shuffle", systemImage: shuffleEnabled ? "shuffle.circle.fill" : "shuffle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(shuffleEnabled ? .cyan : .gray)

                Button(action: onToggleSubtitles) {
                    Image(systemName: subtitlesVisible ? "captions.bubble.fill" : "captions.bubble")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Menu {
                    Button("Add Bookmark") {
                        onAddBookmark()
                    }

                    if bookmarks.isEmpty {
                        Text("No bookmarks")
                    } else {
                        ForEach(Array(bookmarks.enumerated()), id: \.offset) { index, value in
                            Button("Jump \(index + 1): \(formatTime(value))") {
                                onSeekBookmark(index)
                            }

                            Button("Delete \(index + 1)", role: .destructive) {
                                onRemoveBookmark(index)
                            }
                        }
                    }
                } label: {
                    Label("Marks", systemImage: "bookmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button(action: onCycleAudioTrack) {
                    Label("Audio", systemImage: "speaker.wave.2")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(!hasAudioTracks)
                .opacity(hasAudioTracks ? 1.0 : 0.5)

                Button(action: onCycleSubtitleTrack) {
                    Label("Sub", systemImage: "captions.bubble")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(!hasSubtitleTracks)
                .opacity(hasSubtitleTracks ? 1.0 : 0.5)

                Button(action: onCaptureSnapshot) {
                    Label("Shot", systemImage: "camera")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button(action: onOpenSnapshotGallery) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button(action: onMarkABStart) {
                    Text("A")
                        .font(.caption.weight(.bold))
                        .frame(minWidth: 34)
                }
                .buttonStyle(.bordered)
                .tint(abRepeatStartSeconds == nil ? .gray : .mint)

                Button(action: onMarkABEnd) {
                    Text("B")
                        .font(.caption.weight(.bold))
                        .frame(minWidth: 34)
                }
                .buttonStyle(.bordered)
                .tint(abRepeatEndSeconds == nil ? .gray : .orange)

                Button(action: onToggleABRepeat) {
                    Label("A-B", systemImage: abRepeatEnabled ? "repeat.circle.fill" : "repeat.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(abRepeatStartSeconds == nil || abRepeatEndSeconds == nil)
                .opacity((abRepeatStartSeconds == nil || abRepeatEndSeconds == nil) ? 0.55 : 1)

                if abRepeatStartSeconds != nil || abRepeatEndSeconds != nil {
                    Button(action: onClearABRepeat) {
                        Image(systemName: "xmark.circle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                if let a = abRepeatStartSeconds, let b = abRepeatEndSeconds {
                    Text("\(formatTime(a)) - \(formatTime(b))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)

            if !snapshotStatusMessage.isEmpty {
                Text(snapshotStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(audioTrackLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("|")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(subtitleTrackLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    private func formatDelay(_ seconds: TimeInterval) -> String {
        let ms = Int((seconds * 1000).rounded())
        return String(format: "%+dms", ms)
    }
}

#Preview {
    PlayerControls(
        isPlaying: .constant(true),
        currentTime: .constant(30),
        abRepeatStartSeconds: 20,
        abRepeatEndSeconds: 35,
        abRepeatEnabled: true,
        abLoopSlots: [
            ABLoopSlot(id: UUID(), name: "Intro", startSeconds: 30, endSeconds: 50),
            ABLoopSlot(id: UUID(), name: "Hook", startSeconds: 120, endSeconds: 140)
        ],
        repeatOneEnabled: true,
        repeatAllEnabled: true,
        shuffleEnabled: false,
        canStepQueue: true,
        isMuted: false,
        volume: 0.9,
        playbackRate: 1.25,
        subtitleDelaySeconds: 0.1,
        subtitlesVisible: true,
        bookmarks: [12, 54, 128],
        hasAudioTracks: true,
        hasSubtitleTracks: true,
        audioTrackLabel: "Audio: Auto",
        subtitleTrackLabel: "Subtitles: Off",
        snapshotStatusMessage: "",
        totalDuration: 3600,
        onPlayPauseToggle: { },
        onPlayPrevious: { },
        onPlayNext: { },
        onSeekBackward: { },
        onSeekForward: { },
        onMarkABStart: { },
        onMarkABEnd: { },
        onToggleABRepeat: { },
        onClearABRepeat: { },
        onSetPlaybackRate: { _ in },
        onAdjustSubtitleDelay: { _ in },
        onResetSubtitleDelay: { },
        onStepFrame: { },
        onCaptureSnapshot: { },
        onToggleMute: { },
        onSetVolume: { _ in },
        onToggleRepeatOne: { },
        onToggleRepeatAll: { },
        onToggleShuffle: { },
        onToggleSubtitles: { },
        onCycleAudioTrack: { },
        onCycleSubtitleTrack: { },
        onOpenSnapshotGallery: { },
        onAddBookmark: { },
        onSeekBookmark: { _ in },
        onRemoveBookmark: { _ in }
        ,
        onSelectABLoopSlot: { _ in }
    )
}

private extension PlayerControls {
    func markerX(for seconds: TimeInterval, duration: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = min(max(seconds / duration, 0), 1)
        return CGFloat(progress) * width
    }
}
