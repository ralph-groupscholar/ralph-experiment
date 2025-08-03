#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/state"
cp "$ROOT/hubs.sh" "$TMP_DIR/hubs.sh"
cp "$ROOT/state/helpers.sh" "$TMP_DIR/state/helpers.sh"
cp "$ROOT/tests/fixtures/tree.json" "$TMP_DIR/state/tree.json"

output="$($TMP_DIR/hubs.sh --json)"

echo "$output" | jq -e 'map(select(.id == "big" and .child_count == 2 and .running == 1 and .done == 1 and .failed == 0)) | length == 1' >/dev/null

echo "$output" | jq -e 'map(select(.id == "prod1" and .child_count == 2 and .running == 0 and .done == 1 and .failed == 1)) | length == 1' >/dev/null

echo "$($TMP_DIR/hubs.sh --json --type productralph)" | jq -e 'length == 2 and all(.type == "productralph")' >/dev/null

echo "$($TMP_DIR/hubs.sh --json --status running)" | jq -e 'length == 2 and all(.status == "running")' >/dev/null

echo "hubs_test: ok"
