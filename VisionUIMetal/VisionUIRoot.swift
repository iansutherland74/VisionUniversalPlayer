import SwiftUI

struct VisionUIRoot: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var visionRenderer: VisionUIRenderer

    init(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        _visionRenderer = StateObject(wrappedValue: VisionUIRenderer(playerViewModel: playerViewModel))
    }

    var body: some View {
        VStack(spacing: 12) {
            VisionUIContainer(title: "Vision UI Metal", subtitle: "Scene-based composition and immersive-ready controls") {
                Picker("Surface", selection: Binding(
                    get: { playerViewModel.renderSurface },
                    set: { playerViewModel.switchRenderSurface($0) }
                )) {
                    ForEach(VisionUIRenderSurface.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            MetalUIView(visionRenderer: visionRenderer) {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PlayerHUD(stats: playerViewModel.stats, settings: playerViewModel.hudSettings, audioMixer: playerViewModel.audioEngine.mixer)
                            .frame(maxWidth: 300)
                    }
                }
                .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .onChange(of: playerViewModel.currentPixelBuffer) { _, newValue in
            visionRenderer.pixelBuffer = newValue
        }
        .onChange(of: playerViewModel.selectedMode) { _, _ in
            visionRenderer.refreshFromPlayerState()
        }
        .onChange(of: playerViewModel.renderSurface) { _, newSurface in
            visionRenderer.surfaceMode = newSurface
        }
    }
}
