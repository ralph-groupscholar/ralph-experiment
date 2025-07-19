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

print_header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph inspect${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

print_header

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_id="${1:-}"
if [ -z "$agent_id" ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Needs an agent id."
  echo -e "  ${DIM}Usage: ./inspect.sh <agent_id>${RESET}"
  echo ""
  exit 1
fi

exists=$(jq -r --arg id "$agent_id" '.agents[$id] != null' "$RALPH_STATE")
if [ "$exists" != "true" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds no agent with id ${BOLD}$agent_id${RESET}."
  echo ""
  exit 1
fi

agent_json=$(jq -r --arg id "$agent_id" '.agents[$id]' "$RALPH_STATE")
type=$(jq -r '.type' <<< "$agent_json")
status=$(jq -r '.status' <<< "$agent_json")
pid=$(jq -r '.pid' <<< "$agent_json")
parent=$(jq -r '.parent // "none"' <<< "$agent_json")
task=$(jq -r '.task' <<< "$agent_json")
started_at=$(jq -r '.started_at // "unknown"' <<< "$agent_json")
ended_at=$(jq -r '.ended_at // "active"' <<< "$agent_json")
workspace=$(jq -r '.workspace // ""' <<< "$agent_json")
archived_at=$(jq -r '.archived_at // ""' <<< "$agent_json")

children_total=$(jq -r '.children | length' <<< "$agent_json")
children_counts=$(jq -r '
  .children as $kids
  | {
      running: ([.agents[$kids[]] | select(.status == "running")] | length),
      done: ([.agents[$kids[]] | select(.status == "done")] | length),
      failed: ([.agents[$kids[]] | select(.status == "failed")] | length)
    }
' "$RALPH_STATE")

pid_state="unknown"
if [ "$pid" != "null" ] && [ -n "$pid" ]; then
  if kill -0 "$pid" 2>/dev/null; then
    pid_state="alive"
  else
    pid_state="stale"
  fi
fi

workspace_state="none"
if [ -n "$workspace" ]; then
  if [ -d "$workspace" ]; then
    workspace_state="present"
  else
    workspace_state="missing"
  fi
fi

archived_note="no"
if [ -n "$archived_at" ]; then
  archived_note="yes (${archived_at})"
fi

echo -e "  ${BOLD}Agent${RESET} ${agent_id}"
echo -e "  - Type: ${type}"
echo -e "  - Status: ${status}"
echo -e "  - PID: ${pid} (${pid_state})"
echo -e "  - Parent: ${parent}"
echo -e "  - Task: ${task}"
echo -e "  - Started: ${started_at}"
echo -e "  - Ended: ${ended_at}"
echo -e "  - Workspace: ${workspace_state}${workspace:+ (${workspace})}"
echo -e "  - Archived: ${archived_note}"
echo -e "  - Children: ${children_total} total (running $(jq -r '.running' <<< "$children_counts"), done $(jq -r '.done' <<< "$children_counts"), failed $(jq -r '.failed' <<< "$children_counts"))"
echo ""
