#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="$RALPH_DIR"
source "$RALPH_DIR/state/helpers.sh"

# ── Args ────────────────────────────────────────────────────────────
TASK="$1"
INSTRUCTIONS="$2"

if [ -z "$TASK" ]; then
  echo "Usage: spawn.sh \"<task>\" \"<instructions>\""
  exit 1
fi

# ── Generate ID ─────────────────────────────────────────────────────
AGENT_ID="productralph-$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR="$RALPH_DIR/runs/$AGENT_ID"
mkdir -p "$RUN_DIR"

# ── Fill prompt templates ───────────────────────────────────────────
sed \
  -e "s|{{AGENT_ID}}|$AGENT_ID|g" \
  -e "s|{{TASK}}|$TASK|g" \
  -e "s|{{INSTRUCTIONS}}|$INSTRUCTIONS|g" \
  "$RALPH_DIR/agents/productralph/system-prompt-template.md" \
  > "$RUN_DIR/prompt.md"

sed \
  -e "s|{{AGENT_ID}}|$AGENT_ID|g" \
  -e "s|{{TASK}}|$TASK|g" \
  -e "s|{{INSTRUCTIONS}}|$INSTRUCTIONS|g" \
  "$RALPH_DIR/agents/productralph/finish-prompt-template.md" \
  > "$RUN_DIR/finish-prompt.md"

# ── Register in state ──────────────────────────────────────────────
ralph_register "$AGENT_ID" "productralph" "bigralph" "$TASK" "$RUN_DIR"

# ── Launch (3 phases: plan+spawn, wait, finish) ────────────────────
cat > "$RUN_DIR/runner.sh" <<EOF
#!/usr/bin/env bash
WORKSPACE="$WORKSPACE"
RALPH_DIR="$RALPH_DIR"
AGENT_ID="$AGENT_ID"
RUN_DIR="$RUN_DIR"

cd "\$WORKSPACE"

# Phase 1: Plan and spawn CodeRalphs
echo "[productralph] Phase 1: Planning and spawning..."
prompt_content="\$(cat "\$RUN_DIR/prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "\$prompt_content" \
  >> "\$RUN_DIR/output.log" 2>&1 || true

# Phase 2: Wait for all CodeRalphs to finish
echo "[productralph] Phase 2: Waiting for CodeRalphs..."
source "\$RALPH_DIR/state/helpers.sh"
while true; do
  status=\$(ralph_get_children_status "\$AGENT_ID")
  if [ "\$status" = "all_done" ] || [ "\$status" = "no_children" ]; then
    echo "[productralph] All CodeRalphs done."
    break
  fi
  echo "[productralph] Children status: \$status — checking again in 30s..."
  sleep 30
done

# Phase 3: Merge, commit, push, clean up
echo "[productralph] Phase 3: Finishing up..."
finish_content="\$(cat "\$RUN_DIR/finish-prompt.md")"
codex exec --skip-git-repo-check --sandbox danger-full-access "\$finish_content" \
  >> "\$RUN_DIR/output.log" 2>&1 || true

source "\$RALPH_DIR/state/helpers.sh"
ralph_update_status "\$AGENT_ID" "done"
echo "[productralph] Done."
EOF

chmod +x "$RUN_DIR/runner.sh"
: > "$RUN_DIR/output.log"
: > "$RUN_DIR/runner.log"
nohup bash "$RUN_DIR/runner.sh" > "$RUN_DIR/runner.log" 2>&1 < /dev/null &

AGENT_PID=$!
ralph_update_pid "$AGENT_ID" "$AGENT_PID"

echo "$AGENT_ID"
