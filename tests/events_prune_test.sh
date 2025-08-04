#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVENTS_FILE="$ROOT/tests/fixtures/events_prune.jsonl"

output=$("$ROOT/events-prune.sh" --events "$EVENTS_FILE" --cutoff 2026-02-08T00:00:00Z)

echo "$output" | rg "Finds 2 of 3 events to keep."
echo "$output" | rg "Dry run complete."
