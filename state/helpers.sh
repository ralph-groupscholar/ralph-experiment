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
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _ralph_update jq \
    --arg id "$id" \
    --arg status "$status" \
    --arg now "$now" \
    '
      .agents[$id].status = $status
      | if ($status == "running") then
          .agents[$id].ended_at = null
        else
          .agents[$id].ended_at = (.agents[$id].ended_at // $now)
        end
      | if (.agents[$id].started_at == null or .agents[$id].started_at == "") then
          .agents[$id].started_at = $now
        else .
        end
    ' "$RALPH_STATE"
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

# ── Remove agent from state ─────────────────────────────────────────
# Usage: ralph_remove_agent <id>
ralph_remove_agent() {
  local id="$1"
  _ralph_update jq \
    --arg id "$id" \
    'del(.agents[$id]) |
     .agents |= with_entries(.value.children = (.value.children | map(select(. != $id))))' \
    "$RALPH_STATE"
}

# ── Mark agent archive metadata ────────────────────────────────────
# Usage: ralph_archive_agent <id> <workspace>
ralph_archive_agent() {
  local id="$1" workspace="$2"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _ralph_update jq \
    --arg id "$id" \
    --arg ws "$workspace" \
    --arg now "$now" \
    '.agents[$id].archived_at = $now | .agents[$id].workspace = $ws' \
    "$RALPH_STATE"
}

# ── Mark agent purge metadata ──────────────────────────────────────
# Usage: ralph_purge_agent <id> <workspace>
ralph_purge_agent() {
  local id="$1" workspace="$2"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _ralph_update jq \
    --arg id "$id" \
    --arg ws "$workspace" \
    --arg now "$now" \
    '.agents[$id].purged_at = $now
     | .agents[$id].purged_workspace = $ws
     | .agents[$id].workspace = null' \
    "$RALPH_STATE"
}

# ── Notes and tags ─────────────────────────────────────────────────
# Usage: ralph_set_note <id> <note>
ralph_set_note() {
  local id="$1" note="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg note "$note" \
    '.agents[$id].note = $note' \
    "$RALPH_STATE"
}

# Usage: ralph_clear_note <id>
ralph_clear_note() {
  local id="$1"
  _ralph_update jq \
    --arg id "$id" \
    '.agents[$id].note = null' \
    "$RALPH_STATE"
}

# Usage: ralph_add_tag <id> <tag>
ralph_add_tag() {
  local id="$1" tag="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg tag "$tag" \
    '.agents[$id].tags = ((.agents[$id].tags // []) + [$tag] | unique)' \
    "$RALPH_STATE"
}

# Usage: ralph_remove_tag <id> <tag>
ralph_remove_tag() {
  local id="$1" tag="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg tag "$tag" \
    '.agents[$id].tags = ((.agents[$id].tags // []) | map(select(. != $tag)))' \
    "$RALPH_STATE"
}

# Usage: ralph_clear_tags <id>
ralph_clear_tags() {
  local id="$1"
  _ralph_update jq \
    --arg id "$id" \
    '.agents[$id].tags = []' \
    "$RALPH_STATE"
}
