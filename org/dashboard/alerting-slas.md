# Ralph Dashboard Alerting and SLAs

## Alerting tiers
BigRalph defines four tiers:
- info: notify in dashboard only
- warning: notify Slack channel within 15 minutes
- high: page on-call within 5 minutes
- critical: page on-call and executive within 2 minutes

## Routing rules
BigRalph routes alerts by scope:
- data freshness: data-ops on-call
- agent failures: platform on-call
- deployment errors: release on-call
- security events: security on-call and audit log

## Service level targets
BigRalph sets the following SLAs:
- dashboard uptime: 99.9% monthly
- data freshness: 95% of sources within 15 minutes
- alert delivery: 99% within tier response windows

## Escalation and recovery
BigRalph escalates high alerts after 15 minutes and critical alerts after 5 minutes.
The playbook declares recovery when three consecutive health checks pass.

## Review cadence
BigRalph reviews alert noise weekly and updates routing rules monthly.
