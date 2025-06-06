#!/usr/bin/env bash
set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$RALPH_DIR/.." && pwd)"

AGENT_ID=$(RALPH_SPAWN_DRY_RUN=1 \
  "$RALPH_DIR/agents/coderalph/spawn.sh" \
  "$REPO_ROOT" \
  "test/coderalph-spawn" \
  "Test CodeRalph spawn" \
  "productralph-test")

RUN_DIR="$RALPH_DIR/runs/$AGENT_ID"

if [ ! -f "$RUN_DIR/runner.sh" ]; then
  echo "Reports missing runner script: $RUN_DIR/runner.sh" >&2
  exit 1
fi

if [ ! -f "$RUN_DIR/prompt.md" ]; then
  echo "Reports missing prompt: $RUN_DIR/prompt.md" >&2
  exit 1
fi

echo "Confirms spawn test passes: $AGENT_ID"
