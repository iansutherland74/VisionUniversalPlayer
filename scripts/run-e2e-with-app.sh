#!/usr/bin/env bash
set -e

# Run E2E audit with the app
# This script:
# 1. Starts the E2E WebSocket server
# 2. Launches/reinstalls the app on the simulator
# 3. Collects debug events for the specified duration
# 4. Outputs results to a JSON file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VSCODE_EXT_DIR="$PROJECT_ROOT/../vscode-extension"

# Arguments (passthrough to e2e script)
DURATION_MS=${1:-10000}
MIN_EVENTS=${2:-1}
STRICT_CHECKLIST=${3:-false}
OUT_FILE=${4:-"$PROJECT_ROOT/docs/e2e-audit.json"}

SIMULATOR_DEVICE_ID="3AAB7B37-C8DB-474B-AF04-C431ECB9BBBE"
BUNDLE_ID="com.company.visionuniversalplayer"
PORT=9002

echo "🚀 E2E Audit with App Launch Script"
echo "   Duration: ${DURATION_MS}ms"
echo "   Min Events: ${MIN_EVENTS}"
echo "   Output: ${OUT_FILE}"
echo ""

# Step 1: Find app bundle
echo "📦 Finding app bundle..."
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path "*/Build/Products/Debug-xrsimulator/VisionUniversalPlayer.app" \
  -print -quit)

if [[ -z "$APP_PATH" ]]; then
  echo "❌ App bundle not found. Build the project first with:"
  echo "   xcodebuild -project VisionUniversalPlayer.xcodeproj -scheme VisionUniversalPlayer -configuration Debug -destination 'id=$SIMULATOR_DEVICE_ID' CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO build"
  exit 1
fi
echo "✅ Found: $APP_PATH"
echo ""

# Step 2: Kill any existing app instance
echo "🛑 Stopping any existing app instance..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl terminate "$SIMULATOR_DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1
echo "✅ App stopped"
echo ""

# Step 3: Start E2E server in background
echo "🌐 Starting E2E WebSocket server on ws://localhost:$PORT..."

# Convert output file to absolute path
if [[ ! "$OUT_FILE" = /* ]]; then
  OUT_FILE="$(cd "$(dirname "$OUT_FILE")" 2>/dev/null && pwd)/$(basename "$OUT_FILE")" || OUT_FILE="$PWD/$OUT_FILE"
fi

cd "$VSCODE_EXT_DIR" || { echo "❌ Cannot find vscode-extension directory"; exit 1; }

# Run e2e script with specific arguments
node scripts/e2e-session-audit-local.mjs \
  --port "$PORT" \
  --duration-ms "$DURATION_MS" \
  --min-events "$MIN_EVENTS" \
  --strict-checklist "$STRICT_CHECKLIST" \
  --out "$OUT_FILE" &

E2E_PID=$!
echo "✅ E2E server started (PID: $E2E_PID)"
echo ""

# Wait for server to be ready
sleep 2

# Step 4: Reinstall and launch app
echo "📱 Installing app on simulator..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl install "$SIMULATOR_DEVICE_ID" "$APP_PATH" || {
  echo "⚠️  Install warning (continuing anyway)"
}

echo "🎬 Launching app..."
/Applications/Xcode.app/Contents/Developer/usr/bin/simctl launch "$SIMULATOR_DEVICE_ID" "$BUNDLE_ID" || {
  echo "⚠️  Launch warning (continuing anyway)"
}

echo "✅ App launched"
echo ""

# Step 5: Wait for E2E script to complete
echo "⏳ Collecting debug events (${DURATION_MS}ms)..."
wait $E2E_PID
E2E_EXIT=$?

echo ""
if [[ $E2E_EXIT -eq 0 ]]; then
  echo "✅ E2E audit completed"
  echo ""
  echo "📊 Results:"
  if [[ -f "$OUT_FILE" ]]; then
    head -30 "$OUT_FILE"
    echo "..."
    echo ""
    echo "📄 Full results saved to: $OUT_FILE"
  fi
else
  echo "❌ E2E audit failed with exit code $E2E_EXIT"
  exit $E2E_EXIT
fi
