#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

output="$(${ROOT_DIR}/bootstrap-db.sh --dry-run)"

echo "$output" | rg "CREATE SCHEMA"
echo "$output" | rg "agent_state"
echo "$output" | rg "agent_events"

echo ""
echo "  Confirms bootstrap-db.sh dry run output."
echo ""
