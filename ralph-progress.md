# Ralph Progress

## 2026-02-08
- Adds restore command to reload state from snapshots with optional backups.
- Documents snapshot restore usage in the README.

## 2026-02-07
- Adds an inspect command to surface agent details, workspace health, and log tail output.

## 2026-02-07
- Adds Postgres sync command for agent state with optional filters and schema support.
- Documents database sync usage in the README.

## 2026-02-07
- Adds export command for CSV/JSON agent data with filters and durations.
- Documents the export command in the README.

## 2026-02-07
- Adds agent annotation support with tags/notes, plus inspect visibility.

## 2026-02-07
- Expands report output with agent type breakdowns and duration stats.

## 2026-02-07
- Adds a report command that writes a markdown snapshot of current and recent agent activity.
- Documents the report command in the README.

## 2026-02-07
- Adds a compare command to show deltas between snapshots, including new agents and status changes.
- Documents the compare command in the README.

## 2026-02-07
- Adds a find command to locate agents by keyword across task, id, or workspace fields.
- Documents the new find command in the README.

## 2026-02-07
- Adds a timeline command to list agents chronologically with durations and filters.
- Documents the timeline command in the README.

## 2026-02-07
- Adds a status JSON output mode with alive checks and duration seconds.
- Documents the status JSON flag in the README.

## 2026-02-07
- Adds a workspace audit command to surface missing workspace paths and orphaned run directories.
- Documents the workspace command in the README.

## 2026-02-07
- Adds status/type filtering to status output while keeping matching descendants visible.
- Updates the README to mention status filtering support.

## 2026-02-07
- Adds recent command to list latest completed agents with durations and status filtering.
- Documents the recent command in the README.

## 2026-02-07
- Adds an archive command to move completed agent run folders into runs/archive.
- Records archive metadata in state helpers to track archived workspaces.

## 2026-02-07
- Adds type filtering to the recent command for narrowing by agent class.
- Documents the recent command in the README.

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

## 2026-02-07
- Adds a lineage command to show ancestry for any agent with timestamps.
- Documents the lineage command in the README.

## 2026-02-07
- Adds an overdue command to list running agents beyond a duration threshold.
- Documents the overdue command in the README.

## 2026-02-07
- Adds compare --list support to browse snapshot history with quick agent counts.
- Documents compare listing in the README.

## 2026-02-07
- Adds an inspect command to show agent details, child status counts, and pid/workspace health.
- Documents the inspect command in the README.

## 2026-02-07
- Adds notes command to list agents with annotations and filtering options.
- Documents the notes command in the README.
