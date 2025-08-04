#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

usage() {
  echo -e "  ${DIM}Usage: ./reparent.sh <agent_id> <new_parent_id> | --root${RESET}"
  echo -e "  ${DIM}Examples: ./reparent.sh ProductRalph-001 BigRalph | ./reparent.sh ProductRalph-001 --root${RESET}"
}

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  exit 0
fi

agent_id="${1:-}"
if [ -z "$agent_id" ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Needs an agent id."
  usage
  exit 1
fi
shift || true

new_parent_raw="${1:-}"
if [ -z "$new_parent_raw" ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Needs a new parent id or --root."
  usage
  exit 1
fi

case "$new_parent_raw" in
  --root|-r)
    new_parent="null"
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    new_parent="$new_parent_raw"
    ;;
 esac

exists=$(jq -r --arg id "$agent_id" '.agents[$id] != null' "$RALPH_STATE")
if [ "$exists" != "true" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds no agent with id ${BOLD}$agent_id${RESET}."
  exit 1
fi

if [ "$new_parent" != "null" ]; then
  parent_exists=$(jq -r --arg id "$new_parent" '.agents[$id] != null' "$RALPH_STATE")
  if [ "$parent_exists" != "true" ]; then
    echo -e "  ${RED}${BOLD}!${RESET} Finds no parent with id ${BOLD}$new_parent${RESET}."
    exit 1
  fi
fi

if [ "$agent_id" = "$new_parent" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Cannot reparent an agent to itself."
  exit 1
fi

if [ "$new_parent" != "null" ]; then
  descendants=$(jq -r --arg id "$agent_id" '
    def descend($id):
      (.agents[$id].children // []) as $kids |
      ($kids[]? | . as $c | ($c, (descend($c))));
    [descend($id)] | unique | .[]
  ' "$RALPH_STATE" || true)

  if printf "%s\n" "$descendants" | grep -qx "$new_parent"; then
    echo -e "  ${RED}${BOLD}!${RESET} Cannot reparent into a descendant of ${BOLD}$agent_id${RESET}."
    exit 1
  fi
fi

ralph_reparent "$agent_id" "$new_parent"

if [ "$new_parent" = "null" ]; then
  echo -e "  ${BOLD}Reparents${RESET} ${agent_id} ${DIM}to${RESET} ${BOLD}root${RESET}"
else
  echo -e "  ${BOLD}Reparents${RESET} ${agent_id} ${DIM}to${RESET} ${BOLD}$new_parent${RESET}"
fi
