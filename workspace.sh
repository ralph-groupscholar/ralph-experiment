#!/usr/bin/env bash
set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

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
  echo -e "  ${CYAN}${BOLD}ralph workspace audit${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

print_header

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to audit.${RESET}"
  echo ""
  exit 0
fi

missing_workspace=$(jq -r '
  .agents
  | to_entries[]
  | select(.value.workspace == null or .value.workspace == "")
  | .key
' "$RALPH_STATE")

missing_workspace_paths=()
while IFS=$'\t' read -r agent_id workspace; do
  [ -z "$agent_id" ] && continue
  if [ -z "$workspace" ] || [ "$workspace" = "null" ]; then
    continue
  fi
  if [ ! -d "$workspace" ]; then
    missing_workspace_paths+=("${agent_id}\t${workspace}")
  fi
done < <(jq -r '
  .agents
  | to_entries[]
  | select(.value.workspace != null and .value.workspace != "")
  | [.key, .value.workspace]
  | @tsv
' "$RALPH_STATE")

agent_ids=$(jq -r '.agents | keys[]' "$RALPH_STATE")
orphan_runs=()
run_root="$RALPH_DIR/runs"
if [ -d "$run_root" ]; then
  while IFS= read -r run_dir; do
    base=$(basename "$run_dir")
    if [ "$base" = "archive" ] || [ "$base" = "snapshots" ]; then
      continue
    fi
    if ! echo "$agent_ids" | grep -Fxq "$base"; then
      orphan_runs+=("${base}\t${run_dir}")
    fi
  done < <(find "$run_root" -maxdepth 1 -mindepth 1 -type d)
fi

issue_total=0

print_section() {
  local title="$1" data="$2" note="$3"
  if [ -n "$data" ]; then
    echo -e "  ${RED}${BOLD}✖${RESET} ${title}"
    while IFS=$'\t' read -r a b; do
      [ -z "$a" ] && continue
      if [ -n "$b" ]; then
        echo -e "    ${YELLOW}${a}${RESET} -> ${b}"
      else
        echo -e "    ${YELLOW}${a}${RESET}"
      fi
    done <<< "$data"
    if [ -n "$note" ]; then
      echo -e "    ${DIM}${note}${RESET}"
    fi
    issue_total=$((issue_total + $(echo "$data" | sed '/^$/d' | wc -l | tr -d ' ')))
  else
    echo -e "  ${GREEN}${BOLD}✔${RESET} ${title}"
  fi
}

missing_workspace_paths_output=""
if [ ${#missing_workspace_paths[@]} -gt 0 ]; then
  missing_workspace_paths_output=$(printf "%s\n" "${missing_workspace_paths[@]}")
fi

orphan_runs_output=""
if [ ${#orphan_runs[@]} -gt 0 ]; then
  orphan_runs_output=$(printf "%s\n" "${orphan_runs[@]}")
fi

print_section "Missing workspace entries" "$missing_workspace" "Workspace is unset or empty"
print_section "Missing workspace directories" "$missing_workspace_paths_output" "Workspace path is set but missing on disk"
print_section "Orphaned run directories" "$orphan_runs_output" "Run directory exists without a state entry"

echo ""
if [ "$issue_total" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}Healthy:${RESET} Finds no workspace drift."
else
  echo -e "  ${RED}${BOLD}Issues:${RESET} Reports ${issue_total} issue(s)."
fi

echo ""
