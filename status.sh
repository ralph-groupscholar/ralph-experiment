#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

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

# ── Print a node and its children recursively ───────────────────────
print_node() {
  local id="$1" indent="$2"
  local status type task pid alive

  status=$(ralph_get "$id" status)
  type=$(ralph_get "$id" type)
  task=$(ralph_get "$id" task)
  pid=$(ralph_get "$id" pid)

  # Check if process is actually alive
  alive=""
  if [ "$status" = "running" ]; then
    if kill -0 "$pid" 2>/dev/null; then
      alive="${DIM}pid $pid${RESET}"
    else
      alive="${RED}dead${RESET}"
    fi
  fi

  echo -e "${indent}$(status_icon "$status") $(type_label "$type")  ${task}  ${alive}"

  # Print children
  local children
  children=$(jq -r --arg id "$id" '.agents[$id].children[]?' "$RALPH_STATE")
  for child in $children; do
    print_node "$child" "${indent}    "
  done
}

# ── Main ────────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}${BOLD}ralph status${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

agent_count=$(jq '.agents | length' "$RALPH_STATE")

if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}No agents running. Start with ./start.sh${RESET}"
  echo ""
  exit 0
fi

# Find root agents (no parent)
roots=$(jq -r '[.agents[] | select(.parent == null)] | .[].id' "$RALPH_STATE")
for root in $roots; do
  print_node "$root" "  "
done

echo ""
echo -e "  ${DIM}$agent_count agent(s) total${RESET}"
echo ""
