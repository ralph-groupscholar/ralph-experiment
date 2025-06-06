# Ralph Dashboard Data Quality Playbook

## Purpose

BigRalph defines the standards that keep Ralph Dashboard data accurate, timely, and trustworthy.

## Quality Dimensions

BigRalph enforces freshness, completeness, validity, consistency, and lineage traceability.

## Core Checks

BigRalph validates schema conformance on every collector run.
BigRalph enforces required fields, value ranges, and enum membership per module.
BigRalph detects null spikes, zeroed metrics, and sudden variance beyond expected bands.
BigRalph reconciles daily aggregates against source totals and flags drift above 2%.

## Monitoring Cadence

BigRalph runs inline checks on each ingest, hourly rollups for drift, and daily audits at 02:00 local time.
BigRalph logs failures to `runs/quality/` and summarizes deltas in the daily digest.

## Ownership

ProductRalph owners define module-specific thresholds and remediation steps.
BigRalph approves threshold changes and tracks ownership in `org/decisions.md`.

## Escalation

BigRalph escalates to ProductRalph owners when any module fails two consecutive checks.
BigRalph pauses public tiles when more than 30% of modules fail freshness or validity checks.
BigRalph records incidents and remediation actions in `org/decisions.md`.

## Tooling

BigRalph uses schema validators, anomaly detection rules, and lineage tags on every payload.
BigRalph stores quality snapshots in `runs/quality/` and retains 90 days of audits.
