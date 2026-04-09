import Foundation
import Combine
import Metal
import CoreVideo

@MainActor
final class VisionUIRenderer: ObservableObject {
    @Published var pixelBuffer: CVPixelBuffer?
    @Published var directTexture: MTLTexture?
    @Published var layerMode: VisionUILayerMode = .video
    @Published var surfaceMode: VisionUIRenderSurface = .standard
    @Published var overlayOpacity: Float = 1.0
    @Published var hudIntensity: Float = 0.2

    let playerViewModel: PlayerViewModel

    private(set) var metalVideoRenderer: MetalVideoRenderer?
    private(set) var vrRenderer: VRRenderer?
    private(set) var depthConverter: Depth3DConverter?

    private var cancellable: AnyCancellable?

    init(playerViewModel: PlayerViewModel, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        self.playerViewModel = playerViewModel
        if let device {
            self.metalVideoRenderer = MetalVideoRenderer(device: device)
            self.vrRenderer = VRRenderer(device: device)
            self.depthConverter = Depth3DConverter(device: device)
        }

        cancellable = playerViewModel.pixelBufferPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buffer in
                self?.pixelBuffer = buffer
            }
    }

    func refreshFromPlayerState() {
        switch playerViewModel.selectedMode {
        case .flat:
            layerMode = .video
            surfaceMode = .standard
        case .vr180, .vr360, .sbs, .tab:
            layerMode = .vr
            surfaceMode = .visionMetal
        case .convert2DTo3D:
            layerMode = .depth3D
            surfaceMode = .converted2DTo3D
        }
    }

    func convertedBufferIfNeeded() -> CVPixelBuffer? {
        guard
            layerMode == .depth3D,
            let src = pixelBuffer,
            let converter = depthConverter
        else {
            return pixelBuffer
        }

        return converter.convert2DToStereo3DSBS(
            pixelBuffer: src,
            convergence: playerViewModel.convergence,
            depthStrength: playerViewModel.depthStrength
        )
    }
}
