import Foundation
import MetalKit

final class MetalHostView: NSObject, ObservableObject {
    private let renderer: MetalVideoRenderer
    private var currentPixelBuffer: CVPixelBuffer?
    private var currentFormat: VRFormat = .flat2D
    private let metalView: MTKView

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = MetalVideoRenderer(device: device)
        else {
            fatalError("Metal device unavailable")
        }

        self.renderer = renderer
        self.metalView = MTKView(frame: .zero, device: device)
        super.init()

        metalView.delegate = self
        metalView.framebufferOnly = false
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = true
        metalView.colorPixelFormat = .bgra8Unorm
        Task {
            await DebugCategory.metal.infoLog("MetalHostView initialized")
        }
    }

    func update(pixelBuffer: CVPixelBuffer, format: VRFormat) {
        currentPixelBuffer = pixelBuffer
        currentFormat = format
        renderer.configureForVRFormat(format)
        metalView.draw()
        Task {
            await DebugCategory.renderer.traceLog(
                "MetalHostView frame update",
                context: ["format": String(describing: format)]
            )
        }
    }

    func getView() -> MTKView {
        metalView
    }
}

extension MetalHostView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let pixelBuffer = currentPixelBuffer
        else {
            return
        }

        renderer.render(pixelBuffer: pixelBuffer, to: drawable, in: descriptor, with: currentFormat)
        renderer.flushTextureCache()
    }
}
