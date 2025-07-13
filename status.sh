#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

VERBOSE=0
JSON=0
STATUS_FILTER=""
TYPE_FILTER=""

usage() {
  echo "Usage: ./status.sh [-v|--verbose] [-j|--json] [--status running|done|failed] [--type bigralph|productralph|coderalph]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -j|--json)
      JSON=1
      shift
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --type)
      TYPE_FILTER="$2"
      shift 2
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

csv_contains() {
  local list="$1" value="$2"
  IFS=',' read -r -a items <<< "$list"
  for item in "${items[@]}"; do
    if [ "$item" = "$value" ]; then
      return 0
    fi
  done
  return 1
}

node_matches() {
  local status="$1" type="$2"
  if [ -n "$STATUS_FILTER" ]; then
    if ! csv_contains "$STATUS_FILTER" "$status"; then
      return 1
    fi
  fi
  if [ -n "$TYPE_FILTER" ]; then
    if ! csv_contains "$TYPE_FILTER" "$type"; then
      return 1
    fi
  fi
  return 0
}

node_has_match() {
  local id="$1"
  local status type
  status=$(ralph_get "$id" status)
  type=$(ralph_get "$id" type)

  if node_matches "$status" "$type"; then
    return 0
  fi

  local children
  children=$(jq -r --arg id "$id" '.agents[$id].children[]?' "$RALPH_STATE")
  for child in $children; do
    if node_has_match "$child"; then
      return 0
    fi
  done

  return 1
}

# ── Print a node and its children recursively ───────────────────────
print_node() {
  local id="$1" indent="$2"
  local status type task pid alive started ended line details duration

  if ! node_has_match "$id"; then
    return
  fi

  status=$(ralph_get "$id" status)
  type=$(ralph_get "$id" type)
  task=$(ralph_get "$id" task)
  pid=$(ralph_get "$id" pid)
  started=$(ralph_get "$id" started_at)
  ended=$(ralph_get "$id" ended_at)

  # Check if process is actually alive
  alive=""
  if [ "$status" = "running" ]; then
    if kill -0 "$pid" 2>/dev/null; then
      alive="${DIM}pid $pid${RESET}"
    else
      alive="${RED}dead${RESET}"
    fi
  fi

  line="${indent}$(status_icon "$status") $(type_label "$type")  ${task}"
  if [ -n "$alive" ]; then
    line="$line  ${alive}"
  fi

  if [ "$VERBOSE" -eq 1 ]; then
    local start_epoch end_epoch now_epoch
    details=""
    if [ -n "$started" ] && [ "$started" != "null" ]; then
      details="start ${started}"
      start_epoch=$(to_epoch "$started")
    fi

    if [ -n "$ended" ] && [ "$ended" != "null" ]; then
      details="${details} | end ${ended}"
      end_epoch=$(to_epoch "$ended")
    elif [ "$status" = "running" ]; then
      now_epoch=$(date -u +%s)
      end_epoch="$now_epoch"
    fi

    if [ -n "$start_epoch" ] && [ -n "$end_epoch" ]; then
      duration=$(format_duration "$((end_epoch - start_epoch))")
      if [ -n "$duration" ]; then
        details="${details} | dur ${duration}"
      fi
    fi

    if [ -n "$details" ]; then
      line="$line  ${DIM}${details}${RESET}"
    fi
  fi

  echo -e "$line"

  # Print children
  local children
  children=$(jq -r --arg id "$id" '.agents[$id].children[]?' "$RALPH_STATE")
  for child in $children; do
    print_node "$child" "${indent}    "
  done
}

emit_json() {
  local now now_epoch
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  now_epoch="$(date -u +%s)"

  if [ ! -f "$RALPH_STATE" ]; then
    echo '{"error":"Finds no state file. Runs ./start.sh first."}'
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  while IFS=$'\t' read -r id status pid started ended; do
    local alive start_epoch end_epoch duration_value
    alive=false
    if [ "$status" = "running" ] && kill -0 "$pid" 2>/dev/null; then
      alive=true
    fi

    duration_value=""
    if [ -n "$started" ] && [ "$started" != "null" ]; then
      start_epoch=$(to_epoch "$started")
      if [ -n "$ended" ] && [ "$ended" != "null" ]; then
        end_epoch=$(to_epoch "$ended")
      else
        end_epoch="$now_epoch"
      fi

      if [ -n "$start_epoch" ] && [ -n "$end_epoch" ]; then
        duration_value=$((end_epoch - start_epoch))
        if [ "$duration_value" -lt 0 ]; then
          duration_value=0
        fi
      fi
    fi

    printf "%s\t%s\t%s\n" "$id" "$alive" "$duration_value" >> "$tmp"
  done < <(jq -r '.agents | to_entries[] | [.key, .value.status, (.value.pid | tostring), (.value.started_at // ""), (.value.ended_at // "")] | @tsv' "$RALPH_STATE")

  local maps
  maps="$(jq -R -s '
    split("\n")[:-1]
    | map(split("\t"))
    | {
        alive_map: (map({key: .[0], value: (.[1] == "true")}) | from_entries),
        duration_map: (map({key: .[0], value: (.[2] | if . == "" then null else (tonumber) end)}) | from_entries)
      }
  ' "$tmp")"

  jq \
    --arg now "$now" \
    --argjson maps "$maps" \
    '{
      generated_at: $now,
      agent_count: (.agents | length),
      roots: [.agents[] | select(.parent == null and .id != null) | .id],
      agents: (.agents | with_entries(
        .value.alive = ($maps.alive_map[.key] // false)
        | .value.duration_seconds = ($maps.duration_map[.key] // null)
      ))
    }' "$RALPH_STATE"
}

# ── Main ────────────────────────────────────────────────────────────
if [ "$JSON" -eq 1 ]; then
  emit_json
  exit 0
fi

echo ""
echo -e "  ${CYAN}${BOLD}ralph status${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")

if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents running. Starts with ./start.sh${RESET}"
  echo ""
  exit 0
fi

# Find root agents (no parent)
roots=$(jq -r '[.agents[] | select(.parent == null and .id != null)] | .[].id' "$RALPH_STATE")
for root in $roots; do
  print_node "$root" "  "
done

echo ""
echo -e "  ${DIM}$agent_count agent(s) total${RESET}"
echo ""
