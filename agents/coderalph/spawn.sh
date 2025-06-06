#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="$RALPH_DIR"
source "$RALPH_DIR/state/helpers.sh"

# ── Args ────────────────────────────────────────────────────────────
REPO_PATH="$1"
BRANCH_NAME="$2"
SUBTASK="$3"
PARENT_ID="$4"

if [ -z "$SUBTASK" ] || [ -z "$PARENT_ID" ]; then
  echo "Usage: spawn.sh \"<repo-path>\" \"<branch-name>\" \"<subtask>\" \"<parent-id>\""
  exit 1
fi

# ── Generate ID ─────────────────────────────────────────────────────
AGENT_ID="coderalph-$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR="$RALPH_DIR/runs/$AGENT_ID"
mkdir -p "$RUN_DIR"

# ── Create git worktree ────────────────────────────────────────────
WORKTREE_PATH="$RUN_DIR/worktree"
if [ -n "$REPO_PATH" ] && [ -d "$REPO_PATH/.git" ]; then
  git -C "$REPO_PATH" worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>/dev/null || \
  git -C "$REPO_PATH" worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || \
  echo "Warning: Could not create worktree, CodeRalph will work in run dir"
fi

# Use worktree if created, otherwise use run dir
WORK_DIR="$WORKTREE_PATH"
[ -d "$WORK_DIR" ] || WORK_DIR="$RUN_DIR"

# ── Fill prompt template ────────────────────────────────────────────
sed \
  -e "s|{{AGENT_ID}}|$AGENT_ID|g" \
  -e "s|{{SUBTASK}}|$SUBTASK|g" \
  -e "s|{{WORKTREE_PATH}}|$WORK_DIR|g" \
  "$RALPH_DIR/agents/coderalph/system-prompt-template.md" \
  > "$RUN_DIR/prompt.md"

# ── Register in state ──────────────────────────────────────────────
ralph_register "$AGENT_ID" "coderalph" "$PARENT_ID" "$SUBTASK" "$RUN_DIR"

# ── Launch ──────────────────────────────────────────────────────────
cat > "$RUN_DIR/runner.sh" <<EOF
#!/usr/bin/env bash
WORK_DIR="$WORK_DIR"
RUN_DIR="$RUN_DIR"
RALPH_DIR="$RALPH_DIR"
AGENT_ID="$AGENT_ID"

cd "\$WORK_DIR"
prompt_content="\$(cat "\$RUN_DIR/prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "\$prompt_content" \
  >> "\$RUN_DIR/output.log" 2>&1 || true

source "\$RALPH_DIR/state/helpers.sh"
ralph_update_status "\$AGENT_ID" "done"
EOF

chmod +x "$RUN_DIR/runner.sh"
if [ "${RALPH_SPAWN_DRY_RUN:-}" = "1" ]; then
  ralph_update_pid "$AGENT_ID" "$$"
  ralph_update_status "$AGENT_ID" "done"
  echo "$AGENT_ID"
  exit 0
fi
: > "$RUN_DIR/output.log"
: > "$RUN_DIR/runner.log"
nohup bash "$RUN_DIR/runner.sh" > "$RUN_DIR/runner.log" 2>&1 < /dev/null &

AGENT_PID=$!
ralph_update_pid "$AGENT_ID" "$AGENT_PID"

echo "$AGENT_ID"
