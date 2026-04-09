# VisionUniversalPlayer E2E Testing Quick Start

**Status:** All automation ready. Device interaction phase remaining.

## Phase 1: Automated Prechecks (Run Once)

```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
bash ./scripts/e2e-preflight.sh
```

Expected output:
- Extension pretest PASS (compile + lint)
- Relay smoke gate PASS
- Event phrase coverage PASS
- Subtitle regression PASS
- Swift package builds PASS

## Phase 2: Device Session Capture (Run During Interaction)

**Start the audit listener** (choose one):

### Option A: Local Server Mode (Recommended)
```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
bash ./scripts/start-e2e-device-audit.sh --mode local
```

Listens on `ws://localhost:9002` for 5 minutes. No external dependencies.

### Option B: Panel Relay Mode
(Only if VS Code panel relay is already running)
```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
bash ./scripts/start-e2e-device-audit.sh --mode relay --require-connect true
```

Connects to running relay panel on port 9002.

### Option C: Manual Command (Full Control)
```bash
cd '/Users/sutherland/vision ui/vscode-extension'
node scripts/e2e-session-audit-local.mjs --duration-ms 300000 --min-events 1 --strict-checklist --out ../VisionUniversalPlayer/docs/e2e-session-audit.json
```

## Phase 3: Device Interaction (During Capture Window)

Open VisionUniversalPlayer on device/simulator in DEBUG build.

Execute interactions from the matrix in [E2E_DEBUG_VALIDATION_CHECKLIST.md](E2E_DEBUG_VALIDATION_CHECKLIST.md):

- Playback: toggle play/pause
- Voice: start/stop listening, speak commands
- HLS: load variants, trigger switch
- Network: simulate disruption
- Rendering: switch VR mode
- Audio: adjust sync, spatial settings
- IPTV: load playlist, fetch Xtream
- Gestures: tap, double-tap, pinch
- Immersive: open/close space
- Subtitles: import sidecar files
- UI: check advisory finalization

Spend time in each area. Capture windows are 5 minutes.

## Phase 4: Report Generation & Analysis

When audit completes, a timestamped JSON report is written to `./docs/`.

### Quick Summary
```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local-*.json
```

(Use the most recent timestamped file.)

### Expected Output
- Full PASS: All checklist phrases found, no schema errors
- PARTIAL: Some phrases missing (needs more interaction time)
- INCOMPLETE: No events captured (verify app DEBUG mode + audit listener connectivity)

## Phase 5: Triage & Iterate

If PARTIAL or gaps remain:
1. Note which checklist phrases are missing
2. Interact with those subsystems longer in a second run
3. Rerun audit and summary

If all PASS:
1. Fill in the sign-off section in [E2E_DEBUG_VALIDATION_CHECKLIST.md](E2E_DEBUG_VALIDATION_CHECKLIST.md)
2. Archive the report: `cp ./docs/e2e-session-audit-local-*.json ./docs/e2e-session-audit-final.json`

## Quick Smoke Test (No Device Needed)

Validate tooling without a live device:

```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
bash ./scripts/start-e2e-device-audit.sh --mode local --duration-ms 2500 --inject-smoke --strict-checklist false
node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local-*.json
```

Expected: 1 event ("Playback toggled"), 0 schema errors, PARTIAL status.

## Troubleshooting

### "Unable to connect to relay"
- Expected in local mode (local mode doesn't need relay)
- In relay mode, verify VS Code extension panel is open and running

### "No events captured"
- Verify app is running in DEBUG build (`#if DEBUG` gates are active)
- Check app logs for "DebugCategory" messages being emitted
- Verify audit listener is accessible on port 9002

### "Schema issues found"
- Check app is emitting all required event fields: id, timestamp, category, severity, message, thread, context
- Run extended capture (longer duration) to capture more event samples

### Report file not written
- Verify you have write permission to `./docs/`
- Check audit output for path confirmation

## Files Reference

**Automation:**
- [scripts/e2e-preflight.sh](scripts/e2e-preflight.sh) - All prechecks
- [scripts/start-e2e-device-audit.sh](scripts/start-e2e-device-audit.sh) - Unified launcher
- [scripts/e2e-report-summary.mjs](scripts/e2e-report-summary.mjs) - Result triage
- [scripts/e2e-event-coverage.sh](scripts/e2e-event-coverage.sh) - Source-level validation

**Extension (via ../vscode-extension):**
- [scripts/e2e-session-audit-local.mjs](../vscode-extension/scripts/e2e-session-audit-local.mjs) - Local server
- [scripts/e2e-session-audit.mjs](../vscode-extension/scripts/e2e-session-audit.mjs) - Relay client

**Docs:**
- [E2E_DEBUG_VALIDATION_CHECKLIST.md](E2E_DEBUG_VALIDATION_CHECKLIST.md) - Full spec
- [docs/e2e-session-audit-*.json](docs/) - Generated reports

## Next Step

```bash
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'
bash ./scripts/start-e2e-device-audit.sh --mode local
```

Then interact with the app for 5 minutes covering the matrix items.

When done, run:
```bash
node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local-*.json
```

Share the status code and any missing phrases, and I'll patch immediately.
