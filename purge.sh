#!/usr/bin/env bash
set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

usage() {
  echo "Usage: ./purge.sh [--execute] [--age-days N]"
  echo "  --execute    Remove archived agent run directories"
  echo "  --age-days   Minimum age in days since archived_at (default: 14)"
}

EXECUTE=0
AGE_DAYS=14

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

if ! [[ "$AGE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "age-days must be an integer"
  exit 1
fi

ARCHIVE_DIR="$RALPH_DIR/runs/archive"
if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "Archive directory missing: $ARCHIVE_DIR"
  exit 0
fi

now_epoch=$(date -u +%s)
cutoff=$((AGE_DAYS * 86400))

readarray -t candidates < <(jq -r '.agents
  | to_entries[]
  | select(.value.archived_at != null)
  | select(.value.purged_at == null)
  | select(.value.workspace != null and .value.workspace != "")
  | [.key, .value.archived_at, .value.workspace]
  | @tsv' "$RALPH_STATE")

if [ ${#candidates[@]} -eq 0 ]; then
  echo "No archived agents ready for purge."
  exit 0
fi

purged=0
skipped=0

for row in "${candidates[@]}"; do
  IFS=$'\t' read -r agent_id archived_at workspace <<< "$row"

  if [ -z "$archived_at" ] || [ "$archived_at" = "null" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: missing archived_at"
    continue
  fi

  archived_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$archived_at" +%s 2>/dev/null || true)
  if [ -z "$archived_epoch" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: invalid archived_at ($archived_at)"
    continue
  fi

  age=$((now_epoch - archived_epoch))
  if [ $age -lt $cutoff ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: age ${age}s < cutoff ${cutoff}s"
    continue
  fi

  if [ ! -d "$workspace" ]; then
    skipped=$((skipped + 1))
    echo "skip $agent_id: missing archive ($workspace)"
    continue
  fi

  if [ $EXECUTE -eq 1 ]; then
    rm -rf "$workspace"
    ralph_purge_agent "$agent_id" "$workspace"
    purged=$((purged + 1))
    echo "purged $agent_id -> $workspace"
  else
    echo "would purge $agent_id -> $workspace"
  fi
 done

if [ $EXECUTE -eq 0 ]; then
  echo "Dry run complete. Use --execute to remove directories."
fi

echo "purged: $purged, skipped: $skipped"
