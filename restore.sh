#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"
SNAPSHOT_ROOT="$RALPH_DIR/runs/snapshots"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

print_header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph restore${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

list_snapshots() {
  if [ ! -d "$SNAPSHOT_ROOT" ]; then
    echo -e "  ${DIM}Finds no snapshot directory. Runs ./snapshot.sh first.${RESET}"
    echo ""
    return 0
  fi

  snapshots=()
  while IFS= read -r entry; do
    snapshots+=("$entry")
  done < <(ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | sort)

  if [ "${#snapshots[@]}" -eq 0 ]; then
    echo -e "  ${DIM}Finds no snapshots.${RESET}"
    echo ""
    return 0
  fi

  echo -e "  ${BOLD}Lists snapshots${RESET}"
  for snap in "${snapshots[@]}"; do
    summary_path="$SNAPSHOT_ROOT/$snap/summary.md"
    if [ -f "$summary_path" ]; then
      summary_line=$(grep -m 1 "Reports agents:" "$summary_path" | sed 's/^- Reports agents: //')
      if [ -n "$summary_line" ]; then
        echo -e "  - ${snap} (${summary_line})"
      else
        echo -e "  - ${snap}"
      fi
    else
      echo -e "  - ${snap}"
    fi
  done
  echo ""
}

print_header

snapshot_name=""
backup_current=1

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo -e "  ${BOLD}Usage${RESET}"
      echo -e "  ./restore.sh <snapshot> [--no-backup]"
      echo -e "  ./restore.sh --list"
      echo ""
      exit 0
      ;;
    --list|-l)
      list_snapshots
      exit 0
      ;;
    --no-backup)
      backup_current=0
      ;;
    --backup)
      backup_current=1
      ;;
    *)
      if [ -z "$snapshot_name" ]; then
        snapshot_name="$arg"
      else
        echo -e "  ${RED}${BOLD}!${RESET} Receives multiple snapshot names."
        echo -e "  ${DIM}Uses: ./restore.sh <snapshot> [--no-backup]${RESET}"
        echo ""
        exit 1
      fi
      ;;
  esac
done

if [ -z "$snapshot_name" ]; then
  echo -e "  ${DIM}Needs a snapshot name to restore.${RESET}"
  echo -e "  ${DIM}Uses: ./restore.sh <snapshot> [--no-backup]${RESET}"
  echo ""
  list_snapshots
  exit 0
fi

if [ ! -d "$SNAPSHOT_ROOT" ]; then
  echo -e "  ${DIM}Finds no snapshot directory. Runs ./snapshot.sh first.${RESET}"
  echo ""
  exit 0
fi

resolve_snapshot() {
  local input="$1"
  if [ -d "$input" ]; then
    echo "$input"
    return 0
  fi
  if [ -d "$SNAPSHOT_ROOT/$input" ]; then
    echo "$SNAPSHOT_ROOT/$input"
    return 0
  fi
  echo ""
}

snapshot_path="$(resolve_snapshot "$snapshot_name")"

if [ -z "$snapshot_path" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds unknown snapshot name."
  echo -e "  ${DIM}Uses: ./restore.sh <snapshot> [--no-backup]${RESET}"
  echo ""
  exit 1
fi

snapshot_state="$snapshot_path/tree.json"

if [ ! -f "$snapshot_state" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds no tree.json in snapshot.${RESET}"
  echo ""
  exit 1
fi

if [ "$backup_current" -eq 1 ] && [ -f "$RALPH_STATE" ]; then
  backup_dir="$RALPH_DIR/state/backups"
  mkdir -p "$backup_dir"
  backup_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_path="$backup_dir/tree.$backup_stamp.json"
  cp "$RALPH_STATE" "$backup_path"
  echo -e "  ${GREEN}${BOLD}✔${RESET} Backs up current state to ${BOLD}state/backups/tree.${backup_stamp}.json${RESET}"
fi

cp "$snapshot_state" "$RALPH_STATE"

echo -e "  ${GREEN}${BOLD}✔${RESET} Restores state from ${BOLD}${snapshot_name}${RESET}"
echo ""
