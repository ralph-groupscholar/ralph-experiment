#!/usr/bin/env bash
# State management helpers for the Ralph agent hierarchy.
# Source this file: source "$(dirname "$0")/../state/helpers.sh"

RALPH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RALPH_STATE="$RALPH_ROOT/state/tree.json"
RALPH_EVENTS="$RALPH_ROOT/state/events.jsonl"

# ── Event logging ──────────────────────────────────────────────────
# Usage: ralph_log_event <event> <agent_id> [detail_json]
ralph_log_event() {
  local event="$1" id="$2" detail_json="${3:-{}}"
  local now entry
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  entry="$(jq -cn \
    --arg ts "$now" \
    --arg event "$event" \
    --arg id "$id" \
    --argjson detail "$detail_json" \
    '{ts: $ts, event: $event, agent: $id, detail: $detail}')"
  mkdir -p "$(dirname "$RALPH_EVENTS")"
  printf "%s\n" "$entry" >> "$RALPH_EVENTS"
}

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
  ralph_log_event "register" "$id" "$(jq -cn \
    --arg type "$type" \
    --arg parent "$parent" \
    --arg task "$task" \
    --arg ws "$workspace" \
    --arg pid "$$" \
    '{type: $type, parent: (if $parent == "null" then null else $parent end), task: $task, workspace: $ws, pid: ($pid | tonumber)}')"
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
  ralph_log_event "status" "$id" "$(jq -cn --arg status "$status" '{status: $status}')"
}

# ── Update agent PID ────────────────────────────────────────────────
# Usage: ralph_update_pid <id> <pid>
ralph_update_pid() {
  local id="$1" pid="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg pid "$pid" \
    '.agents[$id].pid = ($pid | tonumber)' "$RALPH_STATE"
  ralph_log_event "pid" "$id" "$(jq -cn --arg pid "$pid" '{pid: ($pid | tonumber)}')"
}

# ── Add child to parent ─────────────────────────────────────────────
# Usage: ralph_add_child <parent_id> <child_id>
ralph_add_child() {
  local parent_id="$1" child_id="$2"
  _ralph_update jq \
    --arg pid "$parent_id" \
    --arg cid "$child_id" \
    '.agents[$pid].children += [$cid] | .agents[$pid].children |= unique' "$RALPH_STATE"
  ralph_log_event "child_add" "$parent_id" "$(jq -cn --arg child "$child_id" '{child: $child}')"
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
  ralph_log_event "remove" "$id"
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
  ralph_log_event "archive" "$id" "$(jq -cn --arg ws "$workspace" '{workspace: $ws}')"
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
  ralph_log_event "purge" "$id" "$(jq -cn --arg ws "$workspace" '{workspace: $ws}')"
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
  ralph_log_event "note_set" "$id" "$(jq -cn --arg note "$note" '{note: $note}')"
}

# Usage: ralph_clear_note <id>
ralph_clear_note() {
  local id="$1"
  _ralph_update jq \
    --arg id "$id" \
    '.agents[$id].note = null' \
    "$RALPH_STATE"
  ralph_log_event "note_clear" "$id"
}

# Usage: ralph_add_tag <id> <tag>
ralph_add_tag() {
  local id="$1" tag="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg tag "$tag" \
    '.agents[$id].tags = ((.agents[$id].tags // []) + [$tag] | unique)' \
    "$RALPH_STATE"
  ralph_log_event "tag_add" "$id" "$(jq -cn --arg tag "$tag" '{tag: $tag}')"
}

# Usage: ralph_remove_tag <id> <tag>
ralph_remove_tag() {
  local id="$1" tag="$2"
  _ralph_update jq \
    --arg id "$id" \
    --arg tag "$tag" \
    '.agents[$id].tags = ((.agents[$id].tags // []) | map(select(. != $tag)))' \
    "$RALPH_STATE"
  ralph_log_event "tag_remove" "$id" "$(jq -cn --arg tag "$tag" '{tag: $tag}')"
}

# Usage: ralph_clear_tags <id>
ralph_clear_tags() {
  local id="$1"
  _ralph_update jq \
    --arg id "$id" \
    '.agents[$id].tags = []' \
    "$RALPH_STATE"
  ralph_log_event "tags_clear" "$id"
}
