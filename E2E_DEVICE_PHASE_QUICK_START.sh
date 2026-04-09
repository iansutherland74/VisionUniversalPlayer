#!/usr/bin/env bash
# VisionUniversalPlayer E2E Device Test — Quick Reference
# One-page guide for running the device phase

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║         VISIONUNIVERSALPLAYER E2E DEBUG SYSTEM — DEVICE PHASE                ║
║                          ONE-PAGE QUICK REFERENCE                            ║
╚══════════════════════════════════════════════════════════════════════════════╝

STEP 1: OPEN TERMINAL
────────────────────────────────────────────────────────────────────────────────
cd '/Users/sutherland/vision ui/VisionUniversalPlayer'


STEP 2: START AUDIT LISTENER (5-minute session)
────────────────────────────────────────────────────────────────────────────────
bash ./scripts/start-e2e-device-audit.sh --mode local --duration-ms 300000

Expected output:
  "Listening for debug events on ws://localhost:9002"
  [... waiting ...]


STEP 3: LAUNCH APP ON DEVICE/SIMULATOR (in separate terminal)
────────────────────────────────────────────────────────────────────────────────
• Build configuration: DEBUG
• Build scheme: VisionUniversalPlayer
• Destination: visionOS Simulator 2.0 (or actual device)


STEP 4: INTERACT WITH APP FOR 5 MINUTES
────────────────────────────────────────────────────────────────────────────────
Follow the interaction matrix in: E2E_DEBUG_VALIDATION_CHECKLIST.md

Quick checklist:
  □ Tap to toggle playback (HUD should appear/disappear)
  □ Speak voice command (should trigger voice listening)
  □ Pinch gesture to zoom
  □ Play video content (triggers HLS parsing, FFmpeg)
  □ Tap cinema icon (triggers cinema mode)
  □ Open settings (triggers settings updates)
  □ Swipe to navigate (triggers gestures)
  □ Try immersive mode if available (opens/closes space)
  □ Load IPTV content if configured
  □ View subtitles if available


STEP 5: WAIT FOR LISTENER TO FINISH (auto-generates report)
────────────────────────────────────────────────────────────────────────────────
Listener will automatically close after 300 seconds.
Report saved to: docs/e2e-session-audit-local-TIMESTAMP.json


STEP 6: ANALYZE REPORT (back in terminal)
────────────────────────────────────────────────────────────────────────────────
node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local-*.json

Output will show:
  STATUS: PASS       (exit code 0)   ✓ All 36 phrases captured
  STATUS: PARTIAL    (exit code 3)   ⚠ Some phrases missing
  STATUS: INCOMPLETE (exit code 2)   ✗ No events captured


STEP 7: INTERPRET RESULTS
────────────────────────────────────────────────────────────────────────────────

Exit Code 0 — FULL PASS ✓
  All 36 required phrases captured + schema valid
  → Ready for integration
  → No further action needed

Exit Code 3 — PARTIAL PASS ⚠
  Some events captured but missing phrases
  → Check "Missing checklist phrases" section
  → Common causes:
     • Didn't interact with all 10 feature areas
     • Interaction was too brief (22 seconds each minimum)
     • Feature not available on test device/simulator
  → Solution: Re-run with longer duration or more thorough interaction

Exit Code 2 — NO EVENTS ✗
  Listener captured no events
  → Check:
     1. Is app running in DEBUG mode? (check Xcode build logs)
     2. Is listener still running? (should see output in terminal)
     3. Network connectivity? (localhost :9002 should be reachable)
  → Solution: Restart both listener and app, ensure DEBUG=1


STEP 8: SHARE RESULTS (if needed)
────────────────────────────────────────────────────────────────────────────────
If exit code is not 0:
  1. Copy the "Missing checklist phrases" list
  2. Share exit code + missing phrases with agent
  3. Agent will patch instrumentation (5 min turnaround)
  4. Re-run device phase with updated code


═══════════════════════════════════════════════════════════════════════════════

TOTAL TIME ESTIMATE: ~10 minutes (5 min listening + interaction + 1 min analysis)

TROUBLESHOOTING: See E2E_PRODUCTION_READY.md section "Known Limitations"

═══════════════════════════════════════════════════════════════════════════════

EOF
