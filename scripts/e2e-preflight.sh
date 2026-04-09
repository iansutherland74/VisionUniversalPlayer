#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$PLAYER_DIR/.." && pwd)"
EXT_DIR="$WORKSPACE_DIR/vscode-extension"
METAL_DIR="$WORKSPACE_DIR/vision-ui-metal"
METAL_UPSTREAM_DIR="$WORKSPACE_DIR/vision-ui-metal-upstream"

run_step() {
  local label="$1"
  shift
  echo ""
  echo "==> $label"
  "$@"
}

echo "VisionUniversalPlayer E2E preflight"
echo "Workspace: $WORKSPACE_DIR"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: Missing extension directory: $EXT_DIR"
  exit 1
fi

run_step "Extension pretest (compile + lint)" bash -lc "cd \"$EXT_DIR\" && npm run pretest"
run_step "Relay smoke gate" bash -lc "cd \"$EXT_DIR\" && node scripts/e2e-relay-smoke.mjs"
run_step "Required event phrase coverage" bash "$PLAYER_DIR/scripts/e2e-event-coverage.sh"
run_step "Subtitle sidecar regression" bash "$PLAYER_DIR/scripts/subtitle-sidecar-regression.sh"

if [[ -d "$METAL_DIR" ]]; then
  run_step "vision-ui-metal build" bash -lc "cd \"$METAL_DIR\" && swift build"
fi

if [[ -d "$METAL_UPSTREAM_DIR" ]]; then
  run_step "vision-ui-metal-upstream build" bash -lc "cd \"$METAL_UPSTREAM_DIR\" && swift build"
fi

echo ""
echo "Preflight PASS: automated E2E gates are green."
echo "Next: run the manual device interaction matrix in E2E_DEBUG_VALIDATION_CHECKLIST.md."
