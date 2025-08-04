#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

SCHEMA="ralph_experiment"
TABLE="agent_events"
SINCE=""
DRY_RUN=0
EVENTS_PATH=""

usage() {
  echo "Usage: ./sync-events.sh [--since ISO8601] [--schema name] [--table name] [--events path] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="$2"
      shift 2
      ;;
    --schema)
      SCHEMA="$2"
      shift 2
      ;;
    --table)
      TABLE="$2"
      shift 2
      ;;
    --events)
      EVENTS_PATH="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

EVENTS_FILE="$RALPH_EVENTS"
if [ -n "$EVENTS_PATH" ]; then
  EVENTS_FILE="$EVENTS_PATH"
fi

if [ ! -f "$EVENTS_FILE" ]; then
  echo ""
  echo "  Finds no event log yet. Runs ./start.sh or updates state first."
  echo ""
  exit 0
fi

filtered=$(jq -s \
  --arg since "$SINCE" \
  '
    [
      .[]
      | select($since == "" or .ts >= $since)
    ]
  ' "$EVENTS_FILE")

count=$(echo "$filtered" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo ""
  echo "  Finds no matching events to sync."
  echo ""
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo ""
  echo "  Finds $count events ready to sync."
  echo ""
  exit 0
fi

DB_URL="${RALPH_DATABASE_URL:-${DATABASE_URL:-}}"

if [ -z "$DB_URL" ]; then
  echo ""
  echo "  Finds no database URL. Sets RALPH_DATABASE_URL to sync events."
  echo ""
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo ""
  echo "  Finds no psql client. Installs PostgreSQL client tools first."
  echo ""
  exit 1
fi

tmp_file="$(mktemp)"

echo "$filtered" | jq -r \
  '[
    .[]
    | [.ts, .event, .agent, (.detail // {} | @json)]
    | @csv
  ]
  | .[]
  ' > "$tmp_file"

psql "$DB_URL" <<SQL
BEGIN;
CREATE SCHEMA IF NOT EXISTS ${SCHEMA};
CREATE TABLE IF NOT EXISTS ${SCHEMA}.${TABLE} (
  event_hash text PRIMARY KEY,
  ts timestamptz,
  event text,
  agent text,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  ingested_at timestamptz NOT NULL DEFAULT now()
);
CREATE TEMP TABLE ralph_event_stage (
  ts timestamptz,
  event text,
  agent text,
  detail_text text
);
\copy ralph_event_stage FROM '${tmp_file}' WITH (FORMAT csv, NULL '');
INSERT INTO ${SCHEMA}.${TABLE} (
  event_hash,
  ts,
  event,
  agent,
  detail
)
SELECT
  md5(
    coalesce(ts::text, '')
    || '|' || coalesce(event, '')
    || '|' || coalesce(agent, '')
    || '|' || coalesce(detail_text, '')
  ) AS event_hash,
  ts,
  event,
  agent,
  coalesce(detail_text, '{}')::jsonb
FROM ralph_event_stage
ON CONFLICT (event_hash) DO NOTHING;
COMMIT;
SQL

psql_status="$?"
rm -f "$tmp_file"

if [ "$psql_status" -ne 0 ]; then
  echo ""
  echo "  Finds a sync failure. Reviews database connectivity and permissions."
  echo ""
  exit 1
fi

echo ""
echo "  Syncs $count events to ${SCHEMA}.${TABLE}."
echo ""
