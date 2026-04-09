import MetalKit
import SwiftUI
import CoreImage

/// Vision UI Metal renderer that composites all overlays (HUD, cinema, settings, IPTV, audio).
/// This efficient Metal-backed layer handles multi-overlay rendering for visionOS and iOS.
class VisionUIMetalRenderer: NSObject, MTKViewDelegate {
    var commandQueue: MTLCommandQueue?
    var pipelineState: MTLRenderPipelineState?
    var samplerState: MTLSamplerState?
    
    var videoTexture: MTLTexture?
    var hudTexture: MTLTexture?
    var iptvTexture: MTLTexture?
    var audioMeterTexture: MTLTexture?
    
    weak var mtkView: MTKView?
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var audioMixer: AudioMixer
    
    let hudSettings: HUDSettings
    let cinemaModeSettings: CinemaModeSettings
    
    init(
        mtkView: MTKView,
        playerViewModel: PlayerViewModel,
        audioMixer: AudioMixer,
        hudSettings: HUDSettings,
        cinemaModeSettings: CinemaModeSettings
    ) {
        self.mtkView = mtkView
        self.playerViewModel = playerViewModel
        self.audioMixer = audioMixer
        self.hudSettings = hudSettings
        self.cinemaModeSettings = cinemaModeSettings
        
        super.init()
        
        setupMetal(mtkView: mtkView)
    }
    
    private func setupMetal(mtkView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        mtkView.device = device
        
        commandQueue = device.makeCommandQueue()
        
        // Setup render pipeline
        let library = device.makeDefaultLibrary()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShaderComposite")
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        // Setup sampler
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.minFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
        
        mtkView.delegate = self
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let pipelineState = pipelineState else { return }
        
        // Render video layer with overlays
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set textures for compositing
        if let videoTexture = videoTexture {
            renderEncoder.setFragmentTexture(videoTexture, index: 0)
        }
        
        // Conditional overlays based on settings
        if hudSettings.showVideoStats && hudTexture != nil {
            renderEncoder.setFragmentTexture(hudTexture, index: 1)
        }
        
        if let iptvTexture = iptvTexture {
            renderEncoder.setFragmentTexture(iptvTexture, index: 2)
        }
        
        if hudSettings.showAudioMeters && audioMeterTexture != nil {
            renderEncoder.setFragmentTexture(audioMeterTexture, index: 3)
        }
        
        // Cinema mode darkening
        if cinemaModeSettings.isEnabled {
            var environmentDimmingFactor = Float(cinemaModeSettings.environmentDimming)
            renderEncoder.setFragmentBytes(&environmentDimmingFactor, length: MemoryLayout<Float>.size, index: 0)
        }
        
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateVideoTexture(_ texture: MTLTexture) {
        videoTexture = texture
    }
    
    func updateHUDTexture(_ texture: MTLTexture?) {
        hudTexture = texture
    }
    
    func updateIPTVTexture(_ texture: MTLTexture?) {
        iptvTexture = texture
    }
    
    func updateAudioMeterTexture(_ texture: MTLTexture?) {
        audioMeterTexture = texture
    }
}

/// SwiftUI wrapper for Metal renderer view.
struct VisionUIMetalView: UIViewRepresentable {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var audioMixer: AudioMixer
    let hudSettings: HUDSettings
    let cinemaModeSettings: CinemaModeSettings
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        mtkView.delegate = context.coordinator
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.playerViewModel = playerViewModel
        context.coordinator.audioMixer = audioMixer
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            playerViewModel: playerViewModel,
            audioMixer: audioMixer,
            hudSettings: hudSettings,
            cinemaModeSettings: cinemaModeSettings
        )
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        @ObservedObject var playerViewModel: PlayerViewModel
        @ObservedObject var audioMixer: AudioMixer
        let hudSettings: HUDSettings
        let cinemaModeSettings: CinemaModeSettings
        var renderer: VisionUIMetalRenderer?
        
        init(
            playerViewModel: PlayerViewModel,
            audioMixer: AudioMixer,
            hudSettings: HUDSettings,
            cinemaModeSettings: CinemaModeSettings
        ) {
            self.playerViewModel = playerViewModel
            self.audioMixer = audioMixer
            self.hudSettings = hudSettings
            self.cinemaModeSettings = cinemaModeSettings
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            if renderer == nil {
                renderer = VisionUIMetalRenderer(
                    mtkView: view,
                    playerViewModel: playerViewModel,
                    audioMixer: audioMixer,
                    hudSettings: hudSettings,
                    cinemaModeSettings: cinemaModeSettings
                )
            }
            renderer?.draw(in: view)
        }
    }
}

/// Metal shader library for overlay compositing.
/// This is embedded as a string; in production, use a .metal file.
let metalShaderLibrary = """
#include <metal_stdlib>
using namespace metal;

// Vertex shader
vertex float4 vertexShader(
    uint vertexID [[vertex_id]],
    constant packed_float3* vertices [[buffer(0)]]
) {
    return float4(vertices[vertexID], 1.0);
}

// Fragment shader for multi-layer compositing
fragment float4 fragmentShaderComposite(
    float4 in [[stage_in]],
    texture2d<float> videoTex [[texture(0)]],
    texture2d<float> hudTex [[texture(1)]],
    texture2d<float> iptvTex [[texture(2)]],
    texture2d<float> audioMeterTex [[texture(3)]],
    sampler smp [[sampler(0)]],
    constant float& dimmingFactor [[buffer(0)]]
) -> float4 {
    // Normalized coordinates
    float2 uv = in.xy;
    
    // Sample video layer
    float4 videoColor = videoTex.sample(smp, uv);
    
    // Apply cinema mode dimming
    videoColor.rgb *= (1.0 - (dimmingFactor * 0.3));
    
    // Alpha blend overlays
    float4 result = videoColor;
    
    // Blend HUD layer (minimal opacity)
    float4 hudColor = hudTex.sample(smp, uv);
    result = mix(result, hudColor, hudColor.a * 0.85);
    
    // Blend IPTV overlay
    float4 iptvColor = iptvTex.sample(smp, uv);
    result = mix(result, iptvColor, iptvColor.a * 0.75);
    
    // Blend audio meters (top right)
    float4 meterColor = audioMeterTex.sample(smp, uv);
    result = mix(result, meterColor, meterColor.a * 0.9);
    
    // Apply tone mapping for HDR support
    result.rgb = result.rgb / (result.rgb + float3(1.0));
    
    return result;
}
"""

/// View showing Metal rendering with all overlays composited.
struct VisionUIMetalPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var audioMixer: AudioMixer
    let hudSettings: HUDSettings
    let cinemaModeSettings: CinemaModeSettings
    
    var body: some View {
        ZStack {
            VisionUIMetalView(
                playerViewModel: playerViewModel,
                audioMixer: audioMixer,
                hudSettings: hudSettings,
                cinemaModeSettings: cinemaModeSettings
            )
            .ignoresSafeArea()
            
            // Overlay composition layers appear atop Metal view
            if hudSettings.showAudioMeters {
                VStack {
                    AdvancedVUMetersView(
                        mixer: audioMixer,
                        showChannelLabels: true,
                        showPeakHold: true
                    )
                    .padding()
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        VisionUIMetalPlayerView(
            playerViewModel: PlayerViewModel(),
            audioMixer: AudioEngine().mixer,
            hudSettings: HUDSettings(),
            cinemaModeSettings: CinemaModeSettings()
        )
    }
}
