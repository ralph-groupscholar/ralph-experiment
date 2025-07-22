> **WARNING: This experiment failed. Do not attempt to replicate this setup.** The hierarchical agent architecture described below did not work as intended and is not a viable approach. This repo is preserved for reference only.

# ralph

A hierarchical AI agent system that runs GroupScholar autonomously. Start it once, walk away.

## Quick start

```bash
./start.sh
```

That's it. BigRalph is now running the company.

## How it works

Three tiers of agents, each spawning the next:

```
BigRalph (CEO, runs forever)
├── ProductRalph-001 (task: "Build employee tracker")
│   ├── CodeRalph-001a (branch: feat/database)
│   ├── CodeRalph-001b (branch: feat/api)
│   └── CodeRalph-001c (branch: feat/frontend)
├── ProductRalph-002 (task: "Update company docs")
│   └── CodeRalph-002a (branch: feat/docs)
└── ...
```

- **BigRalph** makes org-wide decisions, spawns ProductRalphs, creates new skills and departments. He runs forever.
- **ProductRalphs** take a task, break it down, spawn CodeRalphs, manage repos, merge branches, update docs.
- **CodeRalphs** write code on git worktrees. They do their task and signal done.

## Commands

| Command | What it does |
|---------|-------------|
| `./start.sh` | Launch BigRalph (the only command you need) |
| `./status.sh` | Views the agent tree (supports status/type filters) |
| `./status.sh --verbose` | Views the agent tree with timestamps and durations |
| `./status.sh --json` | Emits machine-readable status JSON |
| `./health.sh` | Summarize agent health, stale processes, and oldest running agent |
| `./recent.sh` | Show recent agents with optional status/type filters |
| `./audit.sh` | Audit state integrity (schema, parent/child consistency, status) |
| `./sweep.sh` | Marks stale running agents as failed in state |
| `./archive.sh` | Archives completed agent run directories into runs/archive |
| `./prune.sh` | Removes completed agents from state (skips those with running children) |
| `./snapshot.sh` | Captures a timestamped state snapshot and summary |
| `./compare.sh` | Compares two snapshots (latest vs previous by default; use --list to browse) |
| `./metrics.sh` | Summarize agent counts, types, and duration stats |
| `./lineage.sh` | Show the ancestry path for a specific agent |
| `./find.sh` | Finds agents by keyword across task, id, or workspace fields |
| `./timeline.sh` | Shows a chronological agent timeline with durations and filters |
| `./overdue.sh` | Shows running agents over a duration threshold with optional filters |
| `./workspace.sh` | Audits workspaces for missing or orphaned run directories |
| `./inspect.sh` | Shows detailed info for a single agent with pid/workspace health |
| `./annotate.sh` | Adds notes and tags to agents |
| `./report.sh` | Writes a markdown report of current and recent agent activity |
| `./export.sh` | Exports agent data to CSV or JSON with filters |
| `./stop.sh` | Emergency stop all agents |

## Structure

```
ralph/
├── start.sh / stop.sh / status.sh    # Entry points
├── state/
│   ├── tree.json                      # Agent tree (central state)
│   └── helpers.sh                     # State management utilities
├── agents/
│   ├── bigralph/                      # CEO agent
│   ├── productralph/                  # Product manager template + spawner
│   └── coderalph/                     # Coder template + spawner
├── org/                               # Org knowledge (BigRalph reads/writes)
│   ├── about.md                       # What GroupScholar is
│   ├── projects.md                    # Project registry
│   ├── decisions.md                   # Decision log
│   └── skills/                        # Extensible skills
└── runs/                              # Active agent instances
```

## Editing prompts

System prompts live in `agents/`:
- `agents/bigralph/system-prompt.md` — BigRalph's persona and capabilities
- `agents/productralph/system-prompt-template.md` — ProductRalph template
- `agents/coderalph/system-prompt-template.md` — CodeRalph template

Edit these to change how ralphs behave. Keep them short — creativity comes from freedom.

## Self-extensibility

BigRalph can create new skills in `org/skills/`, add departments to `org/about.md`, and spawn ProductRalphs for anything he imagines. The system is designed to grow on its own.
