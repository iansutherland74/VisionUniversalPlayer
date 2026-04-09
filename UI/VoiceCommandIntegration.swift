import SwiftUI
import Speech

/// AudioEngine extension for voice command integration with system speech recognition.
extension VoiceCommandEngine {
    
    /// Starts listening for voice commands using device microphone.
    /// Returns a binding to a stream of recognized commands.
    @MainActor
    func startVoiceRecognition(
        completion: @escaping (Command) -> Void
    ) async {
        isListening = true
        statusMessage = "Listening..."
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusMessage = "Microphone access denied"
            isListening = false
            return
        }
        
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard recognizer?.isAvailable == true else {
            statusMessage = "Speech recognition unavailable"
            isListening = false
            return
        }
        
        #if os(visionOS)
        // For visionOS, use a longer listening window
        await performRecognition(recognizer: recognizer, duration: 10, completion: completion)
        #else
        // For iOS, use standard listening window
        await performRecognition(recognizer: recognizer, duration: 5, completion: completion)
        #endif
    }
    
    @MainActor
    private func performRecognition(
        recognizer: SFSpeechRecognizer?,
        duration: TimeInterval,
        completion: @escaping (Command) -> Void
    ) async {
        guard let recognizer else { return }
        
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { _, _ in
            // Audio processing handled by system
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            statusMessage = "Microphone error"
            isListening = false
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        var recognitionTask: SFSpeechRecognitionTask?
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                self.lastTranscript = transcript
                
                if result.isFinal {
                    // Parse final transcript into command
                    if let command = self.parse(transcript: transcript) {
                        DispatchQueue.main.async {
                            completion(command)
                        }
                    }
                    self.isListening = false
                    self.statusMessage = "Ready"
                } else {
                    self.statusMessage = "Listening: \(transcript)"
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                recognitionTask?.cancel()
                self.isListening = false
            }
        }
    }
    
    /// Stops voice recognition.
    @MainActor
    func stopVoiceRecognition() {
        isListening = false
        statusMessage = "Ready"
    }
}

/// View modifier that integrates voice commands into player screens.
struct VoiceCommandModifier: ViewModifier {
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var showHUD: Bool
    
    @State private var voiceCommandEngine: VoiceCommandEngine?
    @State private var isListeningForVoice = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                voiceCommandEngine = playerViewModel.voiceCommandEngine
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                // Periodic check for voice command status
                if let engine = voiceCommandEngine, engine.isListening {
                    // Update UI to show listening indicator
                }
            }
            .contextMenu {
                Button(action: startVoiceCommand) {
                    Label("Voice Command", systemImage: "microphone.badge.xmark")
                }
            }
    }
    
    private func startVoiceCommand() {
        isListeningForVoice = true
        Task {
            await playerViewModel.voiceCommandEngine.startVoiceRecognition { command in
                handleVoiceCommand(command)
            }
        }
    }
    
    private func handleVoiceCommand(_ command: VoiceCommandEngine.Command) {
        switch command {
        case .playPause:
            playerViewModel.togglePlayPause()
            
        case .seekForward:
            Task { await playerViewModel.seek(to: playerViewModel.playbackTimeSeconds + 10) }
            
        case .seekBackward:
            Task { await playerViewModel.seek(to: max(0, playerViewModel.playbackTimeSeconds - 10)) }
            
        case .louder:
            playerViewModel.setVolume(playerViewModel.volume + 0.1)
            
        case .softer:
            playerViewModel.setVolume(max(0, playerViewModel.volume - 0.1))
            
        case .toggleHUD:
            withAnimation(.easeInOut(duration: 0.2)) {
                showHUD.toggle()
            }
            
        case .toggleSubtitles:
            playerViewModel.toggleSubtitlesVisible()
            
        case .nextTrack:
            Task { await playerViewModel.playNextInQueue() }
        }
        
        isListeningForVoice = false
    }
}

extension View {
    func voiceCommands(
        playerViewModel: PlayerViewModel,
        showHUD: Binding<Bool>
    ) -> some View {
        modifier(
            VoiceCommandModifier(
                playerViewModel: playerViewModel,
                showHUD: showHUD
            )
        )
    }
}
