#!/usr/bin/env bash
set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

usage() {
  echo "Usage: ./archive.sh [--execute] [--age-hours N]"
  echo "  --execute     Move completed agent run directories into runs/archive"
  echo "  --age-hours   Minimum age in hours since ended_at (default: 2)"
}

EXECUTE=0
AGE_HOURS=2

while [ $# -gt 0 ]; do
  case "$1" in
    --execute)
      EXECUTE=1
      shift
      ;;
    --age-hours)
      AGE_HOURS="$2"
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

if ! [[ "$AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "age-hours must be an integer"
  exit 1
fi

ARCHIVE_DIR="$RALPH_DIR/runs/archive"
mkdir -p "$ARCHIVE_DIR"

now_epoch=$(date -u +%s)
cutoff=$((AGE_HOURS * 3600))

readarray -t candidates < <(jq -r '.agents
  | to_entries[]
  | select(.value.status == "done" or .value.status == "failed")
  | select(.value.workspace != null and .value.workspace != "")
  | select(.value.archived_at == null)
  | [.key, .value.ended_at, .value.workspace]
  | @tsv' "$RALPH_STATE")

if [ ${#candidates[@]} -eq 0 ]; then
  echo "No completed agents ready for archive."
  exit 0
fi

moved=0
skipped=0

for row in "${candidates[@]}"; do
  IFS=$'\t' read -r agent_id ended_at workspace <<< "$row"

  if [ -z "$ended_at" ] || [ "$ended_at" = "null" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: missing ended_at"
    continue
  fi

  ended_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ended_at" +%s 2>/dev/null || true)
  if [ -z "$ended_epoch" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: invalid ended_at ($ended_at)"
    continue
  fi

  age=$((now_epoch - ended_epoch))
  if [ $age -lt $cutoff ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: age ${age}s < cutoff ${cutoff}s"
    continue
  fi

  if [ ! -d "$workspace" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: missing workspace ($workspace)"
    continue
  fi

  dest="$ARCHIVE_DIR/$agent_id"
  if [ $EXECUTE -eq 1 ]; then
    if [ -e "$dest" ]; then
      skipped=$((skipped + 1))
      echo "skip $agent_id: archive already exists"
      continue
    fi
    mv "$workspace" "$dest"
    ralph_archive_agent "$agent_id" "$dest"
    moved=$((moved + 1))
    echo "archived $agent_id -> $dest"
  else
    echo "would archive $agent_id -> $dest"
  fi
 done

if [ $EXECUTE -eq 0 ]; then
  echo "Dry run complete. Use --execute to move directories."
fi

echo "archived: $moved, skipped: $skipped"
