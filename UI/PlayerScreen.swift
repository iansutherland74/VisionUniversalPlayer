import SwiftUI
#if os(visionOS)
import RealityKit
#endif

struct PlayerScreen: View {
    let item: MediaItem
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var visionUIRenderer: VisionUIRenderer
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator

    @State private var showControls = true
    @State private var showHUD = false
    @State private var showSnapshotGallery = false
    @State private var showQueueManager = false
    @State private var showSubtitleWorkflow = false
    @State private var showAudioSettings = false
    @State private var showHUDSettings = false
    @State private var showCinemaSettings = false
    @State private var currentTime: TimeInterval = 0
    @State private var lastInteractionAt = Date()
    @State private var hideTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var resumePersistTimer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()
    @AppStorage("ui.blur.profile") private var blurProfileStorage = "strong"
    @AppStorage("ui.blur.playerNoise") private var playerBlurNoiseStorage = 0.3
    @AppStorage("subtitles.fontScale") private var subtitleFontScale = 1.0
    @AppStorage("subtitles.backgroundOpacity") private var subtitleBackgroundOpacity = 0.62
    @AppStorage("subtitles.position") private var subtitlePositionStorage = "low"
    private let eqStepValues: [Float] = [-12, -9, -6, -3, 0, 3, 6, 9, 12]
    private let subtitleStyleStore = SubtitleStyleStore.shared

    @Environment(\.dismiss) private var dismiss
    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif

    init(item: MediaItem, playerViewModel: PlayerViewModel) {
        self.item = item
        self.playerViewModel = playerViewModel
        _visionUIRenderer = StateObject(wrappedValue: VisionUIRenderer(playerViewModel: playerViewModel))
    }

    private var usesYouTubePlayerKitPath: Bool {
        YouTubeURL.videoID(from: item.url) != nil
    }

    private var displayedItem: MediaItem {
        playerViewModel.currentMedia ?? item
    }

    var body: some View {
        Group {
            if usesYouTubePlayerKitPath {
                ZStack {
                    YouTubePlayerSurface(url: item.url)
                        .ignoresSafeArea()

                    VStack {
                        topBar
                        Spacer()
                    }
                }
            } else {
                ZStack {
                    switch playerViewModel.renderSurface {
                    case .standard:
                        MetalVideoView(playerViewModel: playerViewModel)
                            .ignoresSafeArea()
                    case .visionMetal, .converted2DTo3D:
                        MetalUIView(visionRenderer: visionUIRenderer) {
                            EmptyView()
                        }
                        .ignoresSafeArea()
                    case .immersive:
                        MetalVideoView(playerViewModel: playerViewModel)
                            .ignoresSafeArea()
                    }

                    if playerViewModel.cinemaModeSettings.isEnabled {
                        cinemaModeOverlay
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }

                    VStack {
                        topBar
                        Spacer()

                        if let subtitleText = playerViewModel.activeSubtitleText,
                           !subtitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(subtitleText)
                            .font(.system(size: 18 * subtitleFontScale, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                            .background(Color.black.opacity(subtitleBackgroundOpacity), in: RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal, 28)
                            .padding(.bottom, subtitleBottomPadding)
                                .transition(.opacity)
                        }

                        if showHUD {
                            VStack(spacing: 10) {
                                PlayerHUD(
                                    stats: playerViewModel.stats,
                                    settings: playerViewModel.hudSettings,
                                    audioMixer: playerViewModel.audioEngine.mixer
                                )

                                if playerViewModel.hudSettings.showPlaybackDiagnosis {
                                    PlaybackAdvisorLogView(
                                        segments: playerViewModel.advisorySegments,
                                        partialText: playerViewModel.advisoryPartialText,
                                        onClear: { playerViewModel.clearAdvisoryHistory() }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        controlsBar
                    }

                    #if os(visionOS)
                    if (displayedItem.vrFormat.isImmersive || playerViewModel.renderSurface == .immersive) && !showControls {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                SpatialQuickActionsOrnament(
                                    showControls: showControls,
                                    showHUD: showHUD,
                                    immersiveButtonTitle: immersiveActionTitle,
                                    isImmersiveTransitioning: sceneCoordinator.isImmersiveTransitioning,
                                    onToggleControls: {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            showControls.toggle()
                                        }
                                    },
                                    onToggleHUD: {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            showHUD.toggle()
                                        }
                                    },
                                    onToggleImmersive: {
                                        Task {
                                            await toggleImmersivePresentation()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.trailing, 14)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    #endif
                }
            }
        }
        .onTapGesture {
            lastInteractionAt = Date()
            withAnimation { showControls.toggle() }
        }
        .onLongPressGesture {
            lastInteractionAt = Date()
            withAnimation { showHUD.toggle() }
        }
        .onReceive(hideTimer) { now in
            let shouldHide = playerViewModel.isPlaying
                && showControls
                && now.timeIntervalSince(lastInteractionAt) >= playerViewModel.hudSettings.autoHideInterval
            if shouldHide {
                withAnimation { showControls = false }
            }
        }
        .onReceive(resumePersistTimer) { _ in
            if playerViewModel.isPlaying {
                playerViewModel.persistResumeProgressIfNeeded()
            }
        }
        .onChange(of: playerViewModel.playbackTimeSeconds) { _, newValue in
            currentTime = newValue
        }
        .onChange(of: playerViewModel.selectedSubtitleTrackID) { _, _ in
            applySavedSubtitlePresetForCurrentLanguage()
        }
        .onChange(of: currentTime) { oldValue, newValue in
            guard abs(newValue - playerViewModel.playbackTimeSeconds) > 0.8 else { return }
            guard abs(newValue - oldValue) > 0.02 else { return }
            Task {
                await playerViewModel.seek(to: newValue)
            }
        }
        .task {
            if usesYouTubePlayerKitPath == false,
               playerViewModel.currentMedia?.id != item.id {
                await playerViewModel.playMedia(item)
            }
            applySavedSubtitlePresetForCurrentLanguage()
        }
        .onDisappear {
            if usesYouTubePlayerKitPath == false {
                Task { await playerViewModel.stopPlayback() }
            }
        }
        .sheet(isPresented: $showSnapshotGallery) {
            SnapshotGalleryView(playerViewModel: playerViewModel)
        }
        .sheet(isPresented: $showQueueManager) {
            QueueManagerView(playerViewModel: playerViewModel)
        }
        .sheet(isPresented: $showSubtitleWorkflow) {
            SubtitleWorkflowView(playerViewModel: playerViewModel)
        }
        .sheet(isPresented: $showAudioSettings) {
            AudioSettingsView(playerViewModel: playerViewModel)
        }
        .sheet(isPresented: $showHUDSettings) {
            HUDSettingsView(playerViewModel: playerViewModel)
        }
        .sheet(isPresented: $showCinemaSettings) {
            CinemaModeSettingsView(playerViewModel: playerViewModel)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        let blurProfile = ProgressiveBlurProfile(storageValue: blurProfileStorage)

        return VStack(spacing: 8) {
            HStack {
                Button {
                    Task {
                        await dismissPlayer()
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }

                Spacer()

                Text(displayedItem.title)
                    .lineLimit(1)
                    .font(.headline)

                Spacer()

                Menu {
                    Picker("Mode", selection: $playerViewModel.selectedMode) {
                        ForEach(PlayerViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: playerViewModel.selectedMode) { _, newValue in
                        playerViewModel.switchMode(newValue)
                    }

                    Divider()

                    Picker("Surface", selection: $playerViewModel.renderSurface) {
                        ForEach(VisionUIRenderSurface.allCases) { surface in
                            Text(surface.rawValue.capitalized).tag(surface)
                        }
                    }
                    .onChange(of: playerViewModel.renderSurface) { _, newSurface in
                        playerViewModel.switchRenderSurface(newSurface)
                    }

                    Divider()
                    Section("Panels") {
                        Button("Audio Settings") {
                            showAudioSettings = true
                        }

                        Button("HUD Settings") {
                            showHUDSettings = true
                        }

                        Button(playerViewModel.cinemaModeSettings.isEnabled ? "Cinema Mode: On" : "Cinema Mode: Off") {
                            showCinemaSettings = true
                        }
                    }

                    Section("Voice Commands") {
                        Button(playerViewModel.voiceCommandEngine.isListening ? "Stop Listening" : "Start Listening") {
                            if playerViewModel.voiceCommandEngine.isListening {
                                playerViewModel.voiceCommandEngine.stopListening()
                            } else {
                                playerViewModel.voiceCommandEngine.startListening()
                            }
                        }

                        Text(playerViewModel.voiceCommandEngine.statusMessage)
                        Text(playerViewModel.voiceCommandEngine.supportedPhrases.joined(separator: " • "))
                    }

                    if playerViewModel.canStepQueue || playerViewModel.canRestoreQueueSnapshot {
                        Divider()
                        Section("Queue") {
                            Toggle("Shuffle", isOn: Binding(
                                get: { playerViewModel.shuffleEnabled },
                                set: { _ in playerViewModel.toggleShuffleEnabled() }
                            ))

                            Toggle("Repeat All", isOn: Binding(
                                get: { playerViewModel.repeatAllEnabled },
                                set: { _ in playerViewModel.toggleRepeatAllEnabled() }
                            ))

                            Toggle("Auto Remove Watched", isOn: Binding(
                                get: { playerViewModel.autoRemoveWatchedQueueItems },
                                set: { playerViewModel.setQueueAutoRemoveWatched($0) }
                            ))

                            Toggle("Pin Favorites First", isOn: Binding(
                                get: { playerViewModel.pinFavoriteItemsInQueue },
                                set: { playerViewModel.setQueuePinFavorites($0) }
                            ))

                            Toggle("Protect Pinned from Auto-Remove", isOn: Binding(
                                get: { playerViewModel.protectPinnedFromAutoRemove },
                                set: { playerViewModel.setProtectPinnedFromAutoRemove($0) }
                            ))
                            .disabled(!playerViewModel.autoRemoveWatchedQueueItems)

                            Button("Previous") {
                                Task {
                                    await playerViewModel.playPreviousInQueue()
                                }
                            }
                            .disabled(!playerViewModel.canStepQueue)

                            Button("Next") {
                                Task {
                                    await playerViewModel.playNextInQueue()
                                }
                            }
                            .disabled(!playerViewModel.canStepQueue)

                            Button("Save Queue") {
                                playerViewModel.saveQueueSnapshot()
                            }

                            Button("Open Playlist") {
                                showQueueManager = true
                            }
                            .disabled(!playerViewModel.canManageQueue)

                            Button("Load Saved Queue") {
                                Task {
                                    await playerViewModel.restoreQueueSnapshot()
                                }
                            }
                            .disabled(!playerViewModel.canRestoreQueueSnapshot)

                            Button("Clear Saved Queue", role: .destructive) {
                                playerViewModel.clearQueueSnapshot()
                            }
                            .disabled(!playerViewModel.canRestoreQueueSnapshot)
                        }
                    }

                    if !playerViewModel.audioTrackOptions.isEmpty {
                        Divider()
                        Section("Audio Track") {
                            ForEach(playerViewModel.audioTrackOptions) { option in
                                Button {
                                    playerViewModel.selectAudioTrack(id: option.id)
                                } label: {
                                    HStack {
                                        Text(option.title)
                                        if playerViewModel.selectedAudioTrackID == option.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !playerViewModel.subtitleTrackOptions.isEmpty {
                        Section("Subtitle Track") {
                            ForEach(playerViewModel.subtitleTrackOptions) { option in
                                Button {
                                    playerViewModel.selectSubtitleTrack(id: option.id)
                                } label: {
                                    HStack {
                                        Text(option.title)
                                        if playerViewModel.selectedSubtitleTrackID == option.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()
                    Section("Audio DSP") {
                        Picker("Preset", selection: Binding(
                            get: { currentAudioPreset },
                            set: { playerViewModel.applyAudioEffectsPreset($0) }
                        )) {
                            ForEach(AudioEffectsPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }

                        Picker("Preamp", selection: Binding(
                            get: { roundedPreampValue(playerViewModel.audioEffectsProfile.preampDB) },
                            set: { playerViewModel.setPreampDB($0) }
                        )) {
                            ForEach(eqStepValues, id: \.self) { value in
                                Text(String(format: "%+.0f dB", value)).tag(value)
                            }
                        }

                        Toggle("Normalization", isOn: Binding(
                            get: { playerViewModel.audioEffectsProfile.normalizationEnabled },
                            set: { _ in playerViewModel.toggleNormalization() }
                        ))

                        Toggle("Limiter", isOn: Binding(
                            get: { playerViewModel.audioEffectsProfile.limiterEnabled },
                            set: { _ in playerViewModel.toggleLimiter() }
                        ))

                        Menu {
                            Button("-2 dB") { playerViewModel.adjustLoudnessCompensation(by: -2) }
                            Button("-1 dB") { playerViewModel.adjustLoudnessCompensation(by: -1) }
                            Button("+1 dB") { playerViewModel.adjustLoudnessCompensation(by: 1) }
                            Button("+2 dB") { playerViewModel.adjustLoudnessCompensation(by: 2) }
                            Button("Reset for This Media") { playerViewModel.resetLoudnessCompensationForCurrentMedia() }
                            Button("Clear All Saved", role: .destructive) { playerViewModel.clearAllStoredLoudnessCompensation() }
                        } label: {
                            HStack {
                                Text("Loudness Memory")
                                Spacer()
                                Text(String(format: "%+.1f dB", playerViewModel.loudnessCompensationDB))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(Array(AudioEffectsProfile.bandFrequenciesHz.enumerated()), id: \.offset) { index, frequency in
                            Menu {
                                ForEach(eqStepValues, id: \.self) { value in
                                    Button {
                                        playerViewModel.setEqualizerBand(at: index, db: value)
                                    } label: {
                                        HStack {
                                            Text(String(format: "%+.0f dB", value))
                                            if abs(playerViewModel.audioEffectsProfile.bandGainsDB[index] - value) < 0.01 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("\(eqFrequencyLabel(frequency)): \(String(format: "%+.1f dB", playerViewModel.audioEffectsProfile.bandGainsDB[index]))")
                                    Spacer()
                                    Image(systemName: "slider.horizontal.3")
                                }
                            }
                        }

                        Button("Reset EQ") {
                            playerViewModel.resetEqualizer()
                        }
                    }

                    if playerViewModel.canChooseHLSResolution {
                        Divider()
                        Section("HLS Resolution") {
                            Button {
                                playerViewModel.resetHLSBitrateRungSelection()
                            } label: {
                                HStack {
                                    Text("Auto")
                                    if playerViewModel.selectedHLSBitrateRungId == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            ForEach(playerViewModel.hlsBitrateRungs) { rung in
                                Button {
                                    playerViewModel.openHLSBitrateRung(rung)
                                } label: {
                                    HStack {
                                        Text("\(rung.resolutionString) • \(rung.bitrateString)")
                                        if playerViewModel.selectedHLSBitrateRungId == rung.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !playerViewModel.hlsAudioOptions.isEmpty {
                        Section("HLS Audio") {
                            Button {
                                playerViewModel.resetHLSAudioSelection()
                            } label: {
                                HStack {
                                    Text("Default")
                                    if playerViewModel.selectedHLSAudioOptionId == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            ForEach(playerViewModel.hlsAudioOptions) { option in
                                Button {
                                    playerViewModel.openHLSAudioOption(option)
                                } label: {
                                    HStack {
                                        Text(option.description)
                                        if playerViewModel.selectedHLSAudioOptionId == option.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section("Visual Effects") {
                        Picker("Blur Profile", selection: $blurProfileStorage) {
                            Text("Soft").tag("soft")
                            Text("Medium").tag("medium")
                            Text("Strong").tag("strong")
                        }

                        Picker("Blur Noise", selection: $playerBlurNoiseStorage) {
                            Text("Off").tag(0.0)
                            Text("Low").tag(0.15)
                            Text("Medium").tag(0.3)
                            Text("High").tag(0.45)
                        }
                    }

                    Section("Subtitles") {
                        Picker("Preset", selection: Binding(
                            get: { currentSubtitlePreset },
                            set: { applySubtitlePreset($0) }
                        )) {
                            ForEach(SubtitleStylePreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }

                        Toggle("Visible", isOn: Binding(
                            get: { playerViewModel.subtitlesVisible },
                            set: { _ in playerViewModel.toggleSubtitlesVisible() }
                        ))

                        Picker("Size", selection: $subtitleFontScale) {
                            Text("Small").tag(0.85)
                            Text("Normal").tag(1.0)
                            Text("Large").tag(1.2)
                            Text("XL").tag(1.4)
                        }

                        Picker("Position", selection: $subtitlePositionStorage) {
                            Text("Low").tag("low")
                            Text("Middle").tag("mid")
                            Text("High").tag("high")
                        }

                        Picker("Background", selection: $subtitleBackgroundOpacity) {
                            Text("Off").tag(0.0)
                            Text("Low").tag(0.35)
                            Text("Medium").tag(0.62)
                            Text("High").tag(0.82)
                        }

                        Button("Save as Default for \(playerViewModel.currentSubtitleLanguageKey.uppercased())") {
                            subtitleStyleStore.setPreset(currentSubtitlePreset, for: playerViewModel.currentSubtitleLanguageKey)
                        }

                        Button("Load Default for \(playerViewModel.currentSubtitleLanguageKey.uppercased())") {
                            applySavedSubtitlePresetForCurrentLanguage()
                        }

                        Button("Clear Default for \(playerViewModel.currentSubtitleLanguageKey.uppercased())", role: .destructive) {
                            subtitleStyleStore.clearPreset(for: playerViewModel.currentSubtitleLanguageKey)
                        }

                        Button("Search and Download") {
                            showSubtitleWorkflow = true
                        }
                    }

                    Section("A-B Loop Slots") {
                        Button("Save Current A-B") {
                            playerViewModel.saveCurrentABLoopSlot(named: nil)
                        }
                        .disabled(playerViewModel.abRepeatStartSeconds == nil || playerViewModel.abRepeatEndSeconds == nil)

                        if playerViewModel.abLoopSlots.isEmpty {
                            Text("No saved loops")
                        } else {
                            ForEach(Array(playerViewModel.abLoopSlots.enumerated()), id: \.element.id) { index, slot in
                                Button {
                                    playerViewModel.loadABLoopSlot(at: index)
                                } label: {
                                    HStack {
                                        Text("\(slot.name): \(formatTime(slot.startSeconds)) - \(formatTime(slot.endSeconds))")
                                        Spacer()
                                    }
                                }

                                Button("Delete \(slot.name)", role: .destructive) {
                                    playerViewModel.removeABLoopSlot(at: index)
                                }
                            }
                        }

                        Button("Clear All Loops", role: .destructive) {
                            playerViewModel.clearABLoopSlotsForCurrentMedia()
                        }
                        .disabled(playerViewModel.abLoopSlots.isEmpty)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }

            if let resume = playerViewModel.resumeTimeSeconds, resume > 0 {
                Text("Last watched: \(formatTime(resume))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }

            if !playerViewModel.subtitleImportStatusMessage.isEmpty {
                Text(playerViewModel.subtitleImportStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            if playerViewModel.isBuffering {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.78)
                        .tint(.white)
                    Text("Buffering...")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.38), in: Capsule())
            }

            if let transportStatusText {
                HStack(spacing: 6) {
                    Image(systemName: transportStatusIcon)
                        .font(.caption2)
                    Text(transportStatusText)
                        .font(.caption2)
                }
                .foregroundStyle(transportStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.38), in: Capsule())
            }

            if let stallRiskText {
                HStack(spacing: 6) {
                    Image(systemName: stallRiskIcon)
                        .font(.caption2)
                    Text(stallRiskText)
                        .font(.caption2)
                }
                .foregroundStyle(stallRiskColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.38), in: Capsule())
            }

            if let diagnosisSummaryText {
                HStack(spacing: 6) {
                    Image(systemName: diagnosisIcon)
                        .font(.caption2)
                    Text(diagnosisSummaryText)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(diagnosisColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.38), in: Capsule())
            }

            #if os(visionOS)
            if displayedItem.vrFormat.isImmersive || playerViewModel.renderSurface == .immersive {
                Text(immersiveStatusText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
            }
            #endif

            if showControls {
                VRControlsView(playerModel: playerViewModel)
            }
        }
        .padding()
        .foregroundStyle(.white)
        .background(Color.black.opacity(showControls ? 0.35 : 0.0))
        .progressiveBlur(
            offset: 0.0,
            interpolation: 0.62,
            direction: .down,
            noise: playerBlurNoiseStorage,
            profile: blurProfile
        )
    }

    private var cinemaModeOverlay: some View {
        let settings = playerViewModel.cinemaModeSettings

        return ZStack {
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(settings.environmentDimming * 0.42),
                    Color.black.opacity(settings.environmentDimming * 0.8)
                ],
                center: .center,
                startRadius: 120,
                endRadius: 900
            )

            LinearGradient(
                colors: [
                    Color.orange.opacity(settings.ambientLighting * 0.12),
                    Color.clear,
                    Color.blue.opacity(settings.ambientLighting * 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28 + (settings.screenCurvature * 40), style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                .padding(24 + (1.0 - settings.screenScale) * 60)
        }
    }

    private var controlsBar: some View {
        VStack(spacing: 10) {
            PlayerControls(
                isPlaying: Binding(
                    get: { playerViewModel.stats.isPlaying },
                    set: { _ in playerViewModel.togglePlayPause() }
                ),
                currentTime: $currentTime,
                abRepeatStartSeconds: playerViewModel.abRepeatStartSeconds,
                abRepeatEndSeconds: playerViewModel.abRepeatEndSeconds,
                abRepeatEnabled: playerViewModel.abRepeatEnabled,
                abLoopSlots: playerViewModel.abLoopSlots,
                repeatOneEnabled: playerViewModel.repeatOneEnabled,
                repeatAllEnabled: playerViewModel.repeatAllEnabled,
                shuffleEnabled: playerViewModel.shuffleEnabled,
                canStepQueue: playerViewModel.canStepQueue,
                isMuted: playerViewModel.isMuted,
                volume: playerViewModel.volume,
                playbackRate: playerViewModel.playbackRate,
                subtitleDelaySeconds: playerViewModel.subtitleDelaySeconds,
                subtitlesVisible: playerViewModel.subtitlesVisible,
                bookmarks: playerViewModel.playbackBookmarks,
                hasAudioTracks: !playerViewModel.audioTrackOptions.isEmpty,
                hasSubtitleTracks: !playerViewModel.subtitleTrackOptions.isEmpty,
                audioTrackLabel: playerViewModel.selectedAudioTrackLabel,
                subtitleTrackLabel: playerViewModel.selectedSubtitleTrackLabel,
                snapshotStatusMessage: playerViewModel.snapshotStatusMessage,
                totalDuration: displayedItem.duration,
                onPlayPauseToggle: { playerViewModel.togglePlayPause() },
                onPlayPrevious: {
                    Task {
                        await playerViewModel.playPreviousInQueue()
                    }
                },
                onPlayNext: {
                    Task {
                        await playerViewModel.playNextInQueue()
                    }
                },
                onSeekBackward: {
                    Task {
                        await playerViewModel.seekBy(delta: -10)
                    }
                },
                onSeekForward: {
                    Task {
                        await playerViewModel.seekBy(delta: 10)
                    }
                },
                onMarkABStart: { playerViewModel.markABRepeatStart(at: currentTime) },
                onMarkABEnd: { playerViewModel.markABRepeatEnd(at: currentTime) },
                onToggleABRepeat: { playerViewModel.toggleABRepeatEnabled() },
                onClearABRepeat: { playerViewModel.clearABRepeat() },
                onSetPlaybackRate: { playerViewModel.setPlaybackRate($0) },
                onAdjustSubtitleDelay: { playerViewModel.adjustSubtitleDelay(by: $0) },
                onResetSubtitleDelay: { playerViewModel.resetSubtitleDelay() },
                onStepFrame: {
                    Task {
                        await playerViewModel.stepFrameForward()
                    }
                },
                onCaptureSnapshot: { playerViewModel.captureSnapshot() },
                onToggleMute: { playerViewModel.toggleMute() },
                onSetVolume: { playerViewModel.setVolume($0) },
                onToggleRepeatOne: { playerViewModel.toggleRepeatOneEnabled() },
                onToggleRepeatAll: { playerViewModel.toggleRepeatAllEnabled() },
                onToggleShuffle: { playerViewModel.toggleShuffleEnabled() },
                onToggleSubtitles: { playerViewModel.toggleSubtitlesVisible() },
                onCycleAudioTrack: { playerViewModel.cycleAudioTrack() },
                onCycleSubtitleTrack: { playerViewModel.cycleSubtitleTrack() },
                onOpenSnapshotGallery: {
                    showSnapshotGallery = true
                },
                onAddBookmark: { playerViewModel.addPlaybackBookmark(at: currentTime) },
                onSeekBookmark: { index in
                    Task {
                        await playerViewModel.seekToPlaybackBookmark(at: index)
                    }
                },
                onRemoveBookmark: { index in
                    playerViewModel.removePlaybackBookmark(at: index)
                },
                onSelectABLoopSlot: { index in
                    playerViewModel.loadABLoopSlot(at: index)
                }
            )

            #if os(visionOS)
            if displayedItem.vrFormat.isImmersive || playerViewModel.renderSurface == .immersive {
                Button(immersiveActionTitle) {
                    Task {
                        await toggleImmersivePresentation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sceneCoordinator.isImmersiveTransitioning)
            }
            #endif
        }
        .opacity(showControls ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .padding()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(Int(seconds), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%d:%02d", minutes, secs)
    }

    private var currentAudioPreset: AudioEffectsPreset {
        for preset in AudioEffectsPreset.allCases {
            if preset.profile.bandGainsDB == playerViewModel.audioEffectsProfile.bandGainsDB,
               abs(preset.profile.preampDB - playerViewModel.audioEffectsProfile.preampDB) < 0.01 {
                return preset
            }
        }
        return .flat
    }

    private var currentSubtitlePreset: SubtitleStylePreset {
        for preset in SubtitleStylePreset.allCases {
            if abs(preset.fontScale - subtitleFontScale) < 0.01,
               abs(preset.backgroundOpacity - subtitleBackgroundOpacity) < 0.01,
               preset.position == subtitlePositionStorage {
                return preset
            }
        }
        return .broadcast
    }

    private func applySubtitlePreset(_ preset: SubtitleStylePreset) {
        subtitleFontScale = preset.fontScale
        subtitleBackgroundOpacity = preset.backgroundOpacity
        subtitlePositionStorage = preset.position
    }

    private func applySavedSubtitlePresetForCurrentLanguage() {
        let key = playerViewModel.currentSubtitleLanguageKey
        guard let preset = subtitleStyleStore.preset(for: key) else { return }
        applySubtitlePreset(preset)
    }

    private func roundedPreampValue(_ value: Float) -> Float {
        let nearest = eqStepValues.min(by: { abs($0 - value) < abs($1 - value) })
        return nearest ?? 0
    }

    private func eqFrequencyLabel(_ hz: Int) -> String {
        if hz >= 1_000 {
            let kValue = Double(hz) / 1_000.0
            if abs(kValue.rounded() - kValue) < 0.01 {
                return String(format: "%.0fk", kValue)
            }
            return String(format: "%.1fk", kValue)
        }
        return "\(hz)Hz"
    }

    private var subtitleBottomPadding: CGFloat {
        switch subtitlePositionStorage {
        case "high":
            return 170
        case "mid":
            return 92
        default:
            return showControls ? 8 : 24
        }
    }

    private var transportStatusText: String? {
        switch playerViewModel.transportStatus {
        case .idle, .connected, .stopped:
            return nil
        case .connecting:
            return "Connecting stream..."
        case .reconnecting(let attempt, let maxAttempts, let nextDelaySeconds):
            return "Reconnecting \(attempt)/\(maxAttempts) in \(String(format: "%.1f", nextDelaySeconds))s"
        case .failed(let message):
            return "Stream failed: \(message)"
        }
    }

    private var transportStatusIcon: String {
        switch playerViewModel.transportStatus {
        case .failed:
            return "exclamationmark.triangle.fill"
        case .connecting, .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .idle, .connected, .stopped:
            return "info.circle"
        }
    }

    private var transportStatusColor: Color {
        switch playerViewModel.transportStatus {
        case .failed:
            return .red.opacity(0.95)
        case .connecting, .reconnecting:
            return .yellow.opacity(0.95)
        case .idle, .connected, .stopped:
            return .white.opacity(0.9)
        }
    }

    private var stallRiskText: String? {
        let percent = Int((playerViewModel.stallRiskScore * 100).rounded())

        switch playerViewModel.stallRiskLevel {
        case .low:
            return nil
        case .elevated:
            return "Stall risk elevated (\(percent)%)"
        case .high:
            return "Stall risk high (\(percent)%)"
        }
    }

    private var stallRiskIcon: String {
        switch playerViewModel.stallRiskLevel {
        case .low:
            return "waveform.path"
        case .elevated:
            return "waveform.path.badge.minus"
        case .high:
            return "waveform.path.badge.exclamationmark"
        }
    }

    private var stallRiskColor: Color {
        switch playerViewModel.stallRiskLevel {
        case .low:
            return .white.opacity(0.9)
        case .elevated:
            return .orange.opacity(0.95)
        case .high:
            return .red.opacity(0.95)
        }
    }

    private var diagnosisSummaryText: String? {
        switch playerViewModel.playbackDiagnosis.severity {
        case .info:
            return nil
        case .warning, .critical:
            return playerViewModel.playbackDiagnosis.summary
        }
    }

    private var diagnosisIcon: String {
        switch playerViewModel.playbackDiagnosis.severity {
        case .info:
            return "checkmark.circle"
        case .warning:
            return "lightbulb.min"
        case .critical:
            return "exclamationmark.triangle.fill"
        }
    }

    private var diagnosisColor: Color {
        switch playerViewModel.playbackDiagnosis.severity {
        case .info:
            return .white.opacity(0.9)
        case .warning:
            return .orange.opacity(0.95)
        case .critical:
            return .red.opacity(0.95)
        }
    }

    #if os(visionOS)
    private var immersiveActionTitle: String {
        switch sceneCoordinator.immersiveState {
        case .closed:
            return "Enter Immersive"
        case .inTransition:
            return "Switching Immersive..."
        case .open:
            return "Exit Immersive"
        }
    }

    private var immersiveStatusText: String {
        switch sceneCoordinator.immersiveState {
        case .closed:
            return "Immersive space is closed"
        case .inTransition:
            return "Immersive space is transitioning"
        case .open:
            return "Immersive space is open"
        }
    }

    private func toggleImmersivePresentation() async {
        await sceneCoordinator.toggleImmersiveSpace(
            open: {
                let result = await openImmersiveSpace(id: SceneCoordinator.immersivePlayerID)
                switch result {
                case .opened:
                    return true
                case .error, .userCancelled:
                    return false
                @unknown default:
                    return false
                }
            },
            dismiss: {
                await dismissImmersiveSpace()
            }
        )
    }

    private func dismissPlayer() async {
        if sceneCoordinator.isImmersiveOpen {
            await sceneCoordinator.dismissImmersiveSpace {
                await dismissImmersiveSpace()
            }
        }
        dismiss()
    }
    #else
    private func dismissPlayer() async {
        dismiss()
    }
    #endif
}

#Preview {
    PlayerScreen(item: TestMediaPack.allMedia[0], playerViewModel: PlayerViewModel())
}
