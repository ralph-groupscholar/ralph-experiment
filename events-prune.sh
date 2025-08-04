#!/usr/bin/env bash
set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

EVENTS_FILE="$RALPH_EVENTS"
EXECUTE=0
AGE_DAYS=30
CUTOFF=""

usage() {
  echo "Usage: ./events-prune.sh [--execute] [--age-days N] [--cutoff ISO8601] [--events FILE]"
  echo "  --execute   Write pruned events log"
  echo "  --age-days  Keep events newer than N days (default: 30)"
  echo "  --cutoff    Keep events on/after this ISO8601 timestamp"
  echo "  --events    Override events file path"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --execute)
      EXECUTE=1
      shift
      ;;
    --age-days)
      AGE_DAYS="$2"
      shift 2
      ;;
    --cutoff)
      CUTOFF="$2"
      shift 2
      ;;
    --events)
      EVENTS_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
 done

if [ -z "$CUTOFF" ]; then
  if ! [[ "$AGE_DAYS" =~ ^[0-9]+$ ]]; then
    echo "age-days must be an integer"
    exit 1
  fi
  CUTOFF=$(date -u -v "-${AGE_DAYS}d" +%Y-%m-%dT%H:%M:%SZ)
fi

if [ ! -f "$EVENTS_FILE" ]; then
  echo "Events file missing: $EVENTS_FILE"
  exit 0
fi

total=$(wc -l < "$EVENTS_FILE" | tr -d ' ')
if [ "$total" -eq 0 ]; then
  echo "No events to prune."
  exit 0
fi

tmp="${EVENTS_FILE}.tmp.$$"
jq -c --arg cutoff "$CUTOFF" 'select(.ts >= $cutoff)' "$EVENTS_FILE" > "$tmp"
kept=$(wc -l < "$tmp" | tr -d ' ')
removed=$((total - kept))

echo "events: $EVENTS_FILE"
echo "cutoff: $CUTOFF"
echo "Finds $kept of $total events to keep."

tmp_stats_cleanup() {
  rm -f "$tmp"
}

if [ "$EXECUTE" -eq 1 ]; then
  mv "$tmp" "$EVENTS_FILE"
  echo "Pruned $removed events."
else
  tmp_stats_cleanup
  echo "Would remove $removed events."
  echo "Dry run complete. Use --execute to write changes."
fi
