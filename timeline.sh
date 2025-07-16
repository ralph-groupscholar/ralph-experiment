#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

STATUS_FILTER=""
TYPE_FILTER=""
LIMIT=0
DESC=0

usage() {
  echo "Usage: ./timeline.sh [--status running|done|failed] [--type bigralph|productralph|coderalph] [--limit N] [--latest]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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
  case "$1" in
    running) echo -e "${GREEN}●${RESET}" ;;
    done)    echo -e "${DIM}○${RESET}" ;;
    failed)  echo -e "${RED}✖${RESET}" ;;
    *)       echo -e "${YELLOW}?${RESET}" ;;
  esac
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
  local hours=$((total / 3600))
  local minutes=$(((total % 3600) / 60))
  local seconds=$((total % 60))

  if [ "$hours" -gt 0 ]; then
    echo "${hours}h ${minutes}m"
  elif [ "$minutes" -gt 0 ]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

csv_to_json_array() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "null"
    return
  fi
  printf "%s" "$input" | tr ',' '\n' | jq -R -s 'split("\n")[:-1]'
}

if [ ! -f "$RALPH_STATE" ]; then
  echo ""
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")

if [ "$agent_count" = "0" ]; then
  echo ""
  echo -e "  ${DIM}Finds no agents running. Starts with ./start.sh${RESET}"
  echo ""
  exit 0
fi

status_json="$(csv_to_json_array "$STATUS_FILTER")"
type_json="$(csv_to_json_array "$TYPE_FILTER")"

now_epoch=$(date -u +%s)

entries=$(jq -r \
  --argjson statuses "$status_json" \
  --argjson types "$type_json" \
  --argjson limit "$LIMIT" \
  --argjson desc "$DESC" \
  '
  .agents
  | to_entries
  | map(select(
      ($statuses == null or ($statuses | index(.value.status) != null))
      and ($types == null or ($types | index(.value.type) != null))
    ))
  | sort_by(.value.started_at // "")
  | (if $desc == 1 then reverse else . end)
  | (if $limit > 0 then .[:$limit] else . end)
  | .[]
  | [.key, .value.type, .value.status, .value.task, (.value.started_at // ""), (.value.ended_at // ""), (.value.pid | tostring)]
  | @tsv
' "$RALPH_STATE")

if [ -z "$entries" ]; then
  echo ""
  echo -e "  ${DIM}Finds no agents for the provided filters.${RESET}"
  echo ""
  exit 0
fi

echo ""
echo -e "  ${CYAN}${BOLD}ralph timeline${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

while IFS=$'\t' read -r id type status task started ended pid; do
  line="  $(status_icon "$status") $(type_label "$type")  ${task}"

  start_epoch="$(to_epoch "$started")"
  end_epoch=""
  if [ -n "$ended" ] && [ "$ended" != "null" ]; then
    end_epoch="$(to_epoch "$ended")"
  elif [ "$status" = "running" ]; then
    end_epoch="$now_epoch"
  fi

  duration=""
  if [ -n "$start_epoch" ] && [ -n "$end_epoch" ]; then
    duration="$(format_duration "$((end_epoch - start_epoch))")"
  fi

  details=""
  if [ -n "$started" ] && [ "$started" != "null" ]; then
    details="start ${started}"
  fi
  if [ -n "$ended" ] && [ "$ended" != "null" ]; then
    details="${details} | end ${ended}"
  elif [ "$status" = "running" ]; then
    details="${details} | end --"
  fi
  if [ -n "$duration" ]; then
    details="${details} | dur ${duration}"
  fi

  if [ -n "$details" ]; then
    line="${line}  ${DIM}${details}${RESET}"
  fi

  echo -e "$line"
done <<< "$entries"

echo ""
echo -e "  ${DIM}${agent_count} agent(s) total${RESET}"
echo ""
