# Ralph Progress

## 2026-02-07
- Adds an archive command to move completed agent run folders into runs/archive.
- Records archive metadata in state helpers to track archived workspaces.

## 2026-02-07
- Adds a metrics command to summarize agent counts, type breakdowns, and duration stats.
- Documents the new metrics command in the README.

## 2026-02-07
- Records ended_at timestamps when agents move to done/failed, preserving durations for verbose status.
- Backfills missing started_at timestamps when status updates occur.

## 2026-02-07
- Adds a sweep utility to mark stale agents as failed and records cleanup timestamps.
- Updates command documentation for the new sweep script.
- Adds verbose status output with timestamps and durations plus missing state-file guard.

## 2026-02-07
- Adds a health command to summarize agent counts, stale processes, and oldest running agent.
- Documents the new health command in the README.

## 2026-02-07
- Adds a snapshot command that archives state and a markdown summary.
- Documents the new snapshot command in the README.

## 2026-02-07
- Replaces health duration calculation with pure bash/date to avoid python3 dependency.

## 2026-02-07
- Adds a state audit command to flag inconsistent or stale agent entries.
- Documents the new audit command in the README.

## 2026-02-07
- Adds an audit command to validate state integrity (schema, parent/child links, status fields).
- Documents the audit command in the README.

## 2026-02-07
- Adds a prune command to remove completed agents from state with a dry-run option and child-safety check.
- Adds a helper to delete agents while keeping parent child lists clean.
- Documents the new prune command in the README.
