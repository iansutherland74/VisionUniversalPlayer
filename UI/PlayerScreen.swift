import SwiftUI
#if os(visionOS)
import RealityKit
#endif

struct PlayerScreen: View {
    let item: MediaItem
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var visionUIRenderer: VisionUIRenderer
    @StateObject private var nativePlayerController: NativePlayerController
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator

    @State private var showControls = true
    @State private var showSnapshotGallery = false
    @State private var showQueueManager = false
    @State private var showSubtitleWorkflow = false
    @State private var showAudioSettings = false
    @State private var showHUDSettings = false
    @State private var showCinemaSettings = false
    @State private var showPanelMenuSheet = false
    @State private var isFullscreenFillEnabled = true
    @State private var currentTime: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var lastInteractionAt = Date()
    @State private var hideTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var resumePersistTimer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()
    @AppStorage("ui.blur.profile") private var blurProfileStorage = "strong"
    @AppStorage("ui.blur.playerNoise") private var playerBlurNoiseStorage = 0.3
    @AppStorage("subtitles.fontScale") private var subtitleFontScale = 1.0
    @AppStorage("subtitles.backgroundOpacity") private var subtitleBackgroundOpacity = 0.62
    @AppStorage("subtitles.position") private var subtitlePositionStorage = "low"
    @AppStorage("ui.panelMenu.detent") private var panelMenuDetentStorage = "medium"
    @State private var panelMenuDetentSelection: PresentationDetent = .medium
    private let eqStepValues: [Float] = [-12, -9, -6, -3, 0, 3, 6, 9, 12]
    private let subtitleStyleStore = SubtitleStyleStore.shared

    @Environment(\.dismiss) private var dismiss
    #if os(visionOS)
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    init(item: MediaItem, playerViewModel: PlayerViewModel) {
        self.item = item
        self.playerViewModel = playerViewModel
        _visionUIRenderer = StateObject(wrappedValue: VisionUIRenderer(playerViewModel: playerViewModel))
        _nativePlayerController = StateObject(wrappedValue: NativePlayerController(url: item.url))
    }

    private var usesYouTubePlayerKitPath: Bool {
        YouTubeURL.videoID(from: item.url) != nil
    }

    private var usesNativeAVKitPath: Bool {
        #if os(visionOS)
        if usesYouTubePlayerKitPath { return false }
        return item.vrFormat == .flat2D
        #else
        if usesYouTubePlayerKitPath { return false }
        guard item.vrFormat == .flat2D else { return false }
        guard let scheme = item.url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        let ext = item.url.pathExtension.lowercased()
        return ["m3u8", "mp4", "mov", "m4v", "webm"].contains(ext) || item.sourceKind == .ffmpegContainer
        #endif
    }

    private var displayedItem: MediaItem {
        playerViewModel.currentMedia ?? item
    }

    #if os(visionOS)
    private var playerWindowSize: CGSize {
        if isFullscreenFillEnabled {
            return CGSize(width: 1680, height: 1080)
        }
        return CGSize(width: 1280, height: 820)
    }

    private var controlsVisible: Bool {
        showControls || usesNativeAVKitPath
    }
    #endif

    var body: some View {
        ZStack {
            Group {
                if usesYouTubePlayerKitPath {
                    YouTubePlayerSurface(url: item.url)
                        .ignoresSafeArea()
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lastInteractionAt = Date()
                            withAnimation { showControls = true }
                        }
                        .onLongPressGesture(minimumDuration: 0.6) {
                            lastInteractionAt = Date()
                            withAnimation { playerViewModel.isHUDVisible.toggle() }
                        }
                } else if usesNativeAVKitPath {
                    NativeVideoPlayerSurface(
                        controller: nativePlayerController,
                        shouldFillScreen: isFullscreenFillEnabled
                    )
                        .ignoresSafeArea()
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lastInteractionAt = Date()
                            withAnimation { showControls = true }
                        }
                        .onLongPressGesture(minimumDuration: 0.6) {
                            lastInteractionAt = Date()
                            withAnimation { playerViewModel.isHUDVisible.toggle() }
                        }
                } else {
                    switch playerViewModel.renderSurface {
                    case .standard:
                        MetalVideoView(playerViewModel: playerViewModel)
                            .ignoresSafeArea()
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                lastInteractionAt = Date()
                                withAnimation { showControls = true }
                            }
                            .onLongPressGesture(minimumDuration: 0.6) {
                                lastInteractionAt = Date()
                                withAnimation { playerViewModel.isHUDVisible.toggle() }
                            }
                    case .visionMetal, .converted2DTo3D:
                        MetalUIView(visionRenderer: visionUIRenderer) {
                            EmptyView()
                        }
                        .ignoresSafeArea()
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lastInteractionAt = Date()
                            withAnimation { showControls = true }
                        }
                        .onLongPressGesture(minimumDuration: 0.6) {
                            lastInteractionAt = Date()
                            withAnimation { playerViewModel.isHUDVisible.toggle() }
                        }
                    case .immersive:
                        MetalVideoView(playerViewModel: playerViewModel)
                            .ignoresSafeArea()
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                lastInteractionAt = Date()
                                withAnimation { showControls = true }
                            }
                            .onLongPressGesture(minimumDuration: 0.6) {
                                lastInteractionAt = Date()
                                withAnimation { playerViewModel.isHUDVisible.toggle() }
                            }
                    }
                }
            }

            if playerViewModel.cinemaModeSettings.isEnabled {
                cinemaModeOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if controlsVisible {
                VStack {
                    HStack {
                        Button {
                            toggleFullscreenWindowSize()
                        } label: {
                            Image(systemName: isFullscreenFillEnabled ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
            }



            if controlsVisible {
                VStack {
                    Spacer()
                    scrubberBar
                        .padding(.bottom, 108)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.opacity)
            }

            VStack {
                Spacer()
                controlsBar
                    .padding(.bottom, 20)
            }
            .ignoresSafeArea(edges: .bottom)

            VStack {
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
                        .padding(.bottom, subtitleBottomPadding + 84)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if playerViewModel.isHUDVisible {
                VStack(spacing: 10) {
                    Spacer()
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
                .padding(.bottom, 150)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            #if os(visionOS)
            if (displayedItem.vrFormat.isImmersive || playerViewModel.renderSurface == .immersive) && !showControls {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SpatialQuickActionsOrnament(
                            showControls: showControls,
                            showHUD: playerViewModel.isHUDVisible,
                            immersiveButtonTitle: immersiveActionTitle,
                            isImmersiveTransitioning: sceneCoordinator.isImmersiveTransitioning,
                            onToggleControls: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    showControls.toggle()
                                }
                            },
                            onToggleHUD: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    playerViewModel.isHUDVisible.toggle()
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
    #if os(visionOS)
        .windowGeometryPreferences(size: playerWindowSize)
    #endif
        .ignoresSafeArea(edges: .all)
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
        .onReceive(nativePlayerController.$currentTime) { newValue in
            guard usesNativeAVKitPath, isScrubbing == false else { return }
            currentTime = newValue
        }
        .onChange(of: playerViewModel.playbackTimeSeconds) { _, newValue in
            guard usesNativeAVKitPath == false, isScrubbing == false else { return }
            currentTime = newValue
        }
        .onChange(of: playerViewModel.selectedSubtitleTrackID) { _, _ in
            applySavedSubtitlePresetForCurrentLanguage()
        }
        .task {
            if usesYouTubePlayerKitPath == false {
                if usesNativeAVKitPath {
                    nativePlayerController.play()
                } else {
                    await playerViewModel.playMedia(item)
                }
            }
            applySavedSubtitlePresetForCurrentLanguage()
        }
        .onDisappear {
            if usesNativeAVKitPath {
                nativePlayerController.stop()
            }
            Task { await playerViewModel.stopPlayback() }
        }
        #if !os(visionOS)
        .sheet(isPresented: $showSnapshotGallery) {
            SnapshotGalleryView(playerViewModel: playerViewModel)
        }
        #endif
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
        .sheet(isPresented: $showPanelMenuSheet) {
            panelMenuSheet
            #if !os(visionOS)
                .presentationDetents(
                    [.fraction(0.35), .medium, .large],
                    selection: $panelMenuDetentSelection
                )
                .presentationDragIndicator(.visible)
                .onAppear {
                    panelMenuDetentSelection = detentFromStorage(panelMenuDetentStorage)
                }
                .onChange(of: panelMenuDetentSelection) { _, newValue in
                    panelMenuDetentStorage = storageValue(for: newValue)
                }
            #endif
        }
        .navigationBarBackButtonHidden(true)
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


    private var scrubberBar: some View {
        let duration = max(usesNativeAVKitPath ? nativePlayerController.duration : (displayedItem.duration ?? 0), 0)

        return VStack {
            HStack(spacing: 12) {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            currentTime = newValue
                            lastInteractionAt = Date()
                            if showControls == false {
                                withAnimation { showControls = true }
                            }
                        }
                    ),
                    in: 0...max(duration, 0.1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        lastInteractionAt = Date()

                        guard editing == false else { return }
                        if usesNativeAVKitPath {
                            nativePlayerController.seek(to: currentTime)
                        } else {
                            Task {
                                await playerViewModel.seek(to: currentTime)
                            }
                        }
                    }
                )
                    .tint(.white.opacity(0.8))

                Text(formatTime(duration))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24)
    }

    private var controlsBar: some View {
        let isPlaying = usesNativeAVKitPath ? nativePlayerController.isPlaying : playerViewModel.stats.isPlaying
        let isMuted = usesNativeAVKitPath ? nativePlayerController.isMuted : playerViewModel.isMuted

        return HStack(spacing: 20) {
            Button {
                Task {
                    await dismissPlayer()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Speaker/Audio
            Button {
                if usesNativeAVKitPath {
                    nativePlayerController.toggleMute()
                } else {
                    playerViewModel.toggleMute()
                }
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Skip back 15
            Button {
                if usesNativeAVKitPath {
                    nativePlayerController.seekBy(delta: -15)
                } else {
                    Task {
                        await playerViewModel.seekBy(delta: -15)
                    }
                }
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Play/Pause
            Button {
                if usesNativeAVKitPath {
                    nativePlayerController.togglePlayPause()
                } else {
                    playerViewModel.togglePlayPause()
                }
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            // Skip forward 15
            Button {
                if usesNativeAVKitPath {
                    nativePlayerController.seekBy(delta: 15)
                } else {
                    Task {
                        await playerViewModel.seekBy(delta: 15)
                    }
                }
            } label: {
                Image(systemName: "goforward.10")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Button {
                openSnapshotGallery()
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // Settings
            Button {
                #if os(visionOS)
                openPlayerSettings()
                #else
                showPanelMenuSheet = true
                #endif
            } label: {
                Image(systemName: "gear.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            // More options
            Button {
                // Show more options / menu
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .opacity(controlsVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
    }

    private func toggleFullscreenWindowSize() {
        lastInteractionAt = Date()
        withAnimation(.easeInOut(duration: 0.18)) {
            isFullscreenFillEnabled.toggle()
        }
    }

    #if os(visionOS)
    private func openSnapshotGallery() {
        openWindow(id: SceneCoordinator.snapshotWindowID)
    }

    private func openPlayerSettings() {
        if supportsMultipleWindows {
            openWindow(id: SceneCoordinator.playerSettingsWindowID)
        } else {
            showPanelMenuSheet = true
            DebugCategory.navigation.warningLog("Multi-window unavailable; falling back to panel menu sheet")
        }
    }
    #else
    private func openSnapshotGallery() {
        showSnapshotGallery = true
    }
    #endif

    private var panelMenuSheet: some View {
        NavigationStack {
            List {
                Section("Playback") {
                    Picker("Mode", selection: $playerViewModel.selectedMode) {
                        ForEach(PlayerViewModel.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .onChange(of: playerViewModel.selectedMode) { _, newValue in
                        playerViewModel.switchMode(newValue)
                    }

                    Picker("Surface", selection: $playerViewModel.renderSurface) {
                        ForEach(VisionUIRenderSurface.allCases) { surface in
                            Text(surface.rawValue.capitalized).tag(surface)
                        }
                    }
                    .onChange(of: playerViewModel.renderSurface) { _, newSurface in
                        playerViewModel.switchRenderSurface(newSurface)
                    }
                }

                Section("Panels") {
                    Button("Audio Settings") {
                        openSubpanelFromMenu(.audio)
                    }

                    Button("HUD Settings") {
                        openSubpanelFromMenu(.hud)
                    }

                    Button("Cinema Settings") {
                        openSubpanelFromMenu(.cinema)
                    }

                    Button("Subtitle Search & Download") {
                        openSubpanelFromMenu(.subtitleWorkflow)
                    }

                    Button("Queue / Playlist") {
                        openSubpanelFromMenu(.queue)
                    }
                    .disabled(!playerViewModel.canManageQueue)
                }

                Section("Quick Toggles") {
                    Toggle("Show Subtitles", isOn: Binding(
                        get: { playerViewModel.subtitlesVisible },
                        set: { _ in playerViewModel.toggleSubtitlesVisible() }
                    ))

                    Toggle("Show HUD", isOn: $playerViewModel.isHUDVisible)

                    Toggle("Shuffle", isOn: Binding(
                        get: { playerViewModel.shuffleEnabled },
                        set: { _ in playerViewModel.toggleShuffleEnabled() }
                    ))

                    Toggle("Repeat All", isOn: Binding(
                        get: { playerViewModel.repeatAllEnabled },
                        set: { _ in playerViewModel.toggleRepeatAllEnabled() }
                    ))
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Panel Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showPanelMenuSheet = false
                    }
                }
            }
        }
    }

    private enum SubpanelTarget {
        case audio
        case hud
        case cinema
        case subtitleWorkflow
        case queue
    }

    private func openSubpanelFromMenu(_ target: SubpanelTarget) {
        showPanelMenuSheet = false
        DispatchQueue.main.async {
            switch target {
            case .audio:
                showAudioSettings = true
            case .hud:
                showHUDSettings = true
            case .cinema:
                showCinemaSettings = true
            case .subtitleWorkflow:
                showSubtitleWorkflow = true
            case .queue:
                showQueueManager = true
            }
        }
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

    private func detentFromStorage(_ value: String) -> PresentationDetent {
        switch value {
        case "small":
            return .fraction(0.35)
        case "large":
            return .large
        default:
            return .medium
        }
    }

    private func storageValue(for detent: PresentationDetent) -> String {
        if detent == .large {
            return "large"
        }
        if detent == .medium {
            return "medium"
        }
        return "small"
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

    @MainActor
    private func dismissPlayer() async {
        if sceneCoordinator.isImmersiveOpen {
            await sceneCoordinator.dismissImmersiveSpace {
                await dismissImmersiveSpace()
            }
        }
        if usesNativeAVKitPath {
            nativePlayerController.stop()
        }
        sceneCoordinator.playerWindowRequestToken = UUID()
        sceneCoordinator.shouldShowPlayerWindow = false
        sceneCoordinator.selectedPlayerItem = nil
        sceneCoordinator.playerWindowVisible = false
        dismissWindow(id: SceneCoordinator.playerWindowID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismissWindow(id: SceneCoordinator.playerWindowID)
        }
        openWindow(id: SceneCoordinator.mainWindowID)
        dismiss()

        // Stop engine work after the window close request so UI closes immediately.
        Task {
            await playerViewModel.stopPlayback()
        }
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
