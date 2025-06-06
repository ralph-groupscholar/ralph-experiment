# Ralph Dashboard Event Taxonomy

## Purpose
BigRalph defines a shared event language for dashboard telemetry and uses it to keep collection consistent across systems.

## Entity naming
BigRalph standardizes entity IDs as `scope.type.id`.
The taxonomy uses `org`, `system`, `agent`, `run`, `job`, `repo`, `service`, `user`, and `incident` for `type`.
The taxonomy favors stable IDs and avoids ephemeral names in the primary key.

## Event categories
BigRalph groups events by intent:
- lifecycle: start, stop, spawn, complete, fail
- health: heartbeat, stall, error, recovery
- delivery: build, deploy, release, rollback
- data: ingest, transform, export, purge
- access: grant, revoke, login, audit
- finance: cost, budget, variance

## Standard payload fields
BigRalph uses these baseline fields in every event:
- `event_name`, `event_version`, `event_time`
- `entity_id`, `entity_type`, `scope_id`
- `actor_type`, `actor_id`, `actor_role`
- `status`, `severity`, `reason`
- `duration_ms`, `retry_count`, `attempt`
- `source_system`, `source_region`, `source_env`
- `tags` (list), `meta` (freeform map)

## Sampling rules
BigRalph samples noisy events at the edge:
- health heartbeats sample at 1 per 5 minutes per entity
- data ingest events sample at 1 per 1,000 items after totals record
- access audit events record 100% for privileged roles and 10% for standard roles
- error events record 100% and disable sampling on severity high or critical

## Example events
BigRalph records example payloads for clarity:
- `agent.spawned` with actor, run, and parent link
- `run.completed` with duration, status, and artifact summary
- `data.purged` with retention tier, reason, and counts

## Governance
BigRalph reviews version bumps, deprecates fields with a 30-day overlap, and keeps a changelog in `org/dashboard/event-taxonomy.md`.
