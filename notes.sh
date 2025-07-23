#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

LIMIT=20
STATUS_FILTER=""
TYPE_FILTER=""
TAG_FILTER=""
QUERY=""
INCLUDE_EMPTY="false"

usage() {
  echo "Usage: ./notes.sh [-n N] [--status done|failed|running|done,failed] [--type bigralph|productralph|coderalph] [--tag tag] [--query text] [--all]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--number)
      LIMIT="$2"
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
    --tag)
      TAG_FILTER="$2"
      shift 2
      ;;
    --query)
      QUERY="$2"
      shift 2
      ;;
    --all)
      INCLUDE_EMPTY="true"
      shift 1
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

format_tags() {
  local tags="$1"
  if [ -z "$tags" ]; then
    echo ""
    return
  fi
  echo "${DIM}[${tags}]${RESET}"
}

echo ""
echo -e "  ${CYAN}${BOLD}ralph notes${RESET}"
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

items=$(jq -r \
  --arg status "$STATUS_FILTER" \
  --arg type "$TYPE_FILTER" \
  --arg tag "$TAG_FILTER" \
  --arg query "$QUERY" \
  --arg include_empty "$INCLUDE_EMPTY" \
  --argjson limit "$LIMIT" \
  '
    ($status | if length == 0 then [] else split(",") end) as $statuses
    | ($type | if length == 0 then [] else split(",") end) as $types
    | [
        .agents[]
        | select(($statuses | length) == 0 or ($statuses | index(.status)))
        | select(($types | length) == 0 or ($types | index(.type)))
        | select($tag == "" or ((.tags // []) | index($tag)))
        | select(
            $include_empty == "true"
            or ((.note // "") != "" or ((.tags // []) | length) > 0)
          )
        | select(
            $query == ""
            or ([.id, (.task // ""), (.note // ""), (.workspace // "")] | map(test($query; "i")) | any)
          )
        | .sort_key = (.ended_at // .started_at // "")
      ]
    | sort_by(.sort_key)
    | reverse
    | .[0:$limit]
    | .[]
    | [.id, .type, .status, (.tags // [] | join(", ")), (.note // ""), (.task // "")]
    | @tsv
  ' "$RALPH_STATE")

if [ -z "$items" ]; then
  echo -e "  ${DIM}Finds no matching agents with notes or tags.${RESET}"
  echo ""
  exit 0
fi

while IFS=$'\t' read -r id type status tags note task; do
  icon=$(status_icon "$status")
  tag_display=$(format_tags "$tags")
  meta="${DIM}${type} · ${status}${RESET}"
  echo -e "  ${icon} ${id} ${meta} ${tag_display}"
  if [ -n "$note" ]; then
    echo -e "      ${note}"
  fi
  if [ -n "$task" ]; then
    echo -e "      ${DIM}${task}${RESET}"
  fi
  echo ""
done <<< "$items"
