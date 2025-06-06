#!/usr/bin/env bash
WORK_DIR="/Users/ralph/setup/runs/coderalph-20260207-012748-91098/worktree"
RUN_DIR="/Users/ralph/setup/runs/coderalph-20260207-012748-91098"
RALPH_DIR="/Users/ralph/setup"
AGENT_ID="coderalph-20260207-012748-91098"

cd "$WORK_DIR"
prompt_content="$(cat "$RUN_DIR/prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "$prompt_content"   >> "$RUN_DIR/output.log" 2>&1 || true

source "$RALPH_DIR/state/helpers.sh"
ralph_update_status "$AGENT_ID" "done"
