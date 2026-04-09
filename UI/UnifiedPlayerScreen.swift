import SwiftUI

/// Complete unified player screen integrating all Apple TV–inspired UI components.
/// Handles gesture control, voice commands, cinema mode, HUD settings, audio controls,
/// and conditional rendering for flat/immersive/IPTV modes.
#if os(visionOS)
struct UnifiedPlayerScreen: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showHUD = true
    @State private var gestureState = GestureControlState()
    @State private var showAudioSettings = false
    @State private var showHUDSettings = false
    @State private var showCinemaSettings = false
    @State private var lastInteractionTime = Date()
    @State private var selectedTab = "player"
    
    let hideTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Route to appropriate render surface
            switch playerViewModel.currentRenderSurface {
            case .immersive:
                ImmersivePlayerView(playerViewModel: playerViewModel)
                
            case .flat:
                flatPlayerStack
                
            case .iptv:
                iptvPlayerStack
            }
        }
        .onReceive(hideTimer) { _ in
            evaluateAutoHide()
        }
        .playerGestures(
            playerViewModel: playerViewModel,
            showHUD: $showHUD,
            hudSettings: $playerViewModel.hudSettings,
            cinemaModeSettings: $playerViewModel.cinemaModeSettings,
            gestureState: $gestureState
        )
        .voiceCommands(playerViewModel: playerViewModel, showHUD: $showHUD)
    }
    
    // MARK: - Flat Player Stack
    
    @ViewBuilder
    var flatPlayerStack: some View {
        ZStack(alignment: .topLeading) {
            // Video view
            VideoPlayerView(playerViewModel: playerViewModel)
                .ignoresSafeArea()
            
            // Cinema mode overlay (if enabled)
            if playerViewModel.cinemaModeSettings.isEnabled {
                cinemaModeOverlay
                    .ignoresSafeArea()
            }
            
            // Controls (conditionally hidden based on auto-hide)
            if showHUD {
                VStack(spacing: 0) {
                    // Top control bar
                    playerTopBar
                        .transition(.move(edge: .top).animation(.easeOut(duration: 0.3)))
                    
                    Spacer()
                    
                    // Bottom HUD
                    playerHUDView
                        .transition(.move(edge: .bottom).animation(.easeOut(duration: 0.3)))
                }
                .ignoresSafeArea(edges: .all)
            }
            
            // Voice command indicator
            if playerViewModel.voiceCommandEngine.isListening {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "microphone.fill")
                                .font(.caption)
                            Text(playerViewModel.voiceCommandEngine.statusMessage)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.8), in: Capsule())
                        .padding()
                    }
                    Spacer()
                }
                .transition(.scale.animation(.spring()))
            }
        }
    }
    
    // MARK: - IPTV Player Stack
    
    @ViewBuilder
    var iptvPlayerStack: some View {
        ZStack {
            VStack(spacing: 0) {
                // IPTV Home
                AppleTVIPTVHomeView()
                
                // Floating player indicator
                if playerViewModel.isPlaying {
                    HStack(spacing: 12) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                        
                        Text("Now Playing: \(playerViewModel.currentMediaTitle)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
                }
            }
        }
    }
    
    // MARK: - HUD Components
    
    @ViewBuilder
    var playerTopBar: some View {
        VStack {
            HStack {
                // Back button
                Button(action: { playerViewModel.stop() }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(8)
                }
                
                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerViewModel.currentMediaTitle)
                        .font(.headline)
                    Text(playerViewModel.currentMediaSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Settings menu
                Menu {
                    Button(action: { showAudioSettings = true }) {
                        Label("Audio Settings", systemImage: "speaker.wave.2")
                    }
                    Button(action: { showHUDSettings = true }) {
                        Label("HUD Settings", systemImage: "hud")
                    }
                    Button(action: { showCinemaSettings = true }) {
                        Label("Cinema Mode", systemImage: "film")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.headline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .padding()
            .foregroundStyle(.white)
        }
    }
    
    @ViewBuilder
    var playerHUDView: some View {
        VStack(spacing: 0) {
            // Playback progress
            PlaybackProgressView(playerViewModel: playerViewModel)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            // HUD stats
            if playerViewModel.hudSettings.showVideoStats {
                PlayerHUD(
                    stats: playerViewModel.stats,
                    settings: playerViewModel.hudSettings,
                    audioMixer: playerViewModel.audioEngine.mixer
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // Control buttons
            playbackControlsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color.black.opacity(playerViewModel.hudSettings.opacity), in: RoundedRectangle(cornerRadius: 12))
        .padding()
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    var playbackControlsRow: some View {
        HStack(spacing: 24) {
            // Volume control
            Button(action: { playerViewModel.setVolume(max(0, playerViewModel.volume - 0.1)) }) {
                Image(systemName: "speaker.fill")
                    .font(.headline)
            }
            
            // Rewind
            Button(action: { playerViewModel.seek(to: max(0, playerViewModel.currentTime - 15)) }) {
                HStack(spacing: 4) {
                    Image(systemName: "gobackward.15")
                    Text("15s")
                }
                .font(.caption.weight(.semibold))
            }
            
            // Play/Pause
            Button(action: { playerViewModel.togglePlayPause() }) {
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .padding(12)
                    .background(Color.blue, in: Circle())
            }
            
            // Forward
            Button(action: { playerViewModel.seek(to: playerViewModel.currentTime + 15) }) {
                HStack(spacing: 4) {
                    Text("15s")
                    Image(systemName: "goforward.15")
                }
                .font(.caption.weight(.semibold))
            }
            
            // Volume control
            Button(action: { playerViewModel.setVolume(min(1.0, playerViewModel.volume + 0.1)) }) {
                Image(systemName: "speaker.wave.3")
                    .font(.headline)
            }
            
            Spacer()
            
            // Fullscreen toggle
            Button(action: { playerViewModel.toggleFullscreen() }) {
                Image(systemName: playerViewModel.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.headline)
            }
        }
    }
    
    @ViewBuilder
    var cinemaModeOverlay: some View {
        ZStack {
            // Radial gradient for ambient lighting
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(1 - playerViewModel.cinemaModeSettings.environmentDimming),
                    Color.black.opacity(playerViewModel.cinemaModeSettings.environmentDimming)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 800
            )
            
            // Subtle border for theater screen effect
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 2)
                .padding(60)
        }
    }
    
    // MARK: - Auto-hide Logic
    
    private func evaluateAutoHide() {
        let timeSinceInteraction = Date().timeIntervalSince(lastInteractionTime)
        let shouldHide = timeSinceInteraction > playerViewModel.hudSettings.autoHideInterval && showHUD
        
        if shouldHide && !gestureState.shouldShowHUDTemporarily {
            withAnimation(.easeOut(duration: 0.3)) {
                showHUD = false
            }
        }
        
        gestureState.clearExpiredTempHUD()
    }
}

// MARK: - Fallback for non-visionOS
#else
struct UnifiedPlayerScreen: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        Text("Player requires iOS 15+ or visionOS")
            .foregroundStyle(.secondary)
    }
}
#endif

// MARK: - Supporting Views

struct VideoPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Placeholder for actual video rendering
            VStack {
                Text(playerViewModel.currentMediaTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                ProgressView(value: playerViewModel.progress, total: 1.0)
                    .padding()
            }
        }
    }
}

struct PlaybackProgressView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var isDragging = false
    @State private var dragOffset: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * playerViewModel.progress)
                }
                .frame(height: 4)
                .onTapGesture { location in
                    let newProgress = location.x / geometry.size.width
                    playerViewModel.seek(to: playerViewModel.duration * newProgress)
                }
            }
            .frame(height: 4)
            
            HStack {
                Text(playerViewModel.formattedCurrentTime)
                    .font(.caption2)
                Spacer()
                Text(playerViewModel.formattedDuration)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    UnifiedPlayerScreen(playerViewModel: PlayerViewModel())
}
