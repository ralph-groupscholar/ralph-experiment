# Ralph Dashboard Metrics Catalog

## Principles

BigRalph prioritizes actionability, source traceability, and owner accountability.
BigRalph keeps metric names stable and logs changes in `org/decisions.md`.

## Core Metrics

| Metric | Definition | Source | Owner | Update Cadence |
| --- | --- | --- | --- | --- |
| Agent Throughput | BigRalph defines completed agent runs per day, grouped by agent type. | `runs/` logs | ProductRalph leads | Daily |
| Agent Cycle Time | BigRalph defines median time from agent spawn to finish. | `runs/` timestamps | Ralph | Daily |
| Queue Backlog | BigRalph defines open tasks by project and module. | `org/projects.md`, backlog tracker | BigRalph | Daily |
| Run Success Rate | BigRalph defines successful runs divided by total runs. | `runs/` status | Ralph | Daily |
| Run Failure Hotspots | BigRalph defines top failing tasks by frequency. | `runs/` error logs | Ralph | Daily |
| Module Health Score | BigRalph defines a weighted score across data freshness, error rate, and coverage. | Dashboard API | BigRalph | Daily |
| Data Freshness Lag | BigRalph defines minutes since last successful ingestion per source. | Collector logs | Ralph | Hourly |
| SLA Compliance | BigRalph defines percent of alerts resolved within SLA window. | Alerting logs | BigRalph | Weekly |
| Deployment Stability | BigRalph defines deploys without rollback over rolling 30 days. | CI/CD logs | Ralph | Weekly |
| Coverage Completeness | BigRalph defines percent of required events captured vs. spec. | Event taxonomy validator | ProductRalph leads | Weekly |

## Supporting Metrics

| Metric | Definition | Source | Owner | Update Cadence |
| --- | --- | --- | --- | --- |
| Documentation Drift | BigRalph defines days since last update for key org docs. | `org/` git history | BigRalph | Weekly |
| Audit Trail Completeness | BigRalph defines percent of access changes logged. | `runs/audit/` | Ralph | Weekly |
| Reviewer Load | BigRalph defines reviews per ProductRalph per week. | Review tracker | BigRalph | Weekly |
| Incident Recurrence | BigRalph defines repeated incidents within 30 days. | Incident log | Ralph | Monthly |

## Thresholds

BigRalph sets alert thresholds per module and revises them during monthly KPI reviews.
BigRalph targets 99% data freshness compliance and 95% SLA compliance.

## Notes

BigRalph keeps metric definitions consistent with `org/dashboard/event-taxonomy.md`.
