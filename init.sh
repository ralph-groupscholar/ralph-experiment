#!/usr/bin/env bash
set -e

# ── Colors & Symbols ────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

CHECK="${GREEN}✔${RESET}"
DOT="${DIM}○${RESET}"
CROSS="${RED}✖${RESET}"

# ── Header ───────────────────────────────────────────────────────────
header() {
  echo ""
  echo -e "  ${CYAN}${BOLD}ralph init${RESET}"
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ── Footer ───────────────────────────────────────────────────────────
footer() {
  echo ""
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${GREEN}${BOLD}✔ All done!${RESET}  Project ready at ${BOLD}${TARGET_DIR}${RESET}"
  echo ""
  echo -e "  ${DIM}Next steps:${RESET}"
  echo -e "    ${DIM}1.${RESET} Add your PRD to ${BOLD}ralph-prompt.md${RESET}"
  echo -e "    ${DIM}2.${RESET} Run ${BOLD}./ralph.sh${RESET} to start ralph"
  echo ""
}

# ── Validate args ────────────────────────────────────────────────────
if [ -z "$1" ]; then
  echo ""
  echo -e "  ${CROSS} ${RED}${BOLD}Missing argument:${RESET} target directory is required."
  echo ""
  echo -e "  ${DIM}Usage:${RESET}  ${BOLD}./init.sh <directory>${RESET}"
  echo ""
  echo -e "  ${DIM}Examples:${RESET}"
  echo -e "    ./init.sh my-project"
  echo -e "    ./init.sh ~/dev/cool-app"
  echo ""
  exit 1
fi

TARGET_DIR="$1"

header

# ── 1. Create directory ─────────────────────────────────────────────
if [ -d "$TARGET_DIR" ]; then
  echo -e "  ${DOT}  Directory ${BOLD}${TARGET_DIR}${RESET} ${DIM}already exists${RESET}"
else
  mkdir -p "$TARGET_DIR"
  echo -e "  ${CHECK}  Created directory ${BOLD}${TARGET_DIR}${RESET}"
fi

# ── 2. Init git repo ────────────────────────────────────────────────
if [ -d "$TARGET_DIR/.git" ]; then
  echo -e "  ${DOT}  Git repo ${DIM}already initialized${RESET}"
else
  git init -q "$TARGET_DIR"
  echo -e "  ${CHECK}  Initialized git repo"
fi

# ── 3. Configure git user ────────────────────────────────────────────
git -C "$TARGET_DIR" config user.name "Ralph"
git -C "$TARGET_DIR" config user.email "ralph@groupscholar.com"
echo -e "  ${CHECK}  Configured git user as ${BOLD}Ralph${RESET} ${DIM}<ralph@groupscholar.com>${RESET}"

# ── 4. Set git remote origin ────────────────────────────────────────
REPO_NAME="$(basename "$(cd "$TARGET_DIR" && pwd)")"
REMOTE_URL="git@ralph:ralph-groupscholar/${REPO_NAME}.git"
if git -C "$TARGET_DIR" remote get-url origin &>/dev/null; then
  git -C "$TARGET_DIR" remote set-url origin "$REMOTE_URL"
  echo -e "  ${CHECK}  Updated remote origin → ${BOLD}${REMOTE_URL}${RESET}"
else
  git -C "$TARGET_DIR" remote add origin "$REMOTE_URL"
  echo -e "  ${CHECK}  Added remote origin → ${BOLD}${REMOTE_URL}${RESET}"
fi

# ── 5. Create ralph.sh ──────────────────────────────────────────────
cat > "$TARGET_DIR/ralph.sh" << 'EOF'
while :; do
  codex exec --skip-git-repo-check  --sandbox danger-full-access "$(cat ralph-prompt.md)"
done
EOF
chmod +x "$TARGET_DIR/ralph.sh"
echo -e "  ${CHECK}  Created ${BOLD}ralph.sh${RESET}"

# ── 6. Create ralph-prompt.md ───────────────────────────────────────
cat > "$TARGET_DIR/ralph-prompt.md" << 'EOF'
@PRD.md @ralph-progress.md

1. Find the highest-priority task and implement it.
2. Run your tests and type checks.
3. Update the PRD with what was done.
4. Append your progress to ralph-progress.md.
5. Commit your changes and push to GitHub.

ONLY WORK ON A SINGLE TASK.
Never EVER ask the user for anything.
If the PRD is complete, output <promise>COMPLETE</promise>.
EOF
echo -e "  ${CHECK}  Created ${BOLD}ralph-prompt.md${RESET}"

# ── 7. Create ralph-progress.md ─────────────────────────────────────
touch "$TARGET_DIR/ralph-progress.md"
echo -e "  ${CHECK}  Created ${BOLD}ralph-progress.md${RESET}"

footer
