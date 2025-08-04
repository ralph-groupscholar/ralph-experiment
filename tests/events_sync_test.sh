#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVENTS_FILE="$ROOT/tests/fixtures/events.jsonl"

output=$("$ROOT/sync-events.sh" --events "$EVENTS_FILE" --dry-run)

echo "$output" | rg "Finds 3 events ready to sync."

output=$("$ROOT/sync-events.sh" --events "$EVENTS_FILE" --since 2026-02-08T00:00:00Z --dry-run)

echo "$output" | rg "Finds 2 events ready to sync."
