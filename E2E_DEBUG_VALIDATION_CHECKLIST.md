# VisionUniversalPlayer Unified Debug System E2E Checklist

Date: 2026-04-09
Purpose: validate end-to-end debug flow from app runtime -> websocket relay -> VS Code panel.

## Preconditions

- Build configuration is DEBUG.
- Extension dependencies are installed and compile succeeds.
- Command Vision: Open Debug Console is available.
- Debug panel is open before starting device scenarios.

## Automated Smoke Gate (CLI)

Run this first to verify websocket relay behavior without UI interaction:

```bash
bash ./scripts/e2e-preflight.sh
```

Or run only the relay smoke gate:

```bash
cd ../vscode-extension
node scripts/e2e-relay-smoke.mjs
```

Expected output contains:

- PASS: relay broadcast received by panel client
- A wrapped packet with type=event and message=E2E smoke event
- Coverage PASS: all required event phrases found

Smoke Gate Pass/Fail: ____

## Session Audit (Recommended During Device Run)

Simplest entry point (recommended):

```bash
bash ./scripts/start-e2e-device-audit.sh --mode local
```

Relay mode (when panel relay is already up):

```bash
bash ./scripts/start-e2e-device-audit.sh --mode relay --require-connect true
```

Run this in parallel while interacting with the app to capture relay events and validate schema automatically:

```bash
cd ../vscode-extension
node scripts/e2e-session-audit.mjs --duration-ms 180000 --min-events 1 --out ../VisionUniversalPlayer/docs/e2e-session-audit.json
```

If the relay starts slightly later, increase connect timeout:

```bash
cd ../vscode-extension
node scripts/e2e-session-audit.mjs --duration-ms 180000 --min-events 1 --connect-timeout-ms 30000 --out ../VisionUniversalPlayer/docs/e2e-session-audit.json
```

To fail immediately if relay connectivity is missing, add:

```bash
cd ../vscode-extension
node scripts/e2e-session-audit.mjs --duration-ms 180000 --min-events 1 --require-connect --out ../VisionUniversalPlayer/docs/e2e-session-audit.json
```

Optional strict mode (fails unless every checklist phrase is observed):

```bash
cd ../vscode-extension
node scripts/e2e-session-audit.mjs --duration-ms 300000 --strict-checklist --out ../VisionUniversalPlayer/docs/e2e-session-audit-strict.json
```

If the VS Code panel relay is not running, use local audit-server mode instead:

```bash
cd ../vscode-extension
node scripts/e2e-session-audit-local.mjs --duration-ms 180000 --min-events 1 --out ../VisionUniversalPlayer/docs/e2e-session-audit-local.json
```

Quick local smoke (self-inject one test event):

```bash
cd ../vscode-extension
node scripts/e2e-session-audit-local.mjs --duration-ms 3000 --inject-smoke --out ../VisionUniversalPlayer/docs/e2e-session-audit-local-smoke.json
```

Summarize any generated report quickly:

```bash
node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local.json
```

## Environment Setup Validation

1. Open extension host and run Vision: Open Debug Console.
Expected: status shows relay ready and panel stays connected.
Pass/Fail: ____

2. Launch app in DEBUG on simulator/device.
Expected: first lifecycle/system logs appear within 5 to 10 seconds.
Pass/Fail: ____

3. Verify panel controls are responsive.
Expected: category filter, severity filter, search, auto-scroll toggle, clear, export all operate without UI errors.
Pass/Fail: ____

## Subsystem Test Matrix

Record Pass/Fail for each row and include one event sample ID or message text.

| Area | Action | Expected Category | Minimum Expected Event |
|---|---|---|---|
| Playback Core | Toggle play/pause | appLifecycle | Playback toggled |
| Voice | Start/stop listening | voice | Voice listening started, Voice listening stopped |
| Voice | Say play/pause/seek/volume/hud/subtitle commands | voice | Voice command recognized |
| HLS | Load HLS media and parse variants | hls | Parsed HLS playlist or Parsed HLS master playlist |
| HLS | Trigger variant switch | hls | Built HLS variant playlist + temporary playlist write |
| Network | Trigger transient network disruption | network | reconnecting warning or transport failure |
| Demux | Start FFmpeg demux path | demuxer | Starting FFmpeg engine / demuxer connected |
| Decoder | Force unsupported codec path or decode error | decoder | Unsupported codec or decode error event |
| Metal Renderer | Render flat mode and switch VR mode | renderer or metal | Configured VR format |
| VR Renderer | Enter immersive VR render | vr | VR render mode changed |
| 2D to 3D | Enable conversion and render | depth3D | Starting 2D to 3D conversion |
| Spatial Probe | Probe local spatial media | decoder | Spatial probe completed |
| APMP | Native stereo enqueue path | immersive | APMP format description updated |
| Audio Engine | Change sync and lip-sync controls | sync and lipSync | offset changed and calibration changed |
| Audio Spatial | Toggle head tracking and room controls | spatialAudio | Head tracking changed / room size changed |
| Atmos/Mixer | Toggle Atmos preference and downmix mode | atmos and audioEngine | Atmos metadata updated / downmix changed |
| IPTV Playlist | Load playlist URL and pasted playlist | playlist and iptv | Loading IPTV playlist / Loaded IPTV playlist |
| Xtream | Fetch categories and streams | xtream | Fetched Xtream categories / streams |
| EPG | Load XMLTV source | epg | Loading EPG / Loaded EPG |
| Gestures | Single tap, double tap, pinch | gestures | HUD toggle, cinema toggle, pinch detected |
| Immersive Scene | Open and dismiss immersive space | immersive | opening/dismissing events |
| Window Geometry | Trigger geometry preference update | navigation | geometry update warning on failure only |
| Subtitle Sidecar | Import srt/vtt/zip/rar test files | settings | Parsing subtitle sidecar and parsed cue count |
| Advisory UI | Trigger advisory streamer updates | hud | Playback advisory finalized |

Result notes:

- Playback Core: ________________________________
- Voice: ________________________________________
- HLS: __________________________________________
- Network/Demux/Decoder: _________________________
- Rendering/VR/3D/APMP: __________________________
- Audio/Spatial/Atmos: ___________________________
- IPTV/Xtream/EPG: _______________________________
- Gestures/Immersive/UI: _________________________
- Subtitle/Advisory: _____________________________

## Panel Feature Validation

1. Severity filter
- Action: select warning and error only.
- Expected: info and trace entries disappear.
- Pass/Fail: ____

2. Category filter
- Action: select one category such as hls.
- Expected: only hls rows are visible.
- Pass/Fail: ____

3. Search
- Action: search for phrase Playback toggled.
- Expected: matching rows only.
- Pass/Fail: ____

4. Auto-scroll
- Action: toggle off, generate events, verify list does not jump.
- Expected: stable scroll position while off.
- Pass/Fail: ____

5. Export
- Action: export logs to JSON.
- Expected: file downloads with valid JSON array and event fields.
- Pass/Fail: ____

## Required Event Schema Checks

Validate sampled events include:

- id
- timestamp
- category
- severity
- message
- thread
- context object

Schema Pass/Fail: ____

## Performance Spot Check

1. Burst 200 to 500 events in < 10s via rapid interactions.
Expected: panel remains responsive, no relay crash.
Pass/Fail: ____

2. Sustained run for 5 minutes during playback.
Expected: events continue streaming, no websocket disconnect loop.
Pass/Fail: ____

## Known Non-Issues

- Data-only model files do not emit logs directly by design.
- Centralized console print inside debug bus sink is intentional in DEBUG.

## Sign-off

- E2E Owner: __________________
- Device/OS: __________________
- VS Code version: ____________
- Extension build hash/date: ____
- Final verdict: PASS / FAIL
- Follow-up actions: ______________________________
