#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

DRY_RUN=0

case "${1:-}" in
  --dry-run) DRY_RUN=1 ;;
  -h|--help)
    echo "Usage: ./prune.sh [--dry-run]"
    exit 0
    ;;
  "") ;;
  *)
    echo "Usage: ./prune.sh [--dry-run]"
    exit 1
    ;;
esac

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

echo ""
echo -e "  ${CYAN}${BOLD}ralph prune${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to prune.${RESET}"
  echo ""
  exit 0
fi

pruned=0
skipped=0
candidates=$(jq -r '.agents | to_entries[] | select(.value.status != "running") | .key' "$RALPH_STATE")

if [ -z "$candidates" ]; then
  echo -e "  ${GREEN}${BOLD}✔${RESET} Finds no completed agents to prune."
  echo ""
  exit 0
fi

for id in $candidates; do
  running_child=$(jq -r --arg id "$id" '
    [.agents[$id].children[]? as $child | .agents[$child].status == "running"] | any
  ' "$RALPH_STATE")

  if [ "$running_child" = "true" ]; then
    skipped=$((skipped + 1))
    echo -e "  ${YELLOW}↷${RESET} Skips ${BOLD}$id${RESET} (running child present)"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    pruned=$((pruned + 1))
    echo -e "  ${DIM}•${RESET} Would prune ${BOLD}$id${RESET}"
  else
    ralph_remove_agent "$id"
    pruned=$((pruned + 1))
    echo -e "  ${GREEN}✔${RESET} Prunes ${BOLD}$id${RESET}"
  fi
done

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "  ${GREEN}${BOLD}✔${RESET} Would prune ${BOLD}$pruned${RESET} agent(s) (${skipped} skipped)."
else
  echo -e "  ${GREEN}${BOLD}✔${RESET} Prunes ${BOLD}$pruned${RESET} agent(s) (${skipped} skipped)."
fi
echo ""
