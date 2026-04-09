#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
RUNNER="$TMP_DIR/subtitle-sidecar-regression"
PLAIN_SRT="$TMP_DIR/sample.srt"
ZIP_DIR="$TMP_DIR/zip-fixture"
ZIP_FILE="$TMP_DIR/sample-subtitles.zip"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$ZIP_DIR"

cat > "$PLAIN_SRT" <<'EOF'
1
00:00:01,000 --> 00:00:02,000
Hello from subtitles.

2
00:00:03,000 --> 00:00:04,500
Archive parsing still works.
EOF

cp "$PLAIN_SRT" "$ZIP_DIR/sample.srt"
/usr/bin/zip -q -0 -j "$ZIP_FILE" "$ZIP_DIR/sample.srt"

swiftc \
  "$ROOT_DIR/Debug/DebugSeverity.swift" \
  "$ROOT_DIR/Debug/DebugCategory.swift" \
  "$ROOT_DIR/Debug/DebugEvent.swift" \
  "$ROOT_DIR/Debug/DebugEventBus.swift" \
  "$ROOT_DIR/Engine/SubtitleSidecar.swift" \
  "$ROOT_DIR/scripts/subtitle-sidecar-regression.swift" \
  -o "$RUNNER"

if [[ $# -gt 0 ]]; then
  "$RUNNER" "$PLAIN_SRT" "$ZIP_FILE" "$1"
else
  "$RUNNER" "$PLAIN_SRT" "$ZIP_FILE"
fi