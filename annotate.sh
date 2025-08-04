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
  echo -e "  ${DIM}Usage: ./annotate.sh <agent_id> [--note \"text\"] [--tag \"tag\"] [--remove-tag \"tag\"] [--clear-note] [--clear-tags]${RESET}"
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

exists=$(jq -r --arg id "$agent_id" '.agents[$id] != null' "$RALPH_STATE")
if [ "$exists" != "true" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds no agent with id ${BOLD}$agent_id${RESET}."
  exit 1
fi

note=""
clear_note="false"
clear_tags="false"
tags_to_add=()
tags_to_remove=()

while [ $# -gt 0 ]; do
  case "$1" in
    --note)
      shift
      note="${1:-}"
      ;;
    --tag)
      shift
      tags_to_add+=("${1:-}")
      ;;
    --remove-tag)
      shift
      tags_to_remove+=("${1:-}")
      ;;
    --clear-note)
      clear_note="true"
      ;;
    --clear-tags)
      clear_tags="true"
      ;;
    *)
      echo -e "  ${YELLOW}${BOLD}!${RESET} Finds unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift || true
done

if [ "$clear_note" = "false" ] && [ "$clear_tags" = "false" ] && [ -z "$note" ] && [ ${#tags_to_add[@]} -eq 0 ] && [ ${#tags_to_remove[@]} -eq 0 ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Needs at least one annotation action."
  usage
  exit 1
fi

if [ "$clear_note" = "true" ]; then
  ralph_clear_note "$agent_id"
fi

if [ -n "$note" ]; then
  ralph_set_note "$agent_id" "$note"
fi

if [ "$clear_tags" = "true" ]; then
  ralph_clear_tags "$agent_id"
fi

for tag in "${tags_to_add[@]}"; do
  if [ -n "$tag" ]; then
    ralph_add_tag "$agent_id" "$tag"
  fi
done

for tag in "${tags_to_remove[@]}"; do
  if [ -n "$tag" ]; then
    ralph_remove_tag "$agent_id" "$tag"
  fi
done

echo -e "  ${BOLD}Annotates${RESET} ${agent_id}"
