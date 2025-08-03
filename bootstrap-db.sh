#!/usr/bin/env bash
set -e

SCHEMA="ralph_experiment"
STATE_TABLE="agent_state"
EVENTS_TABLE="agent_events"
DRY_RUN=0

usage() {
  echo "Usage: ./bootstrap-db.sh [--schema name] [--state-table name] [--events-table name] [--dry-run]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --schema)
      SCHEMA="$2"
      shift 2
      ;;
    --state-table)
      STATE_TABLE="$2"
      shift 2
      ;;
    --events-table)
      EVENTS_TABLE="$2"
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

sql=$(cat <<SQL
BEGIN;
CREATE SCHEMA IF NOT EXISTS ${SCHEMA};
CREATE TABLE IF NOT EXISTS ${SCHEMA}.${STATE_TABLE} (
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
CREATE TABLE IF NOT EXISTS ${SCHEMA}.${EVENTS_TABLE} (
  event_hash text PRIMARY KEY,
  ts timestamptz,
  event text,
  agent text,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  ingested_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${STATE_TABLE}_status_idx ON ${SCHEMA}.${STATE_TABLE} (status);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${STATE_TABLE}_type_idx ON ${SCHEMA}.${STATE_TABLE} (type);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${STATE_TABLE}_updated_idx ON ${SCHEMA}.${STATE_TABLE} (updated_at);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${EVENTS_TABLE}_ts_idx ON ${SCHEMA}.${EVENTS_TABLE} (ts);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${EVENTS_TABLE}_event_idx ON ${SCHEMA}.${EVENTS_TABLE} (event);
CREATE INDEX IF NOT EXISTS ${SCHEMA}_${EVENTS_TABLE}_agent_idx ON ${SCHEMA}.${EVENTS_TABLE} (agent);
DO \$\$
BEGIN
  IF (SELECT COUNT(*) FROM ${SCHEMA}.${STATE_TABLE}) = 0 THEN
    INSERT INTO ${SCHEMA}.${STATE_TABLE} (
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
    ) VALUES
      (
        'seed-bigr-001',
        'bigralph',
        'running',
        1001,
        NULL,
        'Seed: coordinate experiment',
        now() - interval '6 hours',
        NULL,
        '/var/ralph/runs/seed-bigr-001',
        NULL,
        'Seeded by bootstrap-db.sh',
        '["seed","bootstrap"]'::jsonb,
        2,
        now() - interval '1 hour'
      ),
      (
        'seed-prod-001',
        'productralph',
        'running',
        1002,
        'seed-bigr-001',
        'Seed: draft roadmap',
        now() - interval '5 hours',
        NULL,
        '/var/ralph/runs/seed-prod-001',
        NULL,
        'Seeded by bootstrap-db.sh',
        '["seed","roadmap"]'::jsonb,
        1,
        now() - interval '2 hours'
      ),
      (
        'seed-code-001',
        'coderalph',
        'done',
        1003,
        'seed-prod-001',
        'Seed: prototype dashboard',
        now() - interval '4 hours',
        now() - interval '2 hours',
        '/var/ralph/runs/seed-code-001',
        NULL,
        'Seeded by bootstrap-db.sh',
        '["seed","prototype"]'::jsonb,
        0,
        now() - interval '2 hours'
      );
  END IF;

  IF (SELECT COUNT(*) FROM ${SCHEMA}.${EVENTS_TABLE}) = 0 THEN
    INSERT INTO ${SCHEMA}.${EVENTS_TABLE} (
      event_hash,
      ts,
      event,
      agent,
      detail
    )
    VALUES
      (
        md5('seed|spawned|seed-bigr-001'),
        now() - interval '6 hours',
        'spawned',
        'seed-bigr-001',
        '{"task":"Seed: coordinate experiment"}'::jsonb
      ),
      (
        md5('seed|spawned|seed-prod-001'),
        now() - interval '5 hours 30 minutes',
        'spawned',
        'seed-prod-001',
        '{"task":"Seed: draft roadmap","parent":"seed-bigr-001"}'::jsonb
      ),
      (
        md5('seed|status|seed-code-001'),
        now() - interval '4 hours',
        'status',
        'seed-code-001',
        '{"from":"running","to":"done"}'::jsonb
      ),
      (
        md5('seed|note|seed-code-001'),
        now() - interval '3 hours 30 minutes',
        'note',
        'seed-code-001',
        '{"note":"Prototype shipped"}'::jsonb
      );
  END IF;
END
\$\$;
COMMIT;
SQL
)

if [ "$DRY_RUN" -eq 1 ]; then
  echo "$sql"
  exit 0
fi

DB_URL="${RALPH_DATABASE_URL:-${DATABASE_URL:-}}"

if [ -z "$DB_URL" ]; then
  echo ""
  echo "  Finds no database URL. Sets RALPH_DATABASE_URL to bootstrap."
  echo ""
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo ""
  echo "  Finds no psql client. Installs PostgreSQL client tools first."
  echo ""
  exit 1
fi

psql "$DB_URL" <<SQL
${sql}
SQL

echo ""
echo "  Bootstraps ${SCHEMA}.${STATE_TABLE} and ${SCHEMA}.${EVENTS_TABLE} with seed data."
echo ""
