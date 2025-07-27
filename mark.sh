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
  echo -e "  ${DIM}Usage: ./mark.sh <agent_id> --status <running|done|failed>${RESET}"
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

status=""
while [ $# -gt 0 ]; do
  case "$1" in
    --status|-s)
      shift
      status="${1:-}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo -e "  ${YELLOW}${BOLD}!${RESET} Finds unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift || true
done

if [ -z "$status" ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Needs a status."
  usage
  exit 1
fi

case "$status" in
  running|done|failed)
    ;;
  *)
    echo -e "  ${RED}${BOLD}!${RESET} Receives invalid status: ${BOLD}$status${RESET}."
    usage
    exit 1
    ;;
esac

exists=$(jq -r --arg id "$agent_id" '.agents[$id] != null' "$RALPH_STATE")
if [ "$exists" != "true" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds no agent with id ${BOLD}$agent_id${RESET}."
  exit 1
fi

ralph_update_status "$agent_id" "$status"

echo -e "  ${BOLD}Marks${RESET} ${agent_id} ${DIM}as${RESET} ${BOLD}$status${RESET}"
