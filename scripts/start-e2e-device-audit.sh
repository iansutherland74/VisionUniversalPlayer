#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$PLAYER_DIR/.." && pwd)"
EXT_DIR="$WORKSPACE_DIR/vscode-extension"
OUT_DIR="$PLAYER_DIR/docs"

MODE="local"
DURATION_MS=300000
MIN_EVENTS=1
STRICT_CHECKLIST=true
REQUIRE_CONNECT=false
INJECT_SMOKE=false
OUT_FILE=""

usage() {
  cat <<'USAGE'
Usage: bash ./scripts/start-e2e-device-audit.sh [options]

Options:
  --mode <local|relay>         Audit mode. local starts a server on :9002. relay connects to existing relay. Default: local
  --duration-ms <n>            Capture duration in milliseconds. Default: 300000
  --min-events <n>             Minimum required events. Default: 1
  --strict-checklist <true|false>  Require all checklist phrases. Default: true
  --require-connect <true|false>   Relay mode only; fail if relay cannot connect. Default: false
  --inject-smoke               Local mode only; inject one synthetic event for smoke testing.
  --out <path>                 Output report path. Default: timestamped file in VisionUniversalPlayer/docs
  -h, --help                   Show help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --duration-ms)
      DURATION_MS="$2"
      shift 2
      ;;
    --min-events)
      MIN_EVENTS="$2"
      shift 2
      ;;
    --strict-checklist)
      STRICT_CHECKLIST="$2"
      shift 2
      ;;
    --require-connect)
      REQUIRE_CONNECT="$2"
      shift 2
      ;;
    --inject-smoke)
      INJECT_SMOKE=true
      shift
      ;;
    --out)
      OUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: Missing extension directory: $EXT_DIR"
  exit 1
fi

mkdir -p "$OUT_DIR"

if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date +%Y%m%d-%H%M%S)"
  OUT_FILE="$OUT_DIR/e2e-session-audit-${MODE}-${stamp}.json"
fi

if [[ "$MODE" == "local" ]]; then
  cmd=(
    node scripts/e2e-session-audit-local.mjs
    --duration-ms "$DURATION_MS"
    --min-events "$MIN_EVENTS"
    --out "$OUT_FILE"
  )

  if [[ "$STRICT_CHECKLIST" == "true" ]]; then
    cmd+=(--strict-checklist)
  fi
  if [[ "$INJECT_SMOKE" == "true" ]]; then
    cmd+=(--inject-smoke)
  fi
elif [[ "$MODE" == "relay" ]]; then
  cmd=(
    node scripts/e2e-session-audit.mjs
    --duration-ms "$DURATION_MS"
    --min-events "$MIN_EVENTS"
    --out "$OUT_FILE"
  )

  if [[ "$STRICT_CHECKLIST" == "true" ]]; then
    cmd+=(--strict-checklist)
  fi
  if [[ "$REQUIRE_CONNECT" == "true" ]]; then
    cmd+=(--require-connect)
  fi
else
  echo "ERROR: --mode must be local or relay"
  exit 1
fi

echo "Running E2E audit"
echo "  mode: $MODE"
echo "  durationMs: $DURATION_MS"
echo "  minEvents: $MIN_EVENTS"
echo "  strictChecklist: $STRICT_CHECKLIST"
echo "  output: $OUT_FILE"

(
  cd "$EXT_DIR"
  "${cmd[@]}"
)

echo "Done. Report: $OUT_FILE"
