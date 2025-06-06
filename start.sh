#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

echo ""
echo -e "  ${CYAN}${BOLD}ralph start${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── Check if BigRalph is already running ────────────────────────────
if jq -e '.agents.bigralph.status == "running"' "$RALPH_STATE" &>/dev/null; then
  existing_pid=$(jq -r '.agents.bigralph.pid' "$RALPH_STATE")
  if kill -0 "$existing_pid" 2>/dev/null; then
    echo -e "  ${RED}BigRalph is already running${RESET} (pid $existing_pid)"
    echo -e "  ${DIM}Run ./stop.sh first if you want to restart.${RESET}"
    echo ""
    exit 1
  fi
fi

# ── Seed org knowledge if first run ─────────────────────────────────
if [ ! -f "$RALPH_DIR/org/about.md" ]; then
  echo -e "  ${DIM}First run — seeding org knowledge...${RESET}"
  # org files will be created by the org-knowledge phase
fi

# ── Reset state ─────────────────────────────────────────────────────
echo '{"agents":{}}' | jq . > "$RALPH_STATE"

# ── Launch BigRalph ─────────────────────────────────────────────────
nohup bash "$RALPH_DIR/agents/bigralph/loop.sh" \
  > "$RALPH_DIR/runs/bigralph.log" 2>&1 &
BIGRALPH_PID=$!

ralph_register "bigralph" "bigralph" "null" "CEO — runs GroupScholar forever" "$RALPH_DIR"
ralph_update_pid "bigralph" "$BIGRALPH_PID"

echo -e "  ${GREEN}${BOLD}✔${RESET} BigRalph is alive  ${DIM}pid ${BIGRALPH_PID}${RESET}"
echo -e "  ${DIM}Log: runs/bigralph.log${RESET}"
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${DIM}Walk away. He's got it from here.${RESET}"
echo ""
