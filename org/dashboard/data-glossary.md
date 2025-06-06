# Ralph Dashboard Data Glossary

## Entities

| Term | Definition | Source of Truth |
| --- | --- | --- |
| Agent | BigRalph defines a running instance that executes a task (BigRalph, ProductRalph, CodeRalph). | `state/` and `runs/` |
| Run | BigRalph defines a single execution of an agent with logs and artifacts. | `runs/` |
| Task | BigRalph defines a scoped unit of work assigned to an agent. | Agent prompts and run metadata |
| Artifact | BigRalph defines output files produced by a run (logs, reports, patches). | `runs/` and repo history |
| Module | BigRalph defines a dashboard tile or section that summarizes a domain. | `org/dashboard.md` |
| Event | BigRalph defines a structured record emitted by collectors per taxonomy. | `org/dashboard/event-taxonomy.md` |
| Collector | BigRalph defines a process that ingests data into the dashboard pipeline. | Collector configuration |
| SLA | BigRalph defines the time window to acknowledge and resolve alerts. | `org/dashboard/alerting-slas.md` |
| Snapshot | BigRalph defines a point-in-time export of dashboard state. | `runs/` snapshots |
| Backlog Item | BigRalph defines a planned or open task tracked for delivery. | Project tracker |

## Status Terms

| Term | Definition |
| --- | --- |
| Healthy | BigRalph defines data freshness within thresholds and error rates below targets. |
| Degraded | BigRalph defines data freshness outside thresholds or errors above targets. |
| Stale | BigRalph defines no fresh data beyond the maximum tolerated lag. |
| Complete | BigRalph defines coverage that meets or exceeds required event set. |

## Time Terms

| Term | Definition |
| --- | --- |
| Cadence | BigRalph defines the scheduled review or refresh interval. |
| Window | BigRalph defines the time range for aggregation (daily, weekly, monthly). |
| Lag | BigRalph defines elapsed time since last successful ingest. |

## Ownership Terms

| Term | Definition |
| --- | --- |
| Owner | BigRalph defines the person or role accountable for metric quality. |
| Steward | BigRalph defines the role that maintains definitions and taxonomy. |

## Notes

BigRalph aligns glossary terms with event taxonomy and metric catalog.
