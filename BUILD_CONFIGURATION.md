# VisionOS 26 Build Configuration Guide

## Project Setup

This project targets **visionOS 26** with Metal rendering and VideoToolbox hardware decoding.

Toolchain baseline: **Xcode 26.2**.

### Required Build Settings

**In Xcode:**

1. **Select Target** → VisionUniversalPlayer
2. **Build Settings**:
   - **Supported Platforms**: visionOS
   - **Deployment Target**: the visionOS deployment target selected in Xcode 26.2 for this build
   - **Swift Language Version**: 5.9+
   
### Linked Frameworks

Add to Build Phases → Link Binary With Libraries:

- **Metal**
- **MetalKit**
- **VideoToolbox**
- **AVFoundation**
- **Combine**
- **SwiftUI**

### C Dependencies (FFmpeg)

Ensure FFmpeg is properly linked:

1. **Install FFmpeg with Homebrew** (or use static libraries):
   ```bash
   brew install ffmpeg
   ```

2. **Add to Build Settings**:
   - **Header Search Paths**: `/opt/homebrew/include` (or your FFmpeg path)
   - **Library Search Paths**: `/opt/homebrew/lib`
   - **Other Linker Flags**: 
     ```
     -lswscale -lavformat -lavcodec -lavutil -lpthread
     ```

### Shader Compilation

Shaders compile inline from the Metal source in `MetalVideoRenderer.swift`. No separate .metallib file is required.

### File Organization

```
VisionUniversalPlayer/
├── VisionUniversalPlayerApp.swift
├── Models/
├── Engine/
│   ├── VideoDecoder.swift (VideoToolbox)
│   ├── FFmpegBridge.h/c (libavformat)
│   ├── FFmpegEngine.swift
│   └── ... [other engines]
├── Rendering/
│   ├── MetalVideoRenderer.swift
│   ├── MetalHostView.swift
│   └── Shaders.metal
└── UI/
    └── [SwiftUI views]
```

### VisionOS-Specific Notes

- **Metal Rendering**: Uses MTKView via UIViewRepresentable → MetalViewContainer
- **No ARKit Required**: Pure Metal + SwiftUI for video display
- **Threading**: All decoding and rendering happens on dedicated queues
- **Memory**: Streaming buffers limit memory footprint for long videos
- **Gestures**: Tap to toggle controls, long-press for HUD stats

### Building

```bash
xcodebuild \
  -scheme VisionUniversalPlayer \
  -destination "generic/platform=visionOS" \
  -configuration Release
```

Or in Xcode: Select visionOS target → Build (⌘B)

### Deployment

1. Sign with a valid Apple ID
2. Select visionOS device/simulator
3. Run (⌘R) or build for deployment

### Troubleshooting

**FFmpeg Link Errors:**
- Verify `/opt/homebrew/lib` contains `libavformat.a` (or .dylib)
- Add `-L/opt/homebrew/lib -L/opt/homebrew/opt/ffmpeg/lib` to linker flags

**Metal Shader Compilation Errors:**
- Check Metal syntax in `setupInlineShaders()` in `MetalVideoRenderer.swift`
- Ensure inline shader text matches Metal standard

**VideoToolbox Errors:**
- H.264/HEVC hardware decoder availability is device-dependent
- Falls back gracefully with error messages

**Thread Safety:**
- All decoder/rendering happens on dispatch queues
- Main thread used only for UI updates
