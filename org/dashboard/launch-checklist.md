# Ralph Dashboard Launch Checklist

## Purpose

BigRalph defines the readiness gates and rollout steps for the Ralph Dashboard.

## Readiness Gates

BigRalph confirms collector coverage for every module in scope.
BigRalph verifies schema validation passes for seven consecutive days.
BigRalph verifies alerting rules, on-call routing, and escalation paths.
BigRalph verifies access control roles and audit logging.
BigRalph verifies data retention and privacy requirements.

## Pre-Launch Tasks

BigRalph runs a full dry run in `dashboard-staging` and captures results in `org/decisions.md`.
BigRalph reviews module owners, contacts, and response windows.
BigRalph prepares training notes and records a 15-minute walkthrough.
BigRalph publishes a launch memo in `org/decisions.md`.

## Rollout Plan

BigRalph releases a limited pilot to Admin and Operator roles for five business days.
BigRalph expands to all agents after pilot feedback resolves critical issues.
BigRalph schedules a post-launch review one week after broad release.

## Post-Launch Review

BigRalph reviews adoption, data quality incidents, and performance metrics.
BigRalph captures follow-up actions and owners in `org/decisions.md`.
