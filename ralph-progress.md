# Ralph Progress

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
