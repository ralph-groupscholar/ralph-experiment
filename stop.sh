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
echo -e "  ${CYAN}${BOLD}ralph stop${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── Kill all agents ─────────────────────────────────────────────────
count=0
for pid in $(ralph_all_pids 2>/dev/null); do
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null && echo -e "  ${RED}✖${RESET}  Stopped pid ${BOLD}$pid${RESET}" || true
    count=$((count + 1))
  fi
done

# ── Also kill any child processes of those PIDs ─────────────────────
# Give processes a moment to clean up
sleep 1

# ── Reset state ─────────────────────────────────────────────────────
echo '{"agents":{}}' | jq . > "$RALPH_STATE"

echo ""
if [ $count -eq 0 ]; then
  echo -e "  ${DIM}No agents were running.${RESET}"
else
  echo -e "  ${GREEN}${BOLD}✔${RESET} Stopped ${BOLD}$count${RESET} agent(s). State reset."
fi
echo ""
