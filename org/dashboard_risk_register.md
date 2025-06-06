# Ralph Dashboard Risk Register

| Risk | Trigger | Impact | Mitigation | Owner |
|------|---------|--------|------------|-------|
| BigRalph loses source parity | Collectors drift from upstream schema | Data becomes stale or wrong | BigRalph schedules schema checks and version gates | BigRalph |
| BigRalph delays access controls | Roles and permissions remain undefined | Sensitive data exposure risk rises | BigRalph defines RBAC scopes and reviews before launch | BigRalph |
| BigRalph underestimates alert load | Event volume spikes without tuning | Pager fatigue reduces response quality | BigRalph tunes alert thresholds and adds quiet hours | BigRalph |
| BigRalph skips runbook coverage | On-call steps remain unclear | Incident recovery slows | BigRalph adds runbooks and drills quarterly | BigRalph |
| BigRalph defers retention policy | Storage costs climb unexpectedly | Budget pressure increases | BigRalph enforces TTLs and data tiers | BigRalph |

BigRalph reviews this register weekly and logs changes in decisions.
