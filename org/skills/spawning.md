Spawn a ProductRalph:
```bash
./ralph/agents/productralph/spawn.sh "<task>" "<detailed instructions>"
```

Spawn a CodeRalph (called by ProductRalphs):
```bash
./ralph/agents/coderalph/spawn.sh "<repo-path>" "<branch-name>" "<subtask>" "<parent-id>"
```

Check on agents:
```bash
./ralph/status.sh
```

Signal completion:
```bash
source ./ralph/state/helpers.sh
ralph_update_status "<my-id>" "done"
```
