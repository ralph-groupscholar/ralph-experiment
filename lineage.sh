#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

COMPACT=0

usage() {
  echo "Usage: ./lineage.sh <agent-id> [--compact]"
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

AGENT_ID="$1"
shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --compact)
      COMPACT=1
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

if [ ! -f "$RALPH_STATE" ]; then
  echo ""
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

if ! jq -e --arg id "$AGENT_ID" '.agents[$id] != null' "$RALPH_STATE" >/dev/null; then
  echo ""
  echo -e "  ${DIM}Agent not found: ${AGENT_ID}${RESET}"
  echo ""
  exit 1
fi

# ── Build lineage (root -> agent) ───────────────────────────────────
path=()
current="$AGENT_ID"
while [ -n "$current" ] && [ "$current" != "null" ]; do
  path+=("$current")
  parent=$(ralph_get "$current" parent)
  if [ -z "$parent" ] || [ "$parent" = "null" ]; then
    break
  fi
  current="$parent"
done

# Reverse path
reversed=()
for ((i=${#path[@]}-1; i>=0; i--)); do
  reversed+=("${path[$i]}")
done

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo ""
echo -e "  ${CYAN}${BOLD}ralph lineage${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

level=0
for id in "${reversed[@]}"; do
  status=$(ralph_get "$id" status)
  type=$(ralph_get "$id" type)
  task=$(ralph_get "$id" task)
  started=$(ralph_get "$id" started_at)
  ended=$(ralph_get "$id" ended_at)

  icon=$(status_icon "$status")
  label=$(type_label "$type")
  indent=""
  for ((j=0; j<level; j++)); do
    indent="${indent}    "
  done

  meta="${DIM}${label} · ${status}${RESET}"
  echo -e "  ${indent}${icon} ${id} ${meta}"

  if [ "$COMPACT" -eq 0 ]; then
    echo -e "  ${indent}    ${task}"
    if [ -n "$started" ] && [ "$started" != "null" ]; then
      end_display="$ended"
      if [ -z "$end_display" ] || [ "$end_display" = "null" ]; then
        end_display="$now"
      fi
      duration=$(human_duration "$started" "$end_display")
      time_line="${DIM}${started} -> ${end_display}${RESET}"
      if [ -n "$duration" ]; then
        time_line="${time_line} ${DIM}(${duration})${RESET}"
      fi
      echo -e "  ${indent}    ${time_line}"
    fi
  fi

  level=$((level + 1))
done

echo ""
