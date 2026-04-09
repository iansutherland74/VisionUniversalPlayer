#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

search_roots=(
  "$PLAYER_DIR/Engine"
  "$PLAYER_DIR/UI"
  "$PLAYER_DIR/Rendering"
  "$PLAYER_DIR/IPTV"
)

missing=0

declare -a checks=(
  "Playback toggled"
  "Voice listening started"
  "Voice listening stopped"
  "Voice command recognized"
  "Parsed HLS playlist"
  "Parsed HLS master playlist"
  "Built HLS variant playlist"
  "Starting FFmpeg engine"
  "FFmpeg demuxer connected"
  "Unsupported codec"
  "Configured VR format"
  "VR render mode changed"
  "Starting 2D to 3D conversion"
  "Spatial probe completed"
  "APMP format description updated"
  "Audio sync offset changed"
  "Lip-sync calibration changed"
  "Head tracking changed"
  "Room size changed"
  "Atmos metadata updated"
  "Downmix mode changed"
  "Loading IPTV playlist"
  "Loaded IPTV playlist"
  "Fetched Xtream categories"
  "Fetched Xtream streams"
  "Loading EPG"
  "Loaded EPG"
  "Single tap toggled HUD"
  "Double tap toggled cinema mode"
  "Pinch gesture detected"
  "Opening immersive space"
  "Dismissing immersive space"
  "Window geometry update failed"
  "Parsing subtitle sidecar"
  "Subtitle sidecar parsed"
  "Playback advisory finalized"
)

echo "E2E event coverage scan"
for phrase in "${checks[@]}"; do
  if grep -RFn -- "$phrase" "${search_roots[@]}" > /dev/null; then
    echo "PASS: $phrase"
  else
    echo "FAIL: missing phrase -> $phrase"
    missing=$((missing + 1))
  fi
done

if [[ $missing -gt 0 ]]; then
  echo "Coverage FAIL: $missing required event phrase(s) missing"
  exit 1
fi

echo "Coverage PASS: all required event phrases found"
