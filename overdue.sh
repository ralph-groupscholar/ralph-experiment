#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

OVER_MINUTES=30
TYPE_FILTER=""
LIMIT=0
DESC=0

usage() {
  echo "Usage: ./overdue.sh [--over minutes] [--type bigralph|productralph|coderalph] [--limit N] [--latest]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --over)
      OVER_MINUTES="$2"
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
    --latest)
      DESC=1
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
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

status_icon() {
  echo -e "${GREEN}●${RESET}"
}

type_label() {
  case "$1" in
    bigralph)     echo -e "${CYAN}${BOLD}BigRalph${RESET}" ;;
    productralph) echo -e "${YELLOW}ProductRalph${RESET}" ;;
    coderalph)    echo -e "${DIM}CodeRalph${RESET}" ;;
    *)            echo "$1" ;;
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

csv_to_json_array() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "null"
    return
  fi
  printf "%s" "$input" | tr ',' '\n' | jq -R -s 'split("\n")[:-1]'
}

echo ""
echo -e "  ${CYAN}${BOLD}ralph overdue${RESET}"
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

if ! [[ "$OVER_MINUTES" =~ ^[0-9]+$ ]]; then
  echo -e "  ${RED}Invalid --over value. Uses whole minutes.${RESET}"
  echo ""
  exit 1
fi

over_seconds=$((OVER_MINUTES * 60))
type_json="$(csv_to_json_array "$TYPE_FILTER")"
now_epoch=$(date -u +%s)

entries=$(jq -r \
  --argjson types "$type_json" \
  --argjson desc "$DESC" \
  '
  .agents
  | to_entries
  | map(select(.value.status == "running"))
  | map(select($types == null or ($types | index(.value.type) != null)))
  | sort_by(.value.started_at // "")
  | (if $desc == 1 then reverse else . end)
  | .[]
  | [.key, .value.type, .value.task, (.value.started_at // ""), (.value.pid | tostring)]
  | @tsv
' "$RALPH_STATE")

if [ -z "$entries" ]; then
  echo -e "  ${DIM}Finds no running agents to inspect.${RESET}"
  echo ""
  exit 0
fi

matches=0

while IFS=$'\t' read -r id type task started pid; do
  start_epoch="$(to_epoch "$started")"
  if [ -z "$start_epoch" ]; then
    continue
  fi

  duration=$((now_epoch - start_epoch))
  if [ "$duration" -lt 0 ]; then
    duration=0
  fi

  if [ "$duration" -lt "$over_seconds" ]; then
    continue
  fi

  matches=$((matches + 1))
  if [ "$LIMIT" -gt 0 ] && [ "$matches" -gt "$LIMIT" ]; then
    break
  fi

  duration_label="$(format_duration "$duration")"
  line="  $(status_icon) $(type_label "$type")  ${task}"
  details="start ${started} | dur ${duration_label} | pid ${pid}"
  line="${line}  ${DIM}${details}${RESET}"
  echo -e "$line"
done <<< "$entries"

if [ "$matches" -eq 0 ]; then
  echo -e "  ${DIM}Finds no running agents over ${OVER_MINUTES}m.${RESET}"
  echo ""
  exit 0
fi

echo ""
echo -e "  ${DIM}${matches} agent(s) over ${OVER_MINUTES}m${RESET}"
echo ""
