#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/state"
cp "$ROOT/quiet.sh" "$TMP_DIR/quiet.sh"
cp "$ROOT/state/helpers.sh" "$TMP_DIR/state/helpers.sh"
cp "$ROOT/tests/fixtures/tree.json" "$TMP_DIR/state/tree.json"
cp "$ROOT/tests/fixtures/quiet_events.jsonl" "$TMP_DIR/state/events.jsonl"

output="$($TMP_DIR/quiet.sh --json --idle 30 --now 2026-02-08T10:00:00Z)"

echo "$output" | jq -e 'length == 1 and .[0].id == "big" and .[0].idle_seconds >= 3600' >/dev/null

echo "quiet_test: ok"
