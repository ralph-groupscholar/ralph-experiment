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

human_duration() {
  local start="$1" end="$2"
  python3 - <<PY
from datetime import datetime, timezone
start = "$start"
end = "$end"
fmt = "%Y-%m-%dT%H:%M:%SZ"
start_dt = datetime.strptime(start, fmt).replace(tzinfo=timezone.utc)
end_dt = datetime.strptime(end, fmt).replace(tzinfo=timezone.utc)
seconds = int((end_dt - start_dt).total_seconds())
if seconds < 0:
    seconds = 0
parts = []
days, rem = divmod(seconds, 86400)
hours, rem = divmod(rem, 3600)
minutes, secs = divmod(rem, 60)
if days:
    parts.append(f"{days}d")
if hours:
    parts.append(f"{hours}h")
if minutes:
    parts.append(f"{minutes}m")
if not parts:
    parts.append(f"{secs}s")
print(" ".join(parts))
PY
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
