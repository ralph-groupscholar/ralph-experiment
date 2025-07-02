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
| `./status.sh` | View the agent tree |
| `./status.sh --verbose` | View the agent tree with timestamps and durations |
| `./health.sh` | Summarize agent health, stale processes, and oldest running agent |
| `./audit.sh` | Audits the state file for inconsistencies and stale data |
| `./sweep.sh` | Marks stale running agents as failed in state |
| `./snapshot.sh` | Captures a timestamped state snapshot and summary |
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
