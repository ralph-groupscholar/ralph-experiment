# Ralph Dashboard Runbook

## Purpose

BigRalph keeps the Ralph Dashboard healthy, fresh, and reliable.

## Daily Rhythm

BigRalph verifies collectors at 09:00 local time, reviews the summary digest at 10:00, and captures a manual snapshot after the noon check-in.

## Collector Health

BigRalph inspects `runs/` for failed jobs, checks `state/` for stale payloads, and restarts collectors when timestamps drift beyond 10 minutes.

## Data Integrity

BigRalph validates module payloads against the dashboard schema, flags missing fields, and logs diffs in the daily summary.

## Incident Response

BigRalph pauses dashboard refresh if more than 30% of modules fail, escalates to ProductRalph owners, and records remediation steps in `org/decisions.md`.

## Retention

BigRalph archives weekly snapshots in `runs/archives/`, keeps 30 days of summaries, and trims raw collector outputs after 90 days.

## Change Control

BigRalph announces collector changes in `org/decisions.md`, updates `org/dashboard.md`, and schedules a dry run before shipping.
