Git worktrees let multiple branches be checked out simultaneously in separate directories.

Create a worktree:
```bash
git worktree add <path> <branch>
```

Remove when done:
```bash
git worktree remove <path>
```

CodeRalphs always work on worktrees so they never conflict with each other.
