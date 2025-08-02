#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

LIMIT=10
EVENT_FILTER=""
AGENT_FILTER=""
SINCE=""
HOURS=""
JSON_OUTPUT=0

usage() {
  echo "Usage: ./activity.sh [--since ISO8601] [--hours N] [--event status,register] [--agent ID] [-n N] [--json]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="$2"
      shift 2
      ;;
    --hours)
      HOURS="$2"
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
    -n|--number)
      LIMIT="$2"
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

if [ -n "$SINCE" ] && [ -n "$HOURS" ]; then
  echo "Choose either --since or --hours, not both."
  exit 1
fi

if [ -n "$HOURS" ] && ! [[ "$HOURS" =~ ^[0-9]+$ ]]; then
  echo "Invalid --hours value. Uses whole numbers."
  exit 1
fi

if [ -n "$HOURS" ]; then
  SINCE="$(date -u -v -"${HOURS}"H +%Y-%m-%dT%H:%M:%SZ)"
fi

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

if [ ! -f "$RALPH_EVENTS" ]; then
  echo ""
  echo -e "  ${DIM}Finds no event log yet. Runs ./start.sh or updates state first.${RESET}"
  echo ""
  exit 0
fi

summary=$(jq -s \
  --arg event "$EVENT_FILTER" \
  --arg agent "$AGENT_FILTER" \
  --arg since "$SINCE" \
  --argjson limit "$LIMIT" \
  '
    ($event | if length == 0 then [] else split(",") end) as $events
    | ($agent | if length == 0 then [] else split(",") end) as $agents
    | [
        .[]
        | select(($events | length) == 0 or ($events | index(.event)))
        | select(($agents | length) == 0 or ($agents | index(.agent)))
        | select($since == "" or .ts >= $since)
      ] as $filtered
    | {
        total: ($filtered | length),
        by_event: (
          $filtered
          | sort_by(.event)
          | group_by(.event)
          | map({event: .[0].event, count: length})
          | sort_by(.count)
          | reverse
        ),
        by_agent: (
          $filtered
          | sort_by(.agent)
          | group_by(.agent)
          | map({
              agent: .[0].agent,
              count: length,
              events: (
                sort_by(.event)
                | group_by(.event)
                | map({event: .[0].event, count: length})
                | sort_by(.count)
                | reverse
              )
            })
          | sort_by(.count)
          | reverse
        )
      }
  ' "$RALPH_EVENTS")

if [ "$JSON_OUTPUT" -eq 1 ]; then
  echo "$summary"
  exit 0
fi

count=$(echo "$summary" | jq -r '.total')

label="all time"
if [ -n "$SINCE" ]; then
  label="since ${SINCE}"
fi

echo ""
echo -e "  ${CYAN}${BOLD}ralph activity${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "  ${BOLD}Events:${RESET} ${count} (${label})"

event_rows=$(echo "$summary" | jq -r \
  '.by_event | .[] | [.event, (.count | tostring)] | @tsv')

if [ -z "$event_rows" ]; then
  echo -e "  ${DIM}Finds no matching events.${RESET}"
  echo ""
  exit 0
fi

echo ""
printf "  ${BOLD}%-16s${RESET} ${DIM}%7s${RESET}\n" "Event" "Count"
while IFS=$'\t' read -r event count; do
  printf "  %-16s %7s\n" "$event" "$count"
done <<< "$event_rows"

echo ""
agent_rows=$(echo "$summary" | jq -r \
  --argjson limit "$LIMIT" \
  '.by_agent
   | .[0:$limit]
   | .[]
   | [
       .agent,
       (.count | tostring),
       (.events | map("\(.event):\(.count)") | join(" "))
     ]
   | @tsv')

printf "  ${BOLD}%-18s${RESET} ${DIM}%7s  %s${RESET}\n" "Agent" "Count" "Breakdown"
while IFS=$'\t' read -r agent count breakdown; do
  printf "  %-18s %7s  ${DIM}%s${RESET}\n" "$agent" "$count" "$breakdown"
done <<< "$agent_rows"

echo ""
