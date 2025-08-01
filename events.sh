#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

LIMIT=50
EVENT_FILTER=""
AGENT_FILTER=""
SINCE=""
JSON_OUTPUT=0

usage() {
  echo "Usage: ./events.sh [-n N] [--event status,register] [--agent ID] [--since ISO8601] [--json]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--number)
      LIMIT="$2"
      shift 2
      ;;
    --event)
      EVENT_FILTER="$2"
      shift 2
      ;;
    --agent)
      AGENT_FILTER="$2"
      shift 2
      ;;
    --since)
      SINCE="$2"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=1
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

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

if [ ! -f "$RALPH_EVENTS" ]; then
  echo ""
  echo -e "  ${DIM}Finds no event log yet. Runs ./start.sh or updates state first.${RESET}"
  echo ""
  exit 0
fi

filtered=$(jq -s \
  --arg event "$EVENT_FILTER" \
  --arg agent "$AGENT_FILTER" \
  --arg since "$SINCE" \
  --argjson limit "$LIMIT" \
  '
    ($event | if length == 0 then [] else split(",") end) as $events
    | [
        .[]
        | select(($events | length) == 0 or ($events | index(.event)))
        | select($agent == "" or .agent == $agent)
        | select($since == "" or .ts >= $since)
      ]
    | sort_by(.ts)
    | reverse
    | .[0:$limit]
  ' "$RALPH_EVENTS")

if [ "$JSON_OUTPUT" -eq 1 ]; then
  echo "$filtered"
  exit 0
fi

echo ""
echo -e "  ${CYAN}${BOLD}ralph events${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

count=$(echo "$filtered" | jq 'length')
if [ "$count" -eq 0 ]; then
  echo -e "  ${DIM}Finds no matching events.${RESET}"
  echo ""
  exit 0
fi

echo "$filtered" | jq -r '.[] | [.ts, .event, .agent, (.detail // {} | @json)] | @tsv' | \
while IFS=$'\t' read -r ts event agent detail; do
  color="$YELLOW"
  case "$event" in
    register) color="$GREEN" ;;
    status) color="$CYAN" ;;
    purge|remove) color="$RED" ;;
  esac
  echo -e "  ${DIM}${ts}${RESET}  ${color}${event}${RESET}  ${agent}  ${DIM}${detail}${RESET}"
  echo ""
done
