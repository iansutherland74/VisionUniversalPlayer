# VisionOS 26 Video Player

A production-ready video player build for visionOS 26 featuring hardware-accelerated video decoding, Metal-based rendering, and support for streaming H.264 and HEVC content over HTTP/HTTPS/FTP/WebDAV.

## Features

### Video Decoding
- ✅ **H.264 & HEVC Hardware Decoding** (VideoToolbox)
- ✅ **Remote Streaming** (HTTP, HTTPS, FTP, WebDAV)
- ✅ **Container Support** (MP4, MKV, TS, HLS)
- ✅ **Raw Annex-B Streams**
- ✅ **FFmpeg Demuxing** (libavformat)

### Rendering
- ✅ **Metal GPU Rendering** (NV12 YUV→RGB)
- ✅ **CVMetalTextureCache** (zero-copy pixel buffers)
- ✅ **Real-time Performance** (optimized for Vision Pro)

### UI/UX
- ✅ **Apple TV-Style Home Screen**
- ✅ **Fullscreen Player with HUD**
- ✅ **Live Statistics** (codec, resolution, bitrate, FPS)
- ✅ **Gesture Controls** (tap, long-press)
- ✅ **SwiftUI Interface**

### YouTube Integration
- ✅ **YouTube URL Detection** (watch, short, embed, shorts, live)
- ✅ **Automatic YouTube Thumbnail Fallback** (when no explicit thumbnail is provided)
- ✅ **Dedicated YouTube Playback Surface Routing**
- ⚠️ **Optional Native YouTube Playback via YouTubePlayerKit** (requires adding SPM dependency in Xcode)

### Debug & Testing
- ✅ **Unified Real-Time Debug System** (WebSocket relay to VS Code)
- ✅ **Automated E2E Test Suite** (preflight, session audit, report generation)

See [E2E_QUICK_START.md](E2E_QUICK_START.md) for end-to-end validation workflow.

## System Requirements

- **visionOS 2.0** or later (targeting 26)
- **Swift 5.9+**
- **Xcode 26.2**
- **FFmpeg** (libavformat, libavcodec, libavutil)

## Installation & Setup

### 1. Clone/Add Project

```bash
cd /Users/sutherland/vision\ ui/
# Project files are in VisionUniversalPlayer/
```

### 2. Install FFmpeg

Using Homebrew:
```bash
brew install ffmpeg
```

Or from [ffmpeg.org](https://ffmpeg.org/download.html)

### 3. Configure Xcode Project

**Create a new visionOS app in Xcode, then:**

1. Set **Deployment Target** to the visionOS deployment target provided by Xcode 26.2 for this app
2. Add build settings in Build Settings tab:

```
HEADER_SEARCH_PATHS = $(inherited) /opt/homebrew/include /usr/local/include
LIBRARY_SEARCH_PATHS = $(inherited) /opt/homebrew/lib /usr/local/lib
OTHER_LDFLAGS = $(inherited) -lswscale -lavformat -lavcodec -lavutil -lpthread
SWIFT_OBJC_BRIDGING_HEADER = VisionUniversalPlayer/VisionUniversalPlayer-Bridging-Header.h
```

3. Link Frameworks under Build Phases → Link Binary:
   - Metal
   - MetalKit
   - VideoToolbox
   - AVFoundation
   - Combine

4. Copy all Swift and C files into the Xcode project (drag-and-drop)

### 4. Build & Run

```bash
# In Xcode
Cmd + B  # Build
Cmd + R  # Run on visionOS simulator
```

### 5. Optional: Enable Native YouTube Playback

The app already detects YouTube URLs and routes them to a dedicated surface. To enable native YouTube playback:

1. In Xcode, open your project target and add a Swift Package dependency:
  - URL: https://github.com/SvenTiigi/YouTubePlayerKit.git
  - Version rule: Up to Next Major from 2.0.0
2. Ensure the package product is linked to the app target.
3. Build again.

If the package is not linked, the app shows a clear in-app fallback message instead of attempting FFmpeg playback for YouTube URLs.

### 6. Optional: Enable Archive Subtitle Imports

The subtitle importer supports plain text sidecars by default and can read ZIP/RAR bundles with optional package dependencies added in Xcode.

1. Add `ZIPFoundation`
  - URL: https://github.com/weichsel/ZIPFoundation.git
  - Version rule: Up to Next Major from 0.9.20
2. Add `UnrarKit`
  - URL: https://github.com/abbeycode/UnrarKit.git
  - Version rule: Up to Next Major from 5.7.0
3. Link both products to the app target.

Runtime behavior:
- ZIP sidecars still have a built-in fallback path, but `ZIPFoundation` is preferred when linked.
- RAR sidecars require `UnrarKit`; without it, the app reports that the dependency is missing instead of attempting host-only extraction.

App Store submission note for YouTube usage:
- Add this link to review notes: https://developers.google.com/youtube/terms/api-services-terms-of-service

## Project Structure

```
VisionUniversalPlayer/
│
├── VisionUniversalPlayerApp.swift          # Entry point
│
├── Models/
│   ├── MediaItem.swift                    # Media metadata
│   └── PlayerStats.swift                  # Real-time statistics
│
├── Engine/
│   ├── NALUnit.swift                      # H.264/HEVC NAL types
│   ├── NALParser.swift                    # Annex-B parser
│   ├── VideoDecoder.swift                 # VideoToolbox wrapper
│   ├── FFmpegBridge.[hc]                  # C bridge to FFmpeg
│   ├── FFmpegDemuxer.swift                # Remote demuxing
│   ├── FFmpegEngine.swift                 # Demuxer + decoder
│   ├── RawStreamEngine.swift              # Raw byte streaming
│   ├── HLSClient.swift                    # HLS playlist parser
│   ├── PlayerViewModel.swift              # View model
│   └── module.modulemap                   # C module mapping
│
├── Rendering/
│   ├── MetalVideoRenderer.swift           # Metal renderer
│   ├── MetalHostView.swift                # MTKView wrapper
│   └── Shaders.metal                      # NV12→RGB shader
│
├── UI/
│   ├── RootView.swift                     # Home screen
│   ├── MediaCard.swift                    # Media item card
│   ├── MediaRow.swift                     # Horizontal row
│   ├── DetailView.swift                   # Detail screen
│   ├── PlayerScreen.swift                 # Fullscreen player
│   ├── PlayerControls.swift               # Playback controls
│   ├── PlayerHUD.swift                    # Stats overlay
│   └── MetalVideoView.swift               # Metal view adapter
│
├── BUILD_CONFIGURATION.md                 # Detailed build guide
├── Info.plist                             # App configuration
├── VisionUniversalPlayer-Bridging-Header.h # Swift-C bridge
└── this file (README.md)
```

## Usage

### Playing Media

```swift
let item = MediaItem(
    title: "Sample Video",
    description: "H.264 over HTTP",
    url: URL(string: "http://example.com/video.mp4")!,
    sourceKind: .ffmpegContainer,
    codec: .h264
)

// In PlayerScreen
await viewModel.playMedia(item)
```

### Supported Codecs
- **H.264** (AVC, Annex-B)
- **HEVC** (H.265, Annex-B)

### Supported Protocols
- HTTP / HTTPS
- FTP
- WebDAV
- Local streaming with Annex-B byte streams

### Supported Containers
- MP4 (fMP4)
- HLS (m3u8 with TS/fMP4 segments)
- MKV (Matroska)
- TS (MPEG-2 Transport Stream)
- Raw H.264/HEVC Annex-B

## Architecture

### Decoding Pipeline

```
URL (http/https/ftp/webdav/etc)
  ↓ [FFmpeg Demuxer OR URLSession Raw Stream]
  ↓ Annex-B NAL units + PTS
  ↓ [NALParser]
  ↓ H.264/HEVC NAL units
  ↓ [VideoDecoder] ← VideoToolbox Hardware Decoder
  ↓ CVPixelBuffer (NV12)
  ↓ [MetalVideoRenderer] ← GPU Rendering
  ↓ SwiftUI View
```

### Threading Model

- **Main Thread**: UI Updates, Gesture Handling
- **Decoder Queue**: VideoToolbox decoding (GCD queue)
- **Streaming Queue**: FFmpeg/URLSession downloads
- **Metal Render Queue**: Implicit in MTKView delegate

All communication via Combine publishers (thread-safe).

## Debug Validation

- Unified debug integration checklist: E2E_DEBUG_VALIDATION_CHECKLIST.md
- Run this checklist on device or simulator to validate relay flow from app runtime to the VS Code debug panel.

## Performance

- **Decoding**: Hardware-accelerated (VideoToolbox)
- **Rendering**: GPU-accelerated (Metal)
- **Memory**: Streaming buffers (~64KB chunks)
- **Latency**: ~100-200ms end-to-end (varies by network)

## Customization

### Adding More Codecs

Edit `CodecType` enum in [Models/MediaItem.swift](Models/MediaItem.swift):
```swift
enum CodecType: String, Codable, CaseIterable {
    case h264
    case hevc
    // case vp9  // requires different decoder
}
```

### Changing UI Theme

Modify color constants in UI files. SwiftUI uses system colors by default.

### Custom Shaders

Edit `Shaders.metal` to change YUV color space or add effects:
```metal
// Example: Brightness/Contrast adjustment
float brightness = 1.1;
return float4(rgb * brightness, 1.0);
```

## Troubleshooting

### Build Errors

**"Module FFmpegBridge not found"**
- Ensure `VisionUniversalPlayer-Bridging-Header.h` is set in Build Settings
- Verify Bridging Header path is correct

**"Linker command failed"**
- Check FFmpeg brew installation: `brew list ffmpeg`
- Verify header/library paths in Build Settings
- Try `brew reinstall ffmpeg`

### Runtime Errors

**"Failed to open FFmpeg demuxer"**
- Check URL is accessible and reachable
- Verify FFmpeg supports the protocol (HTTP/FTP/etc)
- Check network permissions in Info.plist

**"VideoToolbox decoder error"**
- H.264/HEVC hardware decoder may not be available on all devices

**"Archive support requires linking UnrarKit to the app target"**
- Add the `UnrarKit` package product to the visionOS target in Xcode
- Rebuild after package resolution completes

**ZIP bundles import inconsistently across environments**
- Add `ZIPFoundation` to standardize ZIP parsing across simulator and device builds
- If you do not link it, the app falls back to the built-in ZIP reader for deflate/stored entries
- Falls back gracefully; check PlayerStats.error

**"Metal shader compilation error"**
- Verify Metal shader syntax in `MetalVideoRenderer.setupInlineShaders()`
- Check Metal version compatibility

## FFmpeg Integration

FFmpeg is used **only for demuxing** and bitstream filtering:

1. Opens remote URL with `avformat_open_input()`
2. Finds video stream from container
3. Applies h264_mp4toannexb / hevc_mp4toannexb bitstream filter
4. Outputs Annex-B NAL units + PTS
5. Swift VideoDecoder does actual decoding via VideoToolbox

**Benefits:**
- ✅ No software decoding overhead
- ✅ Supports many container formats
- ✅ Hardware acceleration preserved
- ✅ Small binary footprint

## Testing

### Local Test Stream

```bash
# Generate test H.264 stream (macOS)
ffmpeg -f lavfi -i testsrc=size=1920x1080:duration=60 \
  -vf format=yuv420p -c:v libx264 \
  -bsf h264_mp4toannexb \
  http://127.0.0.1:8000/stream.h264

# Serve via Python
python3 -m http.server 8000
```

Then load in app:
```swift
MediaItem(
    title: "Test Stream",
    url: URL(string: "http://127.0.0.1:8000/stream.h264")!,
    sourceKind: .rawAnnexB,
    codec: .h264
)
```

## Legal & Credits

- **Metal/MetalKit**: Apple
- **VideoToolbox**: Apple
- **FFmpeg**: FFmpeg Project (LGPL)
- **SwiftUI**: Apple

Ensure FFmpeg license compliance in your app distribution.

## License

MIT License - See LICENSE file

## Support & Contributing

For issues, suggestions, or PRs:
1. Check troubleshooting section
2. Review BUILD_CONFIGURATION.md
3. File issue with reproduction steps

---

**Last Updated**: April 2026  
**Target**: visionOS 26  
**Xcode**: 26.2  
**Swift**: 5.9+
