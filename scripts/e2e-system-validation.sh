#!/usr/bin/env bash

# E2E System Validation
# Comprehensive check that all debug infrastructure is in place and ready

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAYER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$PLAYER_DIR/.." && pwd)"
EXT_DIR="$WORKSPACE_DIR/vscode-extension"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local cmd="$2"
  
  if eval "$cmd" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $name"
    ((PASS++))
  else
    echo -e "${RED}✗${NC} $name"
    ((FAIL++))
  fi
}

check_file() {
  local file="$1"
  local desc="$2"
  
  if [[ -f "$file" ]]; then
    echo -e "${GREEN}✓${NC} $desc"
    ((PASS++))
  else
    echo -e "${RED}✗${NC} $desc: missing $file"
    ((FAIL++))
  fi
}

check_lines() {
  local file="$1"
  local desc="$2"
  local minlines="$3"
  
  if [[ -f "$file" ]]; then
    local lines=$(wc -l < "$file" | tr -d ' ')
    if [[ $lines -ge $minlines ]]; then
      echo -e "${GREEN}✓${NC} $desc ($lines lines)"
      ((PASS++))
    else
      echo -e "${YELLOW}⚠${NC} $desc ($lines lines, expected >=$minlines)"
      ((WARN++))
    fi
  else
    echo -e "${RED}✗${NC} $desc: missing $file"
    ((FAIL++))
  fi
}

echo -e "${BLUE}=== VisionUniversalPlayer E2E System Validation ===${NC}\n"

# 1. Core Debug Files
echo -e "${BLUE}Core Debug Infrastructure${NC}"
check_lines "$PLAYER_DIR/Debug/DebugEventBus.swift" "DebugEventBus" 100
check_lines "$PLAYER_DIR/Debug/DebugEvent.swift" "DebugEvent" 30
check_lines "$PLAYER_DIR/Debug/DebugCategory.swift" "DebugCategory" 50
check_lines "$PLAYER_DIR/Debug/DebugWebSocketServer.swift" "WebSocket relay" 100
echo ""

# 2. E2E Tooling Scripts
echo -e "${BLUE}E2E Automation Tools${NC}"
check_file "$PLAYER_DIR/scripts/e2e-preflight.sh" "Preflight orchestrator"
check_file "$PLAYER_DIR/scripts/start-e2e-device-audit.sh" "Device audit launcher"
check_file "$PLAYER_DIR/scripts/e2e-event-coverage.sh" "Event coverage scanner"
check_file "$PLAYER_DIR/scripts/e2e-report-summary.mjs" "Report summarizer"
check_file "$EXT_DIR/scripts/e2e-session-audit-local.mjs" "Local audit server"
check_file "$EXT_DIR/scripts/e2e-session-audit.mjs" "Relay audit client"
echo ""

# 3. Documentation
echo -e "${BLUE}Documentation${NC}"
check_file "$PLAYER_DIR/E2E_QUICK_START.md" "Quick start guide"
check_file "$PLAYER_DIR/E2E_DEBUG_VALIDATION_CHECKLIST.md" "Validation checklist"
check_file "$PLAYER_DIR/README.md" "README with debug section"
echo ""

# 4. Subsystem Integration
echo -e "${BLUE}Subsystem Integration${NC}"
swift_count=$(find "$PLAYER_DIR" -path "$PLAYER_DIR/vision-ui-metal" -prune -o -type f -name "*.swift" -exec grep -l "DebugCategory\." {} \; 2>/dev/null | wc -l)
if [[ $swift_count -ge 40 ]]; then
  echo -e "${GREEN}✓${NC} Instrumentation coverage ($swift_count files)"
  ((PASS++))
else
  echo -e "${YELLOW}⚠${NC} Instrumentation coverage ($swift_count files, expected >=40)"
  ((WARN++))
fi

if grep -q "Playback toggled\|Voice listening started\|FFmpeg demuxer" "$PLAYER_DIR"/**/*.swift 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Event instrumentation verified"
  ((PASS++))
else
  echo -e "${YELLOW}⚠${NC} Event instrumentation check"
  ((WARN++))
fi
echo ""

# 5. Build Validation
echo -e "${BLUE}Build System Checks${NC}"
check "Extension TypeScript compile" "cd '$EXT_DIR' && npm run compile > /dev/null 2>&1"
check "Extension ESLint" "cd '$EXT_DIR' && npm run lint > /dev/null 2>&1"
check "Swift vision-ui-metal build" "cd '$WORKSPACE_DIR/vision-ui-metal' && swift build 2>/dev/null | grep -q 'Build complete'"
echo ""

# 6. Runtime Validation
echo -e "${BLUE}Runtime Checks${NC}"
check "Audit launcher executable" "[[ -x '$PLAYER_DIR/scripts/start-e2e-device-audit.sh' ]]"
check "Event coverage scan works" "bash '$PLAYER_DIR/scripts/e2e-event-coverage.sh' 2>&1 | grep -q 'Coverage PASS'"
check "Preflight gates work" "bash '$PLAYER_DIR/scripts/e2e-preflight.sh' 2>&1 | grep -q 'Preflight PASS'"
echo ""

# 7. Report Generation
echo -e "${BLUE}Report Workflow${NC}"
check "Report summarizer works" "cd '$PLAYER_DIR' && node scripts/e2e-report-summary.mjs docs/e2e-session-audit-local-smoke.json 2>&1 | grep -q 'STATUS'"
check "Sample report file present" "[[ -f '$PLAYER_DIR/docs/e2e-session-audit-local-smoke.json' ]]"
echo ""

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Warnings: ${YELLOW}$WARN${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}✓ System validation PASSED${NC}"
  echo ""
  echo "Ready for device testing. Next steps:"
  echo "  1. Launch app on device/simulator in DEBUG mode"
  echo "  2. Run: bash ./scripts/start-e2e-device-audit.sh --mode local --duration-ms 300000"
  echo "  3. Interact with app for 5 minutes (follow E2E_DEBUG_VALIDATION_CHECKLIST.md)"
  echo "  4. Run: node ./scripts/e2e-report-summary.mjs ./docs/e2e-session-audit-local-*.json"
  echo "  5. Share the exit code and any missing phrases"
  exit 0
else
  echo -e "${RED}✗ System validation FAILED${NC}"
  echo "Fix the issues above before device testing"
  exit 1
fi
