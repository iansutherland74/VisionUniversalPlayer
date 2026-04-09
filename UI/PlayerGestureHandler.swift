import SwiftUI

/// Gesture handler state for HUD control in PlayerScreen.
/// Coordinates tap, double-tap, long-press, and pinch gestures to control HUD visibility.
struct GestureControlState: Identifiable {
    let id = UUID()
    
    var lastTapTime: Date?
    var tapCount: Int = 0
    var isLongPressActive: Bool = false
    var isPinchActive: Bool = false
    var tempHUDShowEndTime: Date?
    
    mutating func recordTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime ?? now)
        
        if timeSinceLastTap < 0.4 {  // Double-tap window (400ms)
            tapCount += 1
        } else {
            tapCount = 1
            lastTapTime = now
        }
        lastTapTime = now
    }
    
    mutating func resetTaps() {
        tapCount = 0
        lastTapTime = nil
    }
    
    mutating func startTempHUDShow(duration: TimeInterval = 3) {
        tempHUDShowEndTime = Date().addingTimeInterval(duration)
    }
    
    var shouldShowHUDTemporarily: Bool {
        guard let endTime = tempHUDShowEndTime else { return false }
        return Date() < endTime
    }
    
    mutating func clearExpiredTempHUD() {
        if tempHUDShowEndTime.map({ Date() > $0 }) ?? false {
            tempHUDShowEndTime = nil
        }
    }
}

/// Enumeration of supported player gestures.
enum PlayerGesture: Hashable {
    case singleTap
    case doubleTap
    case longPress
    case pinch(scale: Double)
    case pan(translation: CGSize)
    case swipeUp
    case swipeDown
    case gazeDown
}

/// View modifier that adds complete gesture support to player screens.
struct PlayerGestureModifier: ViewModifier {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var showHUD: Bool
    @Binding var hudSettings: HUDSettings
    @Binding var cinemaModeSettings: CinemaModeSettings
    @Binding var gestureState: GestureControlState
    
    @State private var dragStartLocation: CGPoint = .zero
    @State private var isProcessingGesture = false
    
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 1) {
                handleSingleTap()
            }
            .onTapGesture(count: 2) {
                handleDoubleTap()
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onChanged { _ in
                        if !isProcessingGesture {
                            gestureState.isLongPressActive = true
                        }
                    }
                    .onEnded { _ in
                        gestureState.isLongPressActive = false
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        if !isProcessingGesture && scale > 1.1 {
                            gestureState.isPinchActive = true
                            handlePinchGesture(scale: scale)
                        }
                    }
                    .onEnded { _ in
                        gestureState.isPinchActive = false
                    }
            )
            .onChange(of: gestureState.shouldShowHUDTemporarily) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showHUD = true
                    }
                }
            }
    }
    
    private func handleSingleTap() {
        isProcessingGesture = true
        gestureState.recordTap()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if gestureState.tapCount == 1 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showHUD.toggle()
                    playerViewModel.setHUDShowVideoStats(!showHUD)
                }
                Task {
                    await DebugCategory.gestures.infoLog(
                        "Single tap toggled HUD",
                        context: ["showHUD": showHUD ? "true" : "false"]
                    )
                }
            }
            gestureState.resetTaps()
            isProcessingGesture = false
        }
    }
    
    private func handleDoubleTap() {
        gestureState.tapCount = 2
        isProcessingGesture = true
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.2)) {
            playerViewModel.setCinemaModeEnabled(!cinemaModeSettings.isEnabled)
        }
        Task {
            await DebugCategory.gestures.infoLog(
                "Double tap toggled cinema mode",
                context: ["cinemaEnabled": cinemaModeSettings.isEnabled ? "false" : "true"]
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProcessingGesture = false
        }
    }
    
    private func handlePinchGesture(scale: Double) {
        // Pinch to temporarily show HUD (3 seconds)
        gestureState.startTempHUDShow(duration: 3)
        withAnimation(.easeOut(duration: 0.3)) {
            showHUD = true
        }
        Task {
            await DebugCategory.gestures.traceLog(
                "Pinch gesture detected",
                context: ["scale": String(format: "%.3f", scale)]
            )
        }
    }
}

extension View {
    func playerGestures(
        playerViewModel: PlayerViewModel,
        showHUD: Binding<Bool>,
        hudSettings: Binding<HUDSettings>,
        cinemaModeSettings: Binding<CinemaModeSettings>,
        gestureState: Binding<GestureControlState>
    ) -> some View {
        modifier(
            PlayerGestureModifier(
                playerViewModel: playerViewModel,
                showHUD: showHUD,
                hudSettings: hudSettings,
                cinemaModeSettings: cinemaModeSettings,
                gestureState: gestureState
            )
        )
    }
}
