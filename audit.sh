#!/usr/bin/env bash
set -e

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

REQUIRED_FIELDS=(id type status pid parent children task started_at workspace)

print_header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph audit${RESET}"
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

missing_fields=$(jq -r --argjson req "$(printf '%s\n' "${REQUIRED_FIELDS[@]}" | jq -R . | jq -s .)" '
  .agents
  | to_entries[]
  | {id: .key, missing: ($req - (.value | keys))}
  | select(.missing | length > 0)
  | "\(.id)\t\(.missing | join(\",\"))"
' "$RALPH_STATE")

invalid_status=$(jq -r '
  .agents
  | to_entries[]
  | select(.value.status | IN("running", "done", "failed") | not)
  | "\(.key)\t\(.value.status)"
' "$RALPH_STATE")

missing_parent=$(jq -r '
  .agents as $agents
  | $agents
  | to_entries[]
  | select(.value.parent != null and ($agents[.value.parent] == null))
  | "\(.key)\t\(.value.parent)"
' "$RALPH_STATE")

missing_children=$(jq -r '
  .agents as $agents
  | $agents
  | to_entries[]
  | .key as $id
  | .value.children[]?
  | select($agents[.] == null)
  | "\($id)\t\(.)"
' "$RALPH_STATE")

parent_mismatch=$(jq -r '
  .agents as $agents
  | $agents
  | to_entries[]
  | select(.value.parent != null)
  | select(($agents[.value.parent].children // []) | index(.key) | not)
  | "\(.key)\t\(.value.parent)"
' "$RALPH_STATE")

child_mismatch=$(jq -r '
  .agents as $agents
  | $agents
  | to_entries[]
  | .key as $parent
  | .value.children[]?
  | select($agents[.] != null)
  | select($agents[.].parent != $parent)
  | "\($parent)\t\(.)\t\($agents[.].parent)"
' "$RALPH_STATE")

pid_missing=$(jq -r '
  .agents
  | to_entries[]
  | select((.value.pid | type) != "number")
  | "\(.key)\t\(.value.pid)"
' "$RALPH_STATE")

issue_total=0

print_section() {
  local title="$1" data="$2" note="$3"
  if [ -n "$data" ]; then
    echo -e "  ${RED}${BOLD}✖${RESET} ${title}"
    while IFS=$'\t' read -r a b c; do
      [ -z "$a" ] && continue
      if [ -n "$c" ]; then
        echo -e "    ${YELLOW}${a}${RESET} -> ${b} (expected parent ${c})"
      elif [ -n "$b" ]; then
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

print_section "Missing required fields" "$missing_fields" "Required: ${REQUIRED_FIELDS[*]}"
print_section "Invalid status values" "$invalid_status" "Allowed: running, done, failed"
print_section "Missing parent references" "$missing_parent" "Parent is set but not found in agents"
print_section "Missing children references" "$missing_children" "Child listed but missing from agents"
print_section "Parent-child mismatch" "$parent_mismatch" "Agent parent does not list it as a child"
print_section "Child-parent mismatch" "$child_mismatch" "Child points to a different parent"
print_section "Non-numeric pid values" "$pid_missing" "PID should be numeric"

echo ""
if [ "$issue_total" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}Healthy:${RESET} Finds no integrity issues."
else
  echo -e "  ${RED}${BOLD}Issues:${RESET} Reports ${issue_total} issue(s)."
fi

echo ""
