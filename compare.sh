#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
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
  echo -e "  ${CYAN}${BOLD}ralph compare${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

print_header

if [ ! -d "$SNAPSHOT_ROOT" ]; then
  echo -e "  ${DIM}Finds no snapshot directory. Runs ./snapshot.sh first.${RESET}"
  echo ""
  exit 0
fi

snapshots=()
while IFS= read -r entry; do
  snapshots+=("$entry")
done < <(ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | sort)

if [ "${#snapshots[@]}" -lt 2 ]; then
  echo -e "  ${DIM}Finds fewer than two snapshots to compare.${RESET}"
  echo ""
  exit 0
fi

list_snapshots() {
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

case "${1:-}" in
  --list|-l)
    list_snapshots
    exit 0
    ;;
  --help|-h)
    echo -e "  ${BOLD}Usage${RESET}"
    echo -e "  ./compare.sh <snapshotA> <snapshotB>"
    echo -e "  ./compare.sh --list"
    echo ""
    exit 0
    ;;
esac

resolve_snapshot() {
  local input="$1"
  if [ -z "$input" ]; then
    echo ""
    return 0
  fi
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

last_index=$(( ${#snapshots[@]} - 1 ))
second_last_index=$(( last_index - 1 ))
latest_snapshot="${snapshots[$last_index]}"
second_latest_snapshot="${snapshots[$second_last_index]}"

snapshot_a_name="${1:-$second_latest_snapshot}"

if [ -n "$2" ]; then
  snapshot_b_name="$2"
else
  if [ "$snapshot_a_name" = "$latest_snapshot" ]; then
    snapshot_b_name="$second_latest_snapshot"
  else
    snapshot_b_name="$latest_snapshot"
  fi
fi

snapshot_a_path="$(resolve_snapshot "$snapshot_a_name")"
snapshot_b_path="$(resolve_snapshot "$snapshot_b_name")"

if [ -z "$snapshot_a_path" ] || [ -z "$snapshot_b_path" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds unknown snapshot name(s)."
  echo -e "  ${DIM}Uses: ./compare.sh <snapshotA> <snapshotB>${RESET}"
  echo ""
  exit 1
fi

if [ "$snapshot_a_path" = "$snapshot_b_path" ]; then
  echo -e "  ${YELLOW}${BOLD}!${RESET} Finds identical snapshot targets."
  echo ""
  exit 0
fi

state_a="$snapshot_a_path/tree.json"
state_b="$snapshot_b_path/tree.json"

if [ ! -f "$state_a" ] || [ ! -f "$state_b" ]; then
  echo -e "  ${RED}${BOLD}!${RESET} Finds missing tree.json in one or both snapshots."
  echo ""
  exit 1
fi

count_total_a=$(jq '.agents | length' "$state_a")
count_total_b=$(jq '.agents | length' "$state_b")
count_running_a=$(jq '[.agents[] | select(.status == "running")] | length' "$state_a")
count_running_b=$(jq '[.agents[] | select(.status == "running")] | length' "$state_b")
count_done_a=$(jq '[.agents[] | select(.status == "done")] | length' "$state_a")
count_done_b=$(jq '[.agents[] | select(.status == "done")] | length' "$state_b")
count_failed_a=$(jq '[.agents[] | select(.status == "failed")] | length' "$state_a")
count_failed_b=$(jq '[.agents[] | select(.status == "failed")] | length' "$state_b")

format_delta() {
  local delta="$1"
  if [ "$delta" -gt 0 ]; then
    echo "+${delta}"
  else
    echo "${delta}"
  fi
}

delta_total=$((count_total_b - count_total_a))
delta_running=$((count_running_b - count_running_a))
delta_done=$((count_done_b - count_done_a))
delta_failed=$((count_failed_b - count_failed_a))

report_line() {
  local label="$1" value_a="$2" value_b="$3" delta="$4"
  echo -e "  ${label}: ${value_a} → ${value_b} (${delta})"
}

echo -e "  ${BOLD}Compares${RESET} ${snapshot_a_name} → ${snapshot_b_name}"

echo ""
echo -e "  ${BOLD}Reports counts${RESET}"
report_line "Total" "$count_total_a" "$count_total_b" "$(format_delta "$delta_total")"
report_line "Running" "$count_running_a" "$count_running_b" "$(format_delta "$delta_running")"
report_line "Done" "$count_done_a" "$count_done_b" "$(format_delta "$delta_done")"
report_line "Failed" "$count_failed_a" "$count_failed_b" "$(format_delta "$delta_failed")"

echo ""
echo -e "  ${BOLD}Lists changes${RESET}"

new_agents=$(jq -n --argfile a "$state_a" --argfile b "$state_b" '
  [$b.agents | keys[]] as $bids |
  [$a.agents | keys[]] as $aids |
  ($bids - $aids)
')

removed_agents=$(jq -n --argfile a "$state_a" --argfile b "$state_b" '
  [$a.agents | keys[]] as $aids |
  [$b.agents | keys[]] as $bids |
  ($aids - $bids)
')

status_changes=$(jq -n --argfile a "$state_a" --argfile b "$state_b" '
  [$a.agents | keys[]] as $aids |
  [$b.agents | keys[]] as $bids |
  ($aids | map(select($bids | index(.)))) as $both |
  $both
  | map(select($a.agents[.].status != $b.agents[.].status))
')

if [ "$(jq 'length' <<< "$new_agents")" -gt 0 ]; then
  echo -e "  ${GREEN}${BOLD}+${RESET} Adds agents"
  while IFS= read -r line; do
    echo -e "    ${line}"
  done < <(jq -r --argfile b "$state_b" '($ARGS.positional | .[]) as $id | "- \($id) (\($b.agents[$id].type)) — \($b.agents[$id].status) — \($b.agents[$id].task)"' --args $(jq -r '.[]' <<< "$new_agents"))
else
  echo -e "  ${DIM}Finds no new agents.${RESET}"
fi

if [ "$(jq 'length' <<< "$removed_agents")" -gt 0 ]; then
  echo -e "  ${RED}${BOLD}-${RESET} Removes agents"
  while IFS= read -r line; do
    echo -e "    ${line}"
  done < <(jq -r --argfile a "$state_a" '($ARGS.positional | .[]) as $id | "- \($id) (\($a.agents[$id].type)) — \($a.agents[$id].status) — \($a.agents[$id].task)"' --args $(jq -r '.[]' <<< "$removed_agents"))
else
  echo -e "  ${DIM}Finds no removed agents.${RESET}"
fi

if [ "$(jq 'length' <<< "$status_changes")" -gt 0 ]; then
  echo -e "  ${YELLOW}${BOLD}~${RESET} Updates status"
  while IFS= read -r line; do
    echo -e "    ${line}"
  done < <(jq -r --argfile a "$state_a" --argfile b "$state_b" '($ARGS.positional | .[]) as $id | "- \($id) (\($b.agents[$id].type)) — \($a.agents[$id].status) → \($b.agents[$id].status)"' --args $(jq -r '.[]' <<< "$status_changes"))
else
  echo -e "  ${DIM}Finds no status changes.${RESET}"
fi

echo ""
