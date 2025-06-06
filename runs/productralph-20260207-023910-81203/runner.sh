#!/usr/bin/env bash
WORKSPACE="/Users/ralph/setup"
RALPH_DIR="/Users/ralph/setup"
AGENT_ID="productralph-20260207-023910-81203"
RUN_DIR="/Users/ralph/setup/runs/productralph-20260207-023910-81203"

cd "$WORKSPACE"

# Phase 1: Plan and spawn CodeRalphs
echo "[productralph] Phase 1: Planning and spawning..."
prompt_content="$(cat "$RUN_DIR/prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "$prompt_content"   >> "$RUN_DIR/output.log" 2>&1 || true

# Phase 2: Wait for all CodeRalphs to finish
echo "[productralph] Phase 2: Waiting for CodeRalphs..."
source "$RALPH_DIR/state/helpers.sh"
while true; do
  status=$(ralph_get_children_status "$AGENT_ID")
  if [ "$status" = "all_done" ] || [ "$status" = "no_children" ]; then
    echo "[productralph] All CodeRalphs done."
    break
  fi
  echo "[productralph] Children status: $status — checking again in 30s..."
  sleep 30
done

# Phase 3: Merge, commit, push, clean up
echo "[productralph] Phase 3: Finishing up..."
finish_content="$(cat "$RUN_DIR/finish-prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "$finish_content"   >> "$RUN_DIR/output.log" 2>&1 || true

source "$RALPH_DIR/state/helpers.sh"
ralph_update_status "$AGENT_ID" "done"
echo "[productralph] Done."
