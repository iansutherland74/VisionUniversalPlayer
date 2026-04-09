import SwiftUI
import RealityKit
import AVFoundation

/// Immersive player scene for visionOS with spatial video rendering and gesture control.
#if os(visionOS)
import RealityKit

@MainActor
struct ImmersivePlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showControls = false
    @State private var lastInteractionTime = Date()
    @State private var gestureState = GestureControlState()
    
    let controlsHideInterval: TimeInterval = 5
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 3D/spatial video rendering via RealityKit
            ImmersiveVideoRenderer(playerViewModel: playerViewModel)
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            handleTap()
                        }
                )
                .gesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            handleLongPress()
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            if scale > 1.15 {
                                handlePinch()
                            }
                        }
                )
            
            // Minimal immersive HUD (bottom center, appears on gesture)
            if showControls {
                ImmersivePlayerHUD(
                    playerViewModel: playerViewModel,
                    showControls: $showControls
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
            
            // Voice command indicator (top right)
            if playerViewModel.voiceCommandEngine.isListening {
                VStack {
                    HStack {
                        Spacer()
                        Label(
                            playerViewModel.voiceCommandEngine.statusMessage,
                            systemImage: "microphone.fill"
                        )
                        .padding(12)
                        .background(Color.orange.opacity(0.7), in: Capsule())
                        .padding()
                    }
                    Spacer()
                }
                .transition(.scale.animation(.spring(response: 0.3)))
            }
        }
        .onReceive(timer) { _ in
            let timeSinceLastInteraction = Date().timeIntervalSince(lastInteractionTime)
            if timeSinceLastInteraction > controlsHideInterval && showControls {
                withAnimation(.easeOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
        .onAppear {
            playerViewModel.switchMode(.flat)
        }
    }
    
    private func handleTap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        lastInteractionTime = Date()
    }
    
    private func handleLongPress() {
        // Double-tap equivalent: toggle cinema mode
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            playerViewModel.setCinemaModeEnabled(!playerViewModel.cinemaModeSettings.isEnabled)
        }
        lastInteractionTime = Date()
    }
    
    private func handlePinch() {
        // Pinch: temporarily show controls for 3 seconds
        gestureState.startTempHUDShow(duration: 3)
        withAnimation(.easeOut(duration: 0.3)) {
            showControls = true
        }
        lastInteractionTime = Date()
    }
}

/// Reality Kit renderer for immersive spatial video with head tracking.
struct ImmersiveVideoRenderer: UIViewControllerRepresentable {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    func makeUIViewController(context: Context) -> ImmersiveVideoViewController {
        let controller = ImmersiveVideoViewController(playerViewModel: playerViewModel)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ImmersiveVideoViewController, context: Context) {
        uiViewController.updatePlayback(playerViewModel: playerViewModel)
    }
}

/// UIViewController wrapper for RealityKit immersive rendering.
class ImmersiveVideoViewController: UIViewController {
    @ObservedObject var playerViewModel: PlayerViewModel
    var immersiveView: UIView?
    
    init(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
    }
    
    private func setupARView() {
        let immersiveView = UIView(frame: view.bounds)
        immersiveView.backgroundColor = .clear
        self.immersiveView = immersiveView
        view.addSubview(immersiveView)
        
        // Camera tracking for head-relative spatial audio
        var cameraAnchor = AnchorEntity(world: [0, 0, 0])
        
        // Add spatial audio object anchors based on layout
        if playerViewModel.audioEngine.mixer.atmosMetadata.isAtmos {
            addAtmosObjects(to: &cameraAnchor)
        }
    }
    
    private func addAtmosObjects(to anchor: inout AnchorEntity) {
        let metadata = playerViewModel.audioEngine.mixer.atmosMetadata
        
        // Create spatial anchors for Atmos objects
        // Left surround
        var leftSurround = AnchorEntity(world: [-1.5, 0, 0])
        
        // Right surround
        var rightSurround = AnchorEntity(world: [1.5, 0, 0])
        
        // Center (front)
        var center = AnchorEntity(world: [0, 0, -2])
        
        // Height channel (ceiling)
        var heightChannel = AnchorEntity(world: [0, 1.5, -1])
        
        // Assign spatial audio parameters
        if let objectCount = metadata.objectCount {
            // Distribute objects spatially
        }
    }
    
    func updatePlayback(playerViewModel: PlayerViewModel) {
        // Update video playback state if needed
    }
}

/// Minimal HUD for immersive mode with large touch targets.
struct ImmersivePlayerHUD: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var showControls: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 32) {
                // Rewind 15s
                Button(action: { Task { await playerViewModel.seek(to: max(0, playerViewModel.playbackTimeSeconds - 15)) } }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 32))
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
                
                // Play/Pause
                Button(action: { playerViewModel.togglePlayPause() }) {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40))
                        .frame(width: 120, height: 120)
                        .background(Color.blue.opacity(0.4), in: Circle())
                }
                
                // Forward 15s
                Button(action: { Task { await playerViewModel.seek(to: playerViewModel.playbackTimeSeconds + 15) } }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 32))
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.2), in: Circle())
                }
            }
            .padding(.bottom, 60)
            
            // Progress bar
            VStack(spacing: 12) {
                ProgressView(value: playbackProgress, total: 1.0)
                .tint(.blue)
                
                HStack {
                    Text(formatTime(playerViewModel.playbackTimeSeconds))
                        .font(.caption)
                    Spacer()
                    Text(formatTime(totalDuration))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
        .padding(60)
    }

    private var totalDuration: Double {
        max(playerViewModel.currentMedia?.duration ?? 0, 0)
    }

    private var playbackProgress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(playerViewModel.playbackTimeSeconds / totalDuration, 0), 1)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#endif

// Fallback for non-visionOS platforms
#if !os(visionOS)
struct ImmersivePlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        Text("Immersive mode requires visionOS")
            .foregroundStyle(.secondary)
    }
}
#endif

#Preview {
    if #available(visionOS 1.0, *) {
        ImmersivePlayerView(playerViewModel: PlayerViewModel())
    }
}
