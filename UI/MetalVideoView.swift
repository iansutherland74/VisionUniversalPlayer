import SwiftUI
import MetalKit

struct MetalVideoView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var host = MetalHostView()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MetalViewRepresentable(view: host.getView())
        }
        .onReceive(playerViewModel.pixelBufferPublisher) { pixelBuffer in
            let format = playerViewModel.currentMedia?.vrFormat ?? .flat2D
            host.update(pixelBuffer: pixelBuffer, format: format)
        }
    }
}

#if os(visionOS)
struct MetalViewRepresentable: UIViewRepresentable {
    let view: MTKView

    func makeUIView(context: Context) -> MTKView { view }
    func updateUIView(_ uiView: MTKView, context: Context) { }
}
#endif
