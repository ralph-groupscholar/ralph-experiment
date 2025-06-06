#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="$RALPH_DIR"
LOG_DIR="$RALPH_DIR/runs"

mkdir -p "$LOG_DIR"

echo "[bigralph] Starting. Workspace: $WORKSPACE"

i=0
while true; do
  ((i++))
  echo "[bigralph] Iteration $i — $(date)"

  cd "$WORKSPACE"
  codex exec --skip-git-repo-check --sandbox danger-full-access \
    "$(cat "$RALPH_DIR/agents/bigralph/system-prompt.md")" \
    2>&1 | awk '
      /^codex$/ {in=1; next}
      /^tokens used$/ {in=0; next}
      /^exec$/ {next}
      /^thinking$/ {next}
      /^user$/ {next}
      /^mcp startup:/ {next}
      {if (in) print}
    ' || echo "[bigralph] Iteration $i exited with error, continuing..."

  echo "[bigralph] Iteration $i complete. Sleeping 5s..."
  sleep 5
done
