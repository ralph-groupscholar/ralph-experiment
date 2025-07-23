#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

STATUS_FILTER=""
TYPE_FILTER=""
DRY_RUN=0
SCHEMA="ralph_experiment"
TABLE="agent_state"

usage() {
  echo "Usage: ./sync.sh [--status running|done|failed] [--type bigralph|productralph|coderalph] [--schema name] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --type)
      TYPE_FILTER="$2"
      shift 2
      ;;
    --schema)
      SCHEMA="$2"
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

csv_to_json_array() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "null"
    return
  fi
  printf "%s" "$input" | tr ',' '\n' | jq -R -s 'split("\n")[:-1]'
}

if [ ! -f "$RALPH_STATE" ]; then
  echo ""
  echo -e "  Finds no state file. Runs ./start.sh first."
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")

if [ "$agent_count" = "0" ]; then
  echo ""
  echo -e "  Finds no agents running. Starts with ./start.sh"
  echo ""
  exit 0
fi

DB_URL="${RALPH_DATABASE_URL:-${DATABASE_URL:-}}"

if [ -z "$DB_URL" ]; then
  echo ""
  echo "  Finds no database URL. Sets RALPH_DATABASE_URL to sync state."
  echo ""
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo ""
  echo "  Finds no psql client. Installs PostgreSQL client tools first."
  echo ""
  exit 1
fi

status_json="$(csv_to_json_array "$STATUS_FILTER")"
type_json="$(csv_to_json_array "$TYPE_FILTER")"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

entry_count=$(jq -r \
  --argjson statuses "$status_json" \
  --argjson types "$type_json" \
  '
  .agents
  | to_entries
  | map(select(
      ($statuses == null or ($statuses | index(.value.status) != null))
      and ($types == null or ($types | index(.value.type) != null))
    ))
  | length
' "$RALPH_STATE")

if [ "$entry_count" = "0" ]; then
  echo ""
  echo -e "  Finds no agents for the provided filters."
  echo ""
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  echo ""
  echo "  Finds $entry_count agents ready to sync."
  echo ""
  exit 0
fi

tmp_file="$(mktemp)"

jq -r \
  --argjson statuses "$status_json" \
  --argjson types "$type_json" \
  --arg now "$now" \
  '
  .agents
  | to_entries
  | map(select(
      ($statuses == null or ($statuses | index(.value.status) != null))
      and ($types == null or ($types | index(.value.type) != null))
    ))
  | sort_by(.value.started_at // "")
  | .[]
  | [
      .key,
      (.value.type // ""),
      (.value.status // ""),
      (.value.pid // ""),
      (.value.parent // ""),
      (.value.task // ""),
      (.value.started_at // ""),
      (.value.ended_at // ""),
      (.value.workspace // ""),
      (.value.archived_at // ""),
      (.value.note // ""),
      ((.value.tags // []) | @json),
      ((.value.children | length) // 0),
      $now
    ]
  | @csv
' "$RALPH_STATE" > "$tmp_file"

psql "$DB_URL" <<SQL
BEGIN;
CREATE SCHEMA IF NOT EXISTS ${SCHEMA};
CREATE TABLE IF NOT EXISTS ${SCHEMA}.${TABLE} (
  id text PRIMARY KEY,
  type text,
  status text,
  pid integer,
  parent text,
  task text,
  started_at timestamptz,
  ended_at timestamptz,
  workspace text,
  archived_at timestamptz,
  note text,
  tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  children_count integer,
  updated_at timestamptz,
  synced_at timestamptz NOT NULL DEFAULT now()
);
CREATE TEMP TABLE ralph_agent_stage (
  id text,
  type text,
  status text,
  pid integer,
  parent text,
  task text,
  started_at timestamptz,
  ended_at timestamptz,
  workspace text,
  archived_at timestamptz,
  note text,
  tags jsonb,
  children_count integer,
  updated_at timestamptz
);
\copy ralph_agent_stage FROM '${tmp_file}' WITH (FORMAT csv, NULL '');
INSERT INTO ${SCHEMA}.${TABLE} (
  id,
  type,
  status,
  pid,
  parent,
  task,
  started_at,
  ended_at,
  workspace,
  archived_at,
  note,
  tags,
  children_count,
  updated_at
)
SELECT
  id,
  type,
  status,
  pid,
  parent,
  task,
  started_at,
  ended_at,
  workspace,
  archived_at,
  note,
  tags,
  children_count,
  updated_at
FROM ralph_agent_stage
ON CONFLICT (id) DO UPDATE SET
  type = EXCLUDED.type,
  status = EXCLUDED.status,
  pid = EXCLUDED.pid,
  parent = EXCLUDED.parent,
  task = EXCLUDED.task,
  started_at = EXCLUDED.started_at,
  ended_at = EXCLUDED.ended_at,
  workspace = EXCLUDED.workspace,
  archived_at = EXCLUDED.archived_at,
  note = EXCLUDED.note,
  tags = EXCLUDED.tags,
  children_count = EXCLUDED.children_count,
  updated_at = EXCLUDED.updated_at,
  synced_at = now();
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
echo "  Syncs $entry_count agents to ${SCHEMA}.${TABLE}."
echo ""
