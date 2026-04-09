# Xcode Setup Guide for VisionOS 26 Video Player

## Complete Step-by-Step Setup

### Step 1: Create Project in Xcode

1. Open Xcode 26.2
2. File → New → Project
3. Choose **Vision OS** template
   - App name: "VisionUniversalPlayer"
   - Team: Your team (or None)
   - Organization: Your choice
   - Bundle Identifier: `com.company.visionuniversalplayer`
   - Interface: **SwiftUI**
   - Life Cycle: **SwiftUI App**
4. Choose location: `/Users/sutherland/vision ui/`
5. Click "Create"

### Step 2: Remove Default Files

Delete these auto-generated files from the project:
- `VisionUniversalPlayerApp.swift` (we'll use ours)
- `ContentView.swift`
- `Preview Content/` folder

### Step 3: Add Project Files

1. In Finder, open `/Users/sutherland/vision ui/VisionUniversalPlayer/`
2. Drag all folders into Xcode project (onto project root)
   - Models/
   - Engine/
   - Rendering/
   - UI/
3. Ensure "Copy items if needed" is NOT checked
4. Target membership: "VisionUniversalPlayer" app

### Step 4: Build Settings Configuration

1. Select **VisionUniversalPlayer** target in Xcode
2. Go to **Build Settings** tab
3. Search for each setting and update:

#### Platform Settings
```
Supported Platforms: visionOS
Deployment Target: the visionOS deployment target selected in Xcode 26.2 for this target
IPHONEOS_DEPLOYMENT_TARGET: should not be present for this visionOS-only target
```

#### Swift Compilation
```
Swift Language Version: Swift 5.9
Enable Module Verifier: Yes
```

#### C FFmpeg Integration
```
HEADER_SEARCH_PATHS = $(inherited) /opt/homebrew/include /usr/local/include
LIBRARY_SEARCH_PATHS = $(inherited) /opt/homebrew/lib /usr/local/lib
OTHER_LDFLAGS = $(inherited) -lswscale -lavformat -lavcodec -lavutil -lpthread
```

#### Bridging Header
```
SWIFT_OBJC_BRIDGING_HEADER = VisionUniversalPlayer/VisionUniversalPlayer-Bridging-Header.h
```

#### Code Generation
```
Bridging Header: VisionUniversalPlayer/VisionUniversalPlayer-Bridging-Header.h
Module Map File: VisionUniversalPlayer/Engine/module.modulemap
```

### Step 5: Link Frameworks

1. Select target
2. Build Phases
3. Expand "Link Binary With Libraries"
4. Click "+" button
5. Add these frameworks:
   - **Metal**
   - **MetalKit**
   - **VideoToolbox**
   - **AVFoundation**
   - **Combine**
   (All already in visionOS SDK)

### Step 5A: Add Optional Archive Packages

If you want subtitle imports from archives inside the app runtime:

1. In Xcode, select the project root
2. Open the **Package Dependencies** tab
3. Add these packages:

#### ZIPFoundation
```text
URL: https://github.com/weichsel/ZIPFoundation.git
Version: Up to Next Major from 0.9.20
Product: ZIPFoundation
```

#### UnrarKit
```text
URL: https://github.com/abbeycode/UnrarKit.git
Version: Up to Next Major from 5.7.0
Product: UnrarKit
```

4. Link both package products to the `VisionUniversalPlayer` app target

Behavior after linking:
- `ZIPFoundation` is preferred for ZIP subtitle bundles
- `UnrarKit` enables native RAR subtitle extraction on Apple platforms
- If `UnrarKit` is not linked, RAR imports fail with a clear in-app dependency message instead of using a macOS-only process fallback

### Step 6: Info.plist Configuration

1. Replace the default Info.plist with our provided one:
   - Copy [Info.plist](Info.plist) to project root
   - In Xcode: File → Add Files to Project
   - Select Info.plist
   - Target membership: check VisionUniversalPlayer app

Or manually configure:
```
Supported interface orientations: Portrait only
NSLocalNetworkUsageDescription: "This app streams video from network sources"
NSBonjourServices: _http._tcp, _https._tcp
```

### Step 7: Install FFmpeg

#### Option A: Homebrew (Recommended)
```bash
brew install ffmpeg
brew list ffmpeg  # Verify installation
# Should show paths like /opt/homebrew/lib/libavformat.a
```

#### Option B: Manual Installation
1. Download from [ffmpeg.org](https://ffmpeg.org/download.html)
2. Extract to `/opt/ffmpeg/` or `/usr/local/`
3. Update path in Build Settings accordingly

#### Verify Installation
```bash
# Check libraries exist
ls -la /opt/homebrew/lib/libav*.{a,dylib}

# Check headers exist
ls -la /opt/homebrew/include/libav*.h
```

### Step 8: Build & Test

1. Select Target: **VisionUniversalPlayer**
2. Select Destination: **visionOS Simulator** (or Vision Pro device)
3. Product → Build (⌘B)

#### Expected Build Log
```
Compiling Swift...
Linking...
Embed Frameworks...
Signing…
Build complete
```

### Troubleshooting Build Issues

#### "Use of undeclared identifier 'ffmpeg_open'"
- **Fix**: Verify Bridging Header path in Build Settings
- Check: `SWIFT_OBJC_BRIDGING_HEADER = VisionUniversalPlayer/VisionUniversalPlayer-Bridging-Header.h`

#### "Linker command failed (exit code 1)"
- **Check FFmpeg paths**:
  ```bash
  # Find actual brew paths
  brew --prefix ffmpeg
  # Should output: /opt/homebrew/opt/ffmpeg
  
  # Update paths if different
  ```
- **Re-verify linking**:
  ```
  LIBRARY_SEARCH_PATHS = $(inherited) /opt/homebrew/lib
  OTHER_LDFLAGS = $(inherited) -lswscale -lavformat -lavcodec -lavutil -lpthread
  ```

#### "Module 'VisionUniversalPlayer' has conflicting definitions"
- **Fix**: Clean build folder (⇧⌘K)
- Remove derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

#### "VideoToolbox not available"
- **Fix**: Ensure visionOS deployment target is 2.0+
- VideoToolbox is built-in to visionOS

### Step 9: Run on Simulator/Device

1. Select visionOS Simulator or connected Vision Pro
2. Product → Run (⌘R)
3. App should launch with home screen

### Customizing Sample Media

Edit [Models/MediaItem.swift](Models/MediaItem.swift) to change sample media:

```swift
static let samples: [MediaItem] = [
    MediaItem(
        title: "Your Video",
        description: "Your description",
        url: URL(string: "http://your-server.com/video.mp4")!,
        sourceKind: .ffmpegContainer,
        codec: .h264,
        thumbnailURL: URL(string: "http://...")
    ),
    // Add more items...
]
```

### Optional: Create Scheme

For easier switching between Debug/Release:

1. Product → Scheme → Edit Scheme
2. Create variants:
   - **Debug**: All optimizations off, console output
   - **Release**: Full optimizations, minimal logging
3. Set different build settings for each

### Performance Optimization (Release Build)

In Build Settings for Release configuration:

```
Optimize for Speed: Yes (-O3)
Enable LTO: Yes
Strip Linked Product: Yes
Dead Code Stripping: Yes
```

### Next Steps

1. ✅ Verify app launches
2. ✅ Test video playback with sample media
3. ✅ Check Metal rendering (should see video in fullscreen)
4. ✅ Verify stats display (tap → long press for HUD)
5. ✅ Replace sample URLs with your streaming server

### Getting Help

If build fails:
1. Clean: ⇧⌘K
2. Check Build Settings against this guide
3. Verify FFmpeg installation: `brew list ffmpeg`
4. Check file structure matches project outline
5. Review [BUILD_CONFIGURATION.md](BUILD_CONFIGURATION.md)

---

**Version**: visionOS 26 compatible  
**Xcode**: 26.2  
**Swift**: 5.9+
