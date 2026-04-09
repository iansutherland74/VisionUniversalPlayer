import SwiftUI
import MetalKit

struct MetalUIView<Overlay: View>: View {
    @ObservedObject var visionRenderer: VisionUIRenderer
    private let overlay: Overlay

    init(visionRenderer: VisionUIRenderer, @ViewBuilder overlay: () -> Overlay) {
        self.visionRenderer = visionRenderer
        self.overlay = overlay()
    }

    var body: some View {
        ZStack {
            MetalUIViewRepresentable(visionRenderer: visionRenderer)
                .ignoresSafeArea()
            overlay
        }
    }
}

#if os(visionOS)
private struct MetalUIViewRepresentable: UIViewRepresentable {
    @ObservedObject var visionRenderer: VisionUIRenderer

    func makeCoordinator() -> Coordinator {
        Coordinator(visionRenderer: visionRenderer)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.visionRenderer = visionRenderer
        context.coordinator.renderer?.syncCache(from: visionRenderer)
        uiView.setNeedsDisplay()
    }

    final class Coordinator {
        var renderer: MetalUIRenderer?
        var visionRenderer: VisionUIRenderer

        init(visionRenderer: VisionUIRenderer) {
            self.visionRenderer = visionRenderer
        }

        func attach(to view: MTKView) {
            renderer = MetalUIRenderer(mtkView: view, visionRenderer: visionRenderer)
            view.delegate = renderer
        }
    }
}
#endif
