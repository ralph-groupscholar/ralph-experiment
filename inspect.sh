#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

TAIL_LINES=20
SHOW_TAIL=1
AGENT_ID=""

usage() {
  echo "Usage: ./inspect.sh <agent-id> [--tail N] [--no-tail]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tail)
      TAIL_LINES="$2"
      shift 2
      ;;
    --no-tail)
      SHOW_TAIL=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$AGENT_ID" ]; then
        AGENT_ID="$1"
        shift
      else
        echo "Unknown option: $1"
        usage
        exit 1
      fi
      ;;
  esac
done

if [ -z "$AGENT_ID" ]; then
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

human_bytes() {
  local bytes="$1"
  if [ -z "$bytes" ]; then
    echo ""
    return
  fi
  local units=(B KB MB GB TB)
  local value="$bytes"
  local idx=0
  while [ "$value" -ge 1024 ] && [ "$idx" -lt 4 ]; do
    value=$((value / 1024))
    idx=$((idx + 1))
  done
  echo "${value}${units[$idx]}"
}

find_log_path() {
  local id="$1" workspace="$2"
  if [ -n "$workspace" ] && [ "$workspace" != "null" ]; then
    if [ -f "$workspace/output.log" ]; then
      echo "$workspace/output.log"
      return
    fi
  fi

  if [ -f "$RALPH_DIR/runs/$id/output.log" ]; then
    echo "$RALPH_DIR/runs/$id/output.log"
    return
  fi

  if [ "$id" = "bigralph" ] && [ -f "$RALPH_DIR/runs/bigralph.log" ]; then
    echo "$RALPH_DIR/runs/bigralph.log"
    return
  fi

  if [ -f "$RALPH_DIR/runs/$id.log" ]; then
    echo "$RALPH_DIR/runs/$id.log"
    return
  fi
}

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  exit 0
fi

if ! jq -e --arg id "$AGENT_ID" '.agents[$id] != null' "$RALPH_STATE" >/dev/null; then
  echo -e "  ${RED}Unknown agent id:${RESET} $AGENT_ID"
  exit 1
fi

id="$AGENT_ID"
type=$(ralph_get "$id" type)
status=$(ralph_get "$id" status)
pid=$(ralph_get "$id" pid)
parent=$(ralph_get "$id" parent)
task=$(ralph_get "$id" task)
workspace=$(ralph_get "$id" workspace)
archived_at=$(ralph_get "$id" archived_at)
started=$(ralph_get "$id" started_at)
ended=$(ralph_get "$id" ended_at)

children=$(jq -r --arg id "$id" '.agents[$id].children | join(", ")' "$RALPH_STATE")
child_count=$(jq -r --arg id "$id" '.agents[$id].children | length' "$RALPH_STATE")

alive_note=""
if [ "$status" = "running" ]; then
  if kill -0 "$pid" 2>/dev/null; then
    alive_note="${DIM}pid ${pid}${RESET}"
  else
    alive_note="${RED}dead pid ${pid}${RESET}"
  fi
fi

if [ -z "$parent" ] || [ "$parent" = "null" ]; then
  parent="none"
fi

workspace_note=""
if [ -z "$workspace" ] || [ "$workspace" = "null" ]; then
  workspace="none"
else
  if [ -d "$workspace" ]; then
    workspace_note="${DIM}(exists)${RESET}"
  else
    workspace_note="${RED}(missing)${RESET}"
  fi
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
end_for_duration="$ended"
if [ -z "$end_for_duration" ] || [ "$end_for_duration" = "null" ]; then
  if [ "$status" = "running" ]; then
    end_for_duration="$now"
  fi
fi

duration="$(human_duration "$started" "$end_for_duration")"

log_path=$(find_log_path "$id" "$workspace")
log_size=""
if [ -n "$log_path" ]; then
  log_bytes=$(stat -f%z "$log_path" 2>/dev/null || echo "")
  log_size=$(human_bytes "$log_bytes")
fi

echo ""
echo -e "  ${CYAN}${BOLD}ralph inspect${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${BOLD}Agent:${RESET} ${id} (${type})"
echo -e "  ${BOLD}Status:${RESET} $(status_icon "$status") ${status} ${alive_note}"
echo -e "  ${BOLD}Task:${RESET} ${task}"
echo -e "  ${BOLD}Parent:${RESET} ${parent}"
echo -e "  ${BOLD}Children:${RESET} ${child_count} ${DIM}${children}${RESET}"
if [ -n "$started" ] && [ "$started" != "null" ]; then
  echo -e "  ${BOLD}Started:${RESET} ${started}"
fi
if [ -n "$ended" ] && [ "$ended" != "null" ]; then
  echo -e "  ${BOLD}Ended:${RESET} ${ended}"
fi
if [ -n "$duration" ]; then
  echo -e "  ${BOLD}Duration:${RESET} ${duration}"
fi
if [ -n "$archived_at" ] && [ "$archived_at" != "null" ]; then
  echo -e "  ${BOLD}Archived:${RESET} ${archived_at}"
fi

echo -e "  ${BOLD}Workspace:${RESET} ${workspace} ${workspace_note}"

if [ -n "$log_path" ]; then
  log_size_note=""
  if [ -n "$log_size" ]; then
    log_size_note="${DIM}(${log_size})${RESET}"
  fi
  echo -e "  ${BOLD}Log:${RESET} ${log_path} ${log_size_note}"
else
  echo -e "  ${BOLD}Log:${RESET} ${DIM}No log file found${RESET}"
fi

if [ "$SHOW_TAIL" -eq 1 ] && [ -n "$log_path" ]; then
  echo ""
  echo -e "  ${BOLD}Log tail:${RESET} ${DIM}${TAIL_LINES} lines${RESET}"
  tail -n "$TAIL_LINES" "$log_path" | sed 's/^/  /'
fi

echo ""
