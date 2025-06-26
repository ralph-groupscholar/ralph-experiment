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

to_epoch() {
  local ts="$1"
  if [ -z "$ts" ] || [ "$ts" = "null" ]; then
    echo ""
    return
  fi
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo ""
}

format_duration() {
  local total="$1"
  if [ -z "$total" ]; then
    echo ""
    return
  fi
  if [ "$total" -lt 0 ]; then
    total=0
  fi

  local days=$((total / 86400))
  local hours=$(((total % 86400) / 3600))
  local minutes=$(((total % 3600) / 60))
  local seconds=$((total % 60))

  local parts=""
  if [ "$days" -gt 0 ]; then
    parts="${days}d"
  fi
  if [ "$hours" -gt 0 ]; then
    parts="${parts}${parts:+ }${hours}h"
  fi
  if [ "$minutes" -gt 0 ]; then
    parts="${parts}${parts:+ }${minutes}m"
  fi
  if [ -z "$parts" ]; then
    parts="${seconds}s"
  fi

  echo "$parts"
}

human_duration() {
  local start="$1" end="$2"
  local start_epoch end_epoch
  start_epoch=$(to_epoch "$start")
  end_epoch=$(to_epoch "$end")
  if [ -z "$start_epoch" ] || [ -z "$end_epoch" ]; then
    echo ""
    return
  fi
  format_duration "$((end_epoch - start_epoch))"
}

echo ""
echo -e "  ${CYAN}${BOLD}ralph health${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to inspect.${RESET}"
  echo ""
  exit 0
fi

running_count=$(jq '[.agents[] | select(.status == "running")] | length' "$RALPH_STATE")
done_count=$(jq '[.agents[] | select(.status == "done")] | length' "$RALPH_STATE")
failed_count=$(jq '[.agents[] | select(.status == "failed")] | length' "$RALPH_STATE")

stale_count=0
stale_ids=()
oldest_id=""
oldest_start=""

for id in $(jq -r '.agents[] | select(.status == "running") | .id' "$RALPH_STATE"); do
  pid=$(ralph_get "$id" pid)
  start=$(ralph_get "$id" started_at)
  if [ -z "$oldest_start" ] || [[ "$start" < "$oldest_start" ]]; then
    oldest_start="$start"
    oldest_id="$id"
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    stale_count=$((stale_count + 1))
    stale_ids+=("$id")
  fi
done

echo -e "  ${BOLD}Agents:${RESET} ${agent_count} total"
echo -e "  ${BOLD}Running:${RESET} ${GREEN}${running_count}${RESET}  ${BOLD}Done:${RESET} ${DIM}${done_count}${RESET}  ${BOLD}Failed:${RESET} ${RED}${failed_count}${RESET}"

if [ "$running_count" -gt 0 ]; then
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  duration="$(human_duration "$oldest_start" "$now")"
  echo -e "  ${BOLD}Oldest running:${RESET} ${oldest_id} (${DIM}${duration}${RESET})"
fi

if [ "$stale_count" -gt 0 ]; then
  echo -e "  ${RED}${BOLD}Stale:${RESET} ${stale_count} running agent(s) with dead pid"
  for stale_id in "${stale_ids[@]}"; do
    echo -e "    ${RED}✖${RESET} ${stale_id}"
  done
else
  echo -e "  ${GREEN}${BOLD}Healthy:${RESET} Finds no stale running agents"
fi

echo ""
