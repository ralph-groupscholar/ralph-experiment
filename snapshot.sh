#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SNAPSHOT_DIR="$RALPH_DIR/runs/snapshots/$TIMESTAMP"

mkdir -p "$SNAPSHOT_DIR"

print_header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph snapshot${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

print_header

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to snapshot.${RESET}"
  echo ""
  exit 0
fi

running_count=$(jq '[.agents[] | select(.status == "running")] | length' "$RALPH_STATE")
done_count=$(jq '[.agents[] | select(.status == "done")] | length' "$RALPH_STATE")
failed_count=$(jq '[.agents[] | select(.status == "failed")] | length' "$RALPH_STATE")

stale_ids=()
for id in $(jq -r '.agents[] | select(.status == "running") | .id' "$RALPH_STATE"); do
  pid=$(ralph_get "$id" pid)
  if ! kill -0 "$pid" 2>/dev/null; then
    stale_ids+=("$id")
  fi
done

cp "$RALPH_STATE" "$SNAPSHOT_DIR/tree.json"

summary_file="$SNAPSHOT_DIR/summary.md"
{
  echo "# Ralph Snapshot"
  echo ""
  echo "- Reports timestamp: ${TIMESTAMP}"
  echo "- Reports agents: ${agent_count} total, ${running_count} running, ${done_count} done, ${failed_count} failed"

  root_lines=$(jq -r '.agents[] | select(.parent == null) | "- \(.id) (\(.type)) — \(.status) — \(.task)"' "$RALPH_STATE")
  if [ -n "$root_lines" ]; then
    echo "- Lists root agents:"
    echo "$root_lines"
  else
    echo "- Finds no root agents"
  fi

  if [ "${#stale_ids[@]}" -gt 0 ]; then
    echo "- Lists stale running agents:"
    for stale_id in "${stale_ids[@]}"; do
      echo "- ${stale_id}"
    done
  else
    echo "- Finds no stale running agents"
  fi
} > "$summary_file"

echo -e "  ${GREEN}${BOLD}✔${RESET} Creates snapshot in ${BOLD}runs/snapshots/${TIMESTAMP}${RESET}"
if [ "${#stale_ids[@]}" -gt 0 ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Notes ${#stale_ids[@]} stale running agent(s)"
fi

echo ""
