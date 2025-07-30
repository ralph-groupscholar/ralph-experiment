#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

LIMIT=20
STATUS_FILTER=""
TYPE_FILTER=""
SORT_BY="count"
MIN_COUNT=1

usage() {
  echo "Usage: ./tags.sh [-n N] [--status done|failed|running|done,failed] [--type bigralph|productralph|coderalph] [--sort count|name] [--min-count N]"
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
    --sort)
      SORT_BY="$2"
      shift 2
      ;;
    --min-count)
      MIN_COUNT="$2"
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

case "$SORT_BY" in
  count|name)
    ;;
  *)
    echo "Unknown sort: $SORT_BY"
    usage
    exit 1
    ;;
esac

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

format_count() {
  local value="$1"
  if [ -z "$value" ]; then
    echo "0"
  else
    echo "$value"
  fi
}

echo ""
echo -e "  ${CYAN}${BOLD}ralph tags${RESET}"
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
  --arg sort "$SORT_BY" \
  --argjson limit "$LIMIT" \
  --argjson min_count "$MIN_COUNT" \
  '
    ($status | if length == 0 then [] else split(",") end) as $statuses
    | ($type | if length == 0 then [] else split(",") end) as $types
    | [
        .agents[]
        | select(($statuses | length) == 0 or ($statuses | index(.status)))
        | select(($types | length) == 0 or ($types | index(.type)))
        | {status: .status, tags: (.tags // [])}
        | .tags[]? as $tag
        | {tag: $tag, status: .status}
      ] as $entries
    | ($entries
        | group_by(.tag)
        | map({
            tag: .[0].tag,
            total: length,
            running: (map(select(.status == "running")) | length),
            done: (map(select(.status == "done")) | length),
            failed: (map(select(.status == "failed")) | length)
          })
        | map(select(.total >= $min_count))
        | (if $sort == "name" then sort_by(.tag) else (sort_by(.total) | reverse) end)
        | .[0:$limit]
      )
    | .[]
    | [.tag, (.total | tostring), (.running | tostring), (.done | tostring), (.failed | tostring)]
    | @tsv
  ' "$RALPH_STATE")

if [ -z "$items" ]; then
  echo -e "  ${DIM}Finds no tagged agents for the current filters.${RESET}"
  echo ""
  exit 0
fi

printf "  ${BOLD}%-22s${RESET} ${DIM}%7s  %7s  %7s  %7s${RESET}\n" "Tag" "Total" "Running" "Done" "Failed"

while IFS=$'\t' read -r tag total running done failed; do
  total=$(format_count "$total")
  running=$(format_count "$running")
  done=$(format_count "$done")
  failed=$(format_count "$failed")
  printf "  %-22s %7s  %7s  %7s  %7s\n" "$tag" "$total" "$running" "$done" "$failed"
done <<< "$items"

echo ""
