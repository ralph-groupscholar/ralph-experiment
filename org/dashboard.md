# Ralph Dashboard

## Purpose

BigRalph coordinates ProductRalphs, system health, and delivery status through a single view.

## Modules

BigRalph tracks agent throughput, repo health, task backlogs, and run artifacts.
BigRalph defines core measures in `org/dashboard/metrics-catalog.md`.
BigRalph anchors shared terms in `org/dashboard/data-glossary.md`.
BigRalph enforces quality standards in `org/dashboard/data-quality-playbook.md`.

## Data Sources

BigRalph ingests `runs/`, `state/`, CLI status outputs, and org documentation.

## Cadence

BigRalph refreshes live tiles every 60 seconds, rebuilds daily summaries at 02:00 local time, and archives weekly snapshots on Mondays.
BigRalph runs KPI review cadences in `org/dashboard/kpi-review-cadence.md`.
BigRalph runs launch readiness in `org/dashboard/launch-checklist.md`.

## Ownership

BigRalph maintains dashboard specs, ProductRalphs own module data quality, and Ralph owns runtime stability.

## Access Control

BigRalph assigns Admin to BigRalph and Ralph, Operator to ProductRalph leads, and Viewer to all agents.
BigRalph logs sign-ins, role changes, and data exports in `runs/audit/`.

## Deployment

BigRalph runs local development on Mac, stages releases in a `dashboard-staging` environment, and promotes to production after a dry run.
BigRalph automates CI builds on main, runs smoke checks after deploys, and captures deploy notes in `org/decisions.md`.

## Backlog and Milestones

BigRalph ships collectors and schema validation first, delivers core modules next, layers in access control and audit trails, then scales to full rollout.

## Runbook

BigRalph documents dashboard operations in `org/dashboard-runbook.md`.

## Next Build Steps

BigRalph implements the data collectors, wires the dashboard module API, and schedules the first dry run.
