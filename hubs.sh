#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
RESET='\033[0m'

LIMIT=10
TYPE_FILTER=""
STATUS_FILTER=""
AS_JSON=0

usage() {
  cat <<'USAGE'
Usage: ./hubs.sh [options]

Shows agents with the most children and child status breakdowns.

Options:
  --limit N        Number of agents to show (default: 10, 0 = all)
  --type TYPE      Filter by agent type (bigralph|productralph|coderalph)
  --status STATUS  Filter by agent status (running|done|failed)
  --json           Output as JSON
  -h, --help       Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --type)
      TYPE_FILTER="$2"
      shift 2
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --json)
      AS_JSON=1
      shift
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

if [ "$AS_JSON" = "0" ]; then
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph hubs${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
fi
if [ ! -f "$RALPH_STATE" ]; then
  if [ "$AS_JSON" = "1" ]; then
    echo "[]"
  else
    echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
    echo ""
  fi
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  if [ "$AS_JSON" = "1" ]; then
    echo "[]"
  else
    echo -e "  ${DIM}Finds no agents to inspect.${RESET}"
    echo ""
  fi
  exit 0
fi

hub_json=$(jq --arg type "$TYPE_FILTER" --arg status "$STATUS_FILTER" --argjson limit "$LIMIT" '
  def matches($agent):
    (if $type == "" then true else $agent.type == $type end)
    and (if $status == "" then true else $agent.status == $status end);
  .agents as $agents
  | $agents
  | to_entries
  | map(.value)
  | map(select(matches(.)))
  | map(. as $agent
      | ($agent.children // []) as $kids
      | {
          id: $agent.id,
          type: $agent.type,
          status: $agent.status,
          child_count: ($kids | length),
          running: ($kids | map($agents[.]?.status) | map(select(. == "running")) | length),
          done: ($kids | map($agents[.]?.status) | map(select(. == "done")) | length),
          failed: ($kids | map($agents[.]?.status) | map(select(. == "failed")) | length),
          task: ($agent.task // "")
        })
  | sort_by(.child_count) | reverse
  | if $limit > 0 then .[0:$limit] else . end
' "$RALPH_STATE")

if [ "$AS_JSON" = "1" ]; then
  echo "$hub_json" | jq '.'
  exit 0
fi

hub_count=$(echo "$hub_json" | jq 'length')
if [ "$hub_count" = "0" ]; then
  echo -e "  ${DIM}No agents match the filters.${RESET}"
  echo ""
  exit 0
fi

printf "  ${BOLD}%3s  %3s %3s %3s  %-24s  %-12s  %-8s  %s${RESET}\n" "Ch" "Run" "Done" "Fail" "Agent" "Type" "Status" "Task"

while IFS=$'\t' read -r child running done failed id type status task; do
  printf "  %3s  %3s %3s %3s  %-24s  %-12s  %-8s  %s\n" "$child" "$running" "$done" "$failed" "$id" "$type" "$status" "$task"
done < <(echo "$hub_json" | jq -r '.[] | [.child_count, .running, .done, .failed, .id, .type, .status, .task] | @tsv')

echo ""
