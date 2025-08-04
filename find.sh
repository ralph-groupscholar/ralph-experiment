#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

QUERY=""
STATUS_FILTER="running,done,failed"
TYPE_FILTER=""
LIMIT=25
FIELD="task"

usage() {
  echo "Usage: ./find.sh --query <text> [--status running|done|failed|running,done] [--type bigralph|productralph|coderalph]"
  echo "               [--limit N] [--field task|id|workspace]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -q|--query)
      QUERY="$2"
      shift 2
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --type)
      TYPE_FILTER="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --field)
      FIELD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Finds unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Requires --query."
  usage
  exit 1
fi

if [ "$FIELD" != "task" ] && [ "$FIELD" != "id" ] && [ "$FIELD" != "workspace" ]; then
  echo "Finds unknown field: $FIELD"
  usage
  exit 1
fi

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

status_icon() {
  case "$1" in
    running) echo -e "${GREEN}●${RESET}" ;;
    done)    echo -e "${DIM}○${RESET}" ;;
    failed)  echo -e "${RED}✖${RESET}" ;;
    *)       echo -e "${YELLOW}?${RESET}" ;;
  esac
}

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
echo -e "  ${CYAN}${BOLD}ralph find${RESET}"
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

items=$(jq -r \
  --arg query "$QUERY" \
  --arg status "$STATUS_FILTER" \
  --arg type "$TYPE_FILTER" \
  --arg field "$FIELD" \
  --argjson limit "$LIMIT" \
  '
    ($query | ascii_downcase) as $q
    | ($status | split(",")) as $statuses
    | ($type | if length == 0 then [] else split(",") end) as $types
    | [.agents[]
        | select(.status as $s | $statuses | index($s))
        | select(($types | length) == 0 or ($types | index(.type)))
        | .field_value = (if $field == "id" then .id elif $field == "workspace" then (.workspace // "") else (.task // "") end)
        | select((.field_value | ascii_downcase) | contains($q))
        | .sort_key = (.started_at // .ended_at // "")
      ]
    | sort_by(.sort_key)
    | reverse
    | .[0:$limit]
    | .[]
    | [.id, .type, .status, (.started_at // ""), (.ended_at // ""), (.field_value // ""), (.task // ""), (.workspace // "")]
    | @tsv
  ' "$RALPH_STATE")

if [ -z "$items" ]; then
  echo -e "  ${DIM}Finds no agents for query '${QUERY}'.${RESET}"
  echo ""
  exit 0
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

while IFS=$'\t' read -r id type status started ended field_value task workspace; do
  icon=$(status_icon "$status")
  end_display="$ended"
  if [ -z "$end_display" ]; then
    end_display="$now"
  fi
  duration=$(human_duration "$started" "$end_display")
  meta="${DIM}${type} · ${status}${RESET}"
  time_bits="${DIM}${end_display}${RESET}"
  if [ -n "$duration" ]; then
    time_bits="${time_bits} ${DIM}(${duration})${RESET}"
  fi
  echo -e "  ${icon} ${id} ${meta}"
  if [ -n "$task" ]; then
    echo -e "      ${task}"
  fi
  if [ -n "$workspace" ]; then
    echo -e "      ${DIM}workspace:${RESET} ${workspace}"
  fi
  echo -e "      ${DIM}match:${RESET} ${FIELD} contains '${QUERY}'"
  if [ -n "$field_value" ] && [ "$field_value" != "$task" ] && [ "$field_value" != "$workspace" ]; then
    echo -e "      ${DIM}value:${RESET} ${field_value}"
  fi
  echo -e "      ${time_bits}"
  echo ""
done <<< "$items"
