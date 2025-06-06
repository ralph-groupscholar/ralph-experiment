#!/usr/bin/env bash
# State management helpers for the Ralph agent hierarchy.
# Source this file: source "$(dirname "$0")/../state/helpers.sh"

RALPH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RALPH_STATE="$RALPH_ROOT/state/tree.json"

# ── Internal: atomic JSON update (lock-free via temp + mv) ──────────
_ralph_update() {
  local tmp="$RALPH_STATE.tmp.$$"
  "$@" > "$tmp" && mv "$tmp" "$RALPH_STATE"
}

# ── Register a new agent ────────────────────────────────────────────
# Usage: ralph_register <id> <type> <parent|"null"> <task> [workspace]
ralph_register() {
  local id="$1" type="$2" parent="$3" task="$4" workspace="${5:-}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  _ralph_update jq \
    --arg id "$id" \
    --arg type "$type" \
    --arg parent "$parent" \
    --arg task "$task" \
    --arg ws "$workspace" \
    --arg now "$now" \
    --arg pid "$$" \
    '.agents[$id] = {
      id: $id,
      type: $type,
      status: "running",
      pid: ($pid | tonumber),
      parent: (if $parent == "null" then null else $parent end),
      children: [],
      task: $task,
      started_at: $now,
      workspace: $ws
    }' "$RALPH_STATE"

  # Add self as child of parent
  if [ "$parent" != "null" ]; then
    ralph_add_child "$parent" "$id"
  fi
}

# ── Update agent status ─────────────────────────────────────────────
# Usage: ralph_update_status <id> <status>
# Status: running | done | failed
ralph_update_status() {
  local id="$1" status="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg status "$status" \
    '.agents[$id].status = $status' "$RALPH_STATE"
}

# ── Update agent PID ────────────────────────────────────────────────
# Usage: ralph_update_pid <id> <pid>
ralph_update_pid() {
  local id="$1" pid="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg pid "$pid" \
    '.agents[$id].pid = ($pid | tonumber)' "$RALPH_STATE"
}

# ── Add child to parent ─────────────────────────────────────────────
# Usage: ralph_add_child <parent_id> <child_id>
ralph_add_child() {
  local parent_id="$1" child_id="$2"
  _ralph_update jq \
    --arg pid "$parent_id" \
    --arg cid "$child_id" \
    '.agents[$pid].children += [$cid] | .agents[$pid].children |= unique' "$RALPH_STATE"
}

# ── Check if all children of a parent are done ──────────────────────
# Usage: ralph_get_children_status <parent_id>
# Outputs: "all_done", "some_running", or "no_children"
ralph_get_children_status() {
  local parent_id="$1"
  jq -r --arg pid "$parent_id" '
    .agents[$pid].children as $kids |
    if ($kids | length) == 0 then "no_children"
    elif ([.agents[($kids[])].status] | all(. == "done")) then "all_done"
    else "some_running"
    end
  ' "$RALPH_STATE"
}

# ── List all agent IDs ──────────────────────────────────────────────
ralph_list_agents() {
  jq -r '.agents | keys[]' "$RALPH_STATE"
}

# ── Get agent info ──────────────────────────────────────────────────
# Usage: ralph_get <id> <field>
ralph_get() {
  local id="$1" field="$2"
  jq -r --arg id "$id" --arg f "$field" '.agents[$id][$f]' "$RALPH_STATE"
}

# ── Get all PIDs ────────────────────────────────────────────────────
ralph_all_pids() {
  jq -r '.agents[].pid' "$RALPH_STATE"
}
