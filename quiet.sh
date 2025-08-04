#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

IDLE_MINUTES=60
TYPE_FILTER=""
STATUS_FILTER="running"
LIMIT=0
DESC=0
JSON_OUTPUT=0
NOW_OVERRIDE=""

usage() {
  echo "Usage: ./quiet.sh [--idle minutes] [--status running,done,failed] [--type bigralph|productralph|coderalph] [--limit N] [--latest] [--now ISO8601] [--json]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --idle)
      IDLE_MINUTES="$2"
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
    --latest)
      DESC=1
      shift
      ;;
    --now)
      NOW_OVERRIDE="$2"
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
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
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

if [ ! -f "$RALPH_STATE" ]; then
  echo ""
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo ""
  echo -e "  ${DIM}Finds no agents to inspect.${RESET}"
  echo ""
  exit 0
fi

if ! [[ "$IDLE_MINUTES" =~ ^[0-9]+$ ]]; then
  echo ""
  echo -e "  ${YELLOW}Invalid --idle value. Uses whole minutes.${RESET}"
  echo ""
  exit 1
fi

status_json="$(csv_to_json_array "$STATUS_FILTER")"
type_json="$(csv_to_json_array "$TYPE_FILTER")"

now_ts="$NOW_OVERRIDE"
if [ -z "$now_ts" ]; then
  now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

now_epoch="$(to_epoch "$now_ts")"
if [ -z "$now_epoch" ]; then
  echo ""
  echo -e "  ${YELLOW}Invalid --now timestamp. Uses ISO8601 format.${RESET}"
  echo ""
  exit 1
fi

idle_seconds=$((IDLE_MINUTES * 60))

if [ -f "$RALPH_EVENTS" ]; then
  events_json="$(jq -s '.' "$RALPH_EVENTS")"
else
  events_json="[]"
fi

entries=$(jq -r \
  --argjson events "$events_json" \
  --argjson statuses "$status_json" \
  --argjson types "$type_json" \
  --argjson desc "$DESC" \
  '
    ($events
      | group_by(.agent)
      | map({(.[0].agent): (map(.ts) | max)})
      | add // {}) as $last
    | .agents
    | to_entries
    | map(select(
        ($statuses == null or ($statuses | index(.value.status) != null))
        and ($types == null or ($types | index(.value.type) != null))
      ))
    | sort_by(.value.started_at // "")
    | (if $desc == 1 then reverse else . end)
    | .[]
    | (.key) as $id
    | (.value) as $agent
    | ($last[$id] // "") as $last_ts
    | (if $last_ts != "" then "event" else (if ($agent.started_at // "") != "" then "start" else "none" end) end) as $source
    | ($last_ts != "" ? $last_ts : ($agent.started_at // "")) as $effective_ts
    | [$id, ($agent.type // ""), ($agent.status // ""), ($agent.task // ""), ($agent.pid // "" | tostring), $effective_ts, $source]
    | @tsv
  ' "$RALPH_STATE")

if [ "$JSON_OUTPUT" -eq 1 ]; then
  tmp_json="$(mktemp)"
else
  tmp_json=""
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph quiet${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
fi

matches=0
missing=0

while IFS=$'\t' read -r id type status task pid last_ts source; do
  if [ -z "$id" ]; then
    continue
  fi

  if [ -z "$last_ts" ]; then
    missing=$((missing + 1))
    continue
  fi

  last_epoch="$(to_epoch "$last_ts")"
  if [ -z "$last_epoch" ]; then
    missing=$((missing + 1))
    continue
  fi

  idle=$((now_epoch - last_epoch))
  if [ "$idle" -lt 0 ]; then
    idle=0
  fi

  if [ "$idle" -lt "$idle_seconds" ]; then
    continue
  fi

  matches=$((matches + 1))
  if [ "$LIMIT" -gt 0 ] && [ "$matches" -gt "$LIMIT" ]; then
    break
  fi

  idle_label="$(format_duration "$idle")"

  if [ "$JSON_OUTPUT" -eq 1 ]; then
    jq -cn \
      --arg id "$id" \
      --arg type "$type" \
      --arg status "$status" \
      --arg task "$task" \
      --arg pid "$pid" \
      --arg last_ts "$last_ts" \
      --arg source "$source" \
      --argjson idle "$idle" \
      '{id: $id, type: $type, status: $status, task: $task, pid: ($pid | tonumber? // null), last_ts: $last_ts, last_source: $source, idle_seconds: $idle}' >> "$tmp_json"
    continue
  fi

  line="  $(status_icon) $(type_label "$type")  ${task}"
  details="last ${last_ts} (${source}) | idle ${idle_label}"
  if [ -n "$pid" ] && [ "$pid" != "null" ]; then
    details="${details} | pid ${pid}"
  fi
  line="${line}  ${DIM}${details}${RESET}"
  echo -e "$line"
done <<< "$entries"

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ -s "$tmp_json" ]; then
    jq -s '.' "$tmp_json"
  else
    echo "[]"
  fi
  rm -f "$tmp_json"
  exit 0
fi

echo ""
if [ "$matches" -eq 0 ]; then
  if [ "$missing" -gt 0 ]; then
    echo -e "  ${DIM}Finds ${missing} agents without timestamps.${RESET}"
  else
    echo -e "  ${DIM}Finds no quiet agents over ${IDLE_MINUTES}m.${RESET}"
  fi
  echo ""
  exit 0
fi
