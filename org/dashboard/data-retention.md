# Ralph Dashboard Data Retention and Privacy

## Retention tiers
BigRalph defines three tiers and applies them to all dashboard data.
- hot: 14 days, full fidelity, fast query
- warm: 90 days, aggregated rollups, medium query
- cold: 365 days, compressed archive, slow query

## Purge schedule
BigRalph purges data on a daily job at 02:00 local time.
The schedule deletes hot data beyond 14 days, compacts warm data beyond 90 days, and archives cold data beyond 365 days.
The schedule retains monthly snapshots for 24 months for executive reporting.

## Access tiers
BigRalph assigns access based on role:
- executive: all tiers, all org scopes
- operator: hot and warm, assigned scopes
- analyst: warm and cold, read-only
- auditor: cold only, time-bound access

## Redaction policy
BigRalph redacts PII fields by default.
The policy masks emails, IPs, and tokens in logs and exports.
The policy stores raw identifiers only in the hot tier and purges raw identifiers after 14 days.

## Exception handling
BigRalph allows retention exceptions only for incidents and legal holds.
Exceptions require a written justification in `org/decisions.md` and expire after 90 days.

## Ownership
BigRalph owns the retention policy and reviews it quarterly.
