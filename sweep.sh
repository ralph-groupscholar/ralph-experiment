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
echo -e "  ${CYAN}${BOLD}ralph sweep${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to sweep.${RESET}"
  echo ""
  exit 0
fi

marked=0
for id in $(ralph_list_agents 2>/dev/null); do
  status=$(ralph_get "$id" status)
  pid=$(ralph_get "$id" pid)

  if [ "$status" = "running" ]; then
    if ! kill -0 "$pid" 2>/dev/null; then
      ralph_update_status "$id" "failed"
      now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      _ralph_update jq \
        --arg id "$id" \
        --arg now "$now" \
        '.agents[$id].ended_at = $now' "$RALPH_STATE"
      marked=$((marked + 1))
      echo -e "  ${RED}✖${RESET} Marks ${BOLD}$id${RESET} as failed (${DIM}pid $pid${RESET})"
    fi
  fi
done

echo ""
if [ "$marked" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✔${RESET} Finds no stale agents."
else
  echo -e "  ${GREEN}${BOLD}✔${RESET} Marks ${BOLD}$marked${RESET} agent(s) as failed."
fi
echo ""
