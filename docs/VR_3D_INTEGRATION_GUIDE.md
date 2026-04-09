# VisionOS VR/3D Video Player - VR Extensions Guide

## Overview

The VR/3D extension module adds comprehensive stereoscopic and immersive video rendering to the VisionUniversal Player. It supports:

- **180° Hemispherical VR**: Forward-facing immersive content
- **360° Spherical VR**: Full 360° immersive environments
- **Stereo Formats**: Side-by-Side (SBS) and Top-and-Bottom (TAB) stereoscopic splits
- **2D-to-3D Conversion**: Automatic depth estimation and stereo synthesis from monocular video

## Architecture

### Component Overview

```
Video Input
    ↓
[VRRenderer]  ← Determines render geometry (flat, hemisphere, sphere)
    ↓
[SphereMesh/QuadMesh]  ← 3D geometry generation
    ↓
[Metal Rendering]  ← YUV→RGB + sphere mapping
    ↓
[Stereo Splitting]  ← SBS/TAB format handling
    ↓
Display Output
```

### Core Components

#### 1. **VRRenderer** (`Rendering/VRRenderer.swift`)
Main orchestrator for VR video rendering.

**Responsibilities:**
- Detect video format from `MediaItem.vrFormat`
- Select appropriate render geometry (flat quad, hemisphere, sphere)
- Manage Metal pipeline states for YUV→RGB conversion + sphere projection
- Handle stereoscopic splitting (SBS, TAB)
- Manage CVMetalTextureCache for zero-copy texture creation

**Key Classes:**
- `VRRenderer`: Main orchestrator
- `QuadMesh`: Flat 2D/3D quadrilateral for non-immersive content
- `StereoscopicMode`: Enum for stereo output format

**Example Usage:**
```swift
let vrRenderer = VRRenderer(device: metalDevice)
vrRenderer.setRenderMode(.sphere360)  // For 360° content
vrRenderer.render(pixelBuffer: frameBuffer, to: drawable, in: renderPass)
```

#### 2. **SphereMesh** (`Rendering/SphereMesh.swift`)
Procedurally generates 3D sphere/hemisphere geometry.

**Parameters:**
- `segments`: Horizontal divisions (64-128 recommended)
- `rings`: Vertical divisions (32-64 recommended)
- `radius`: Sphere radius in meters
- `isHemisphere`: true for 180°, false for 360°

**Features:**
- Normalized UV mapping for equirectangular video
- Efficient triangle indexing
- GPU-resident vertex/index buffers

#### 3. **Depth3DConverter** (`Rendering/Depth3DConverter.swift`)
Converts monocular 2D video to stereoscopic 3D.

**Pipeline:**
1. **Depth Estimation**: Edge detection + luminance analysis → depth map
2. **Disparity Generation**: Depth inversion + sensitivity scaling → disparity map
3. **Stereo Synthesis**: Parallax shift + occlusion filling → stereo pair

**Adjustable Parameters:**
- `depthStrength`: Controls depth perception intensity (0.0-2.0)
- `convergence`: Controls stereo window position (0.0-1.0)
- `maxDisparity`: Maximum pixel offset between eyes (0.01-0.1)

**Example Usage:**
```swift
let converter = Depth3DConverter(device: metalDevice)
let stereoBuffer = converter.convert2DToStereo3DSBS(
    pixelBuffer: monocularFrame,
    convergence: 0.5,
    depthStrength: 1.0
)
```

#### 4. **DepthShaders** (`Rendering/DepthShaders.metal`)
Metal shaders for depth-based stereo synthesis.

**Fragment Shaders:**
- `depthMapShader`: Edge detection for depth estimation
- `disparityMapShader`: Converts depth to disparity
- `stereoSynthesisLeftShader`: Left eye parallax offset
- `stereoSynthesisRightShader`: Right eye parallax offset
- `stereoSBSOutputShader`: Combined SBS output
- `stereoTABOutputShader`: Combined TAB output
- `occlusionFillShader`: Hole filling for occlusion regions

#### 5. **ImmersivePlayerScene** (`Engine/ImmersivePlayerScene.swift`)
visionOS RealityKit integration for immersive mode.

**Features:**
- Full immersive space rendering
- Hand gesture controls (drag for rotation, pinch for zoom)
- VRCameraController for handling 180°/360° rotation constraints
- Stereoscopic rendering configuration per format

**Activation:**
```swift
// In SwiftUI app
.windowGroup(id: "vr-player") {
    PlayerScreen(model: playerVM)
}
.preferredColorScheme(.dark)

// Transition to immersive
@Environment(\.openImmersiveSpace) var openImmersiveSpace
await openImmersiveSpace(id: "vr-player")
```

## VR Format Support

### Format Enum (`Media/MediaItem.swift`)

```swift
enum VRFormat: String, Codable, CaseIterable {
    // Standard formats
    case flat2D                // Standard 2D video
    case sideBySide3D          // Side-by-side stereoscopic
    case topBottom3D           // Top-and-bottom stereoscopic
    
    // 180° VR
    case mono180               // Single monocular hemisphere
    case stereo180SBS          // Side-by-side stereo hemisphere
    case stereo180TAB          // Top-and-bottom stereo hemisphere
    
    // 360° VR
    case mono360               // Single monocular sphere
    case stereo360SBS          // Side-by-side stereo sphere
    case stereo360TAB          // Top-and-bottom stereo sphere
    
    var isStereoscopic: Bool
    var isImmersive: Bool
}
```

### Rendering by Format

| Format | Geometry | Stereo | Rotation | Use Case |
|--------|----------|--------|----------|----------|
| flat2D | Quad | No | None | Standard video |
| sideBySide3D | Quad | SBS | None | 3D movies |
| mono180 | Hemisphere | No | <90° | VR videos |
| stereo180SBS | Hemisphere | SBS | <90° | 3D VR videos |
| mono360 | Sphere | No | ±180° | 360° photos |
| stereo360SBS | Sphere | SBS | ±180° | 8K VR videos |

## Integration Guide

### Step 1: Update MediaItem Detection

```swift
// In FFmpegDemuxer.swift or MediaItem initialization
func detectVRFormat(from metadata: [String: Any]) -> VRFormat {
    let width = metadata["width"] as? Int ?? 0
    let height = metadata["height"] as? Int ?? 0
    let aspectRatio = Float(width) / Float(height)
    
    // 2:1 ratio → 360° content
    if abs(aspectRatio - 2.0) < 0.1 {
        return .mono360
    }
    
    // 1:1 ratio → 180° content
    if abs(aspectRatio - 1.0) < 0.1 {
        return .mono180
    }
    
    // Default
    return .flat2D
}
```

### Step 2: Enable VR Rendering in PlayerViewModel

```swift
class PlayerViewModel: ObservableObject {
    @Published var vrRenderer: VRRenderer?
    @Published var depth3DConverter: Depth3DConverter?
    
    func setupVRRendering(device: MTLDevice) {
        vrRenderer = VRRenderer(device: device)
        depth3DConverter = Depth3DConverter(device: device)
    }
    
    func configureForMediaFormat(_ format: VRFormat) {
        switch format {
        case .flat2D, .sideBySide3D, .topBottom3D:
            vrRenderer?.setRenderMode(.flatQuad)
            
        case .mono180, .stereo180SBS, .stereo180TAB:
            vrRenderer?.setRenderMode(.hemisphere180)
            
        case .mono360, .stereo360SBS, .stereo360TAB:
            vrRenderer?.setRenderMode(.sphere360)
        }
        
        // Configure stereo mode
        if format.isStereoscopic {
            if format.rawValue.contains("SBS") {
                vrRenderer?.stereoscopicMode = .sideBySide
            } else if format.rawValue.contains("TAB") {
                vrRenderer?.stereoscopicMode = .topAndBottom
            }
        }
    }
}
```

### Step 3: Update MetalVideoRenderer for VR

```swift
class MetalVideoRenderer {
    private var vrRenderer: VRRenderer?
    
    func renderFrame(_ pixelBuffer: CVPixelBuffer, format: VRFormat) {
        if format.isImmersive {
            // Use VR renderer for spherical content
            vrRenderer?.render(pixelBuffer: pixelBuffer, to: drawable, in: renderPass)
        } else {
            // Use standard quad renderer
            renderQuadFrame(pixelBuffer)
        }
    }
}
```

### Step 4: Add UI Control for VR Mode

```swift
// In DetailView.swift
@State private var enable2Dto3D = false
@State private var depthStrength: Float = 1.0

ZStack {
    PlayerScreen(model: playerVM, vrRenderer: vrRenderer)
    
    VStack {
        Toggle("Enable 2D→3D", isOn: $enable2Dto3D)
        
        if enable2Dto3D {
            Slider(value: $depthStrength, in: 0...2)
                .onChange(of: depthStrength) { newValue in
                    depth3DConverter?.depthStrength = newValue
                }
        }
        
        if playerVM.currentMedia?.vrFormat.isImmersive ?? false {
            Button("Enter Immersive Mode") {
                Task {
                    await openImmersiveSpace(id: "vr-player")
                }
            }
        }
    }
}
```

## FFmpeg Build Setup

### Building FFmpeg XCFramework

```bash
# Build FFmpeg for visionOS
./scripts/build-ffmpeg-visionos.sh 6.0

# This creates: Frameworks/libavformat.xcframework, libavcodec.xcframework, libavutil.xcframework
```

### Build Script Features

The build script (`scripts/build-ffmpeg-visionos.sh`):

1. **Multi-Architecture Support**
   - visionOS arm64 (device)
   - visionOS x86_64 (simulator)

2. **Protocol Support**
   - HTTP/HTTPS (streaming)
   - FTP (file transfer)
   - RTMP/RTMPS (streaming)
   - RTSP/RTSPS (streaming)

3. **Container Format Support**
   - MP4, MKV, TS, MOV, FLV
   - HLS, DASH, M3U8

4. **Codec Configuration**
   - H.264, HEVC, VP9, AV1 (decode only)
   - Maintained separate static libraries per architecture
   - Bitstream filters: h264_mp4toannexb, hevc_mp4toannexb

### XCFramework Integration

```swift
// In Xcode: File → Add Files to Project
// Select: Frameworks/FFmpeg.xcframework

// In Source Code:
import FFmpeg

let formatCtx = avformat_alloc_context()
avformat_open_input(&formatCtx, "http://example.com/video.mp4", nil, nil)
```

## Performance Optimization

### Texture Pipeline

- **Input**: CVPixelBuffer (NV12 YUV from VideoToolbox)
- **CVMetalTextureCache**: Zero-copy GPU upload
- **Rendering**: Y + UV textures in single render pass
- **Output**: BGRA MTLTexture to screen

### Sphere Rendering

```swift
// Reduce segments for performance
SphereMesh(device: device, segments: 64, rings: 32)  // Mobile
SphereMesh(device: device, segments: 128, rings: 64) // visionOS
```

### Depth Conversion Parameters

```swift
// Balance quality vs. performance
converter.depthStrength = 0.8    // Subtle depth (faster)
converter.convergence = 0.4      // Tighter stereo window
converter.maxDisparity = 0.03    // Limited parallax
```

## Testing

### Test Media Samples

```swift
// From TestMediaPack.swift
let testSamples: [MediaItem] = [
    MediaItem.flat2DVideo,        // 1920×1080 H.264
    MediaItem.stereo3DVideo,      // Side-by-side 3840×1080
    MediaItem.mono180Video,       // 2048×2048 hemisphere
    MediaItem.stereo180SBSVideo,  // 4096×2048 stereo hemisphere
    MediaItem.mono360Video,       // Equirectangular sphere
    MediaItem.stereo360SBSVideo   // 8192×4096 stereo sphere
]
```

### VR Content Sources

- **YouTube**: 360° videos, 3D side-by-side formats
- **Meta Quest**: MP4 with vrFormat metadata
- **Professional VR**: DNG/MOV equirectangular + stereoscopic
- **2D→3D**: Any standard video (enable depth conversion)

## Troubleshooting

### Issue: Sphere appears inverted

**Solution**: Flip sphere normal direction in SphereMesh
```swift
// In SphereMesh.swift
let normal = normalize(position)  // Invert if needed
// normal = -normal
```

### Issue: Stereo separation too strong

**Solution**: Reduce maxDisparity
```swift
converter.maxDisparity = 0.02  // Down from 0.05
```

### Issue: Immersive mode doesn't activate

**Solution**: Ensure visionOS 1.0+ deployment target
```swift
@available(visionOS 1.0, *)
struct ImmersivePlayerScene: Scene { ... }
```

### Issue: 2D→3D conversion artifacts

**Solution**: Adjust depth parameters for content type
```swift
// For animated content
converter.depthStrength = 0.6
converter.convergence = 0.3

// For live action
converter.depthStrength = 1.2
converter.convergence = 0.7
```

## Future Enhancements

1. **Advanced Depth Estimation**: Integrate learned depth models (MiDaS, Monodepth2)
2. **Real-time Stereo Matching**: Correlation-based disparity maps
3. **Adaptive Quality**: Dynamic resolution based on device capability
4. **Haptic Feedback**: Hand tracking + haptic responses for interaction
5. **Spatial Audio**: Ambisonics decoding for immersive audio
6. **Network Streaming**: HLS/DASH adaptive bitrate for VR
7. **Eye Tracking**: Foveated rendering optimization

## References

- **Apple RealityKit**: https://developer.apple.com/documentation/realitykit
- **Metal Rendering**: https://developer.apple.com/documentation/metal
- **FFmpeg Demuxing**: https://ffmpeg.org/documentation.html
- **VR Video Formats**: https://www.w3.org/community/immersive-web/
- **Stereoscopic 3D**: https://en.wikipedia.org/wiki/Stereoscopy
- **Depth Estimation**: https://github.com/isl-org/MiDaS
