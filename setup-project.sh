#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: setup-project.sh <project-path>

Bootstraps a project for TUI-mode dual-agent workflow:
  1. Initializes agentmsg directories
  2. Installs git hooks (post-commit, pre-push)
  3. Copies CLAUDE.md into the project root
  4. Copies codex-instructions.md for reference
  5. Prints the tmux launcher command

The project must be an existing git repository.
EOF
    exit 1
}

[ $# -lt 1 ] && usage
PROJECT="$1"

[ -d "$PROJECT/.git" ] || { echo "error: $PROJECT is not a git repository"; exit 1; }
command -v agentmsg >/dev/null 2>&1 || { echo "error: agentmsg not on PATH (run install.sh first)"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq is required"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up agentmsg for: $PROJECT"
echo ""

# 1. Init agentmsg + install hooks
agentmsg init "$PROJECT"
echo ""

# 2. Copy agent instruction files
if [ ! -f "$PROJECT/CLAUDE.md" ]; then
    cp "$SCRIPT_DIR/templates/CLAUDE.md" "$PROJECT/CLAUDE.md"
    echo "Created $PROJECT/CLAUDE.md"
else
    echo "CLAUDE.md already exists, skipping (review templates/CLAUDE.md to merge manually)"
fi

cp "$SCRIPT_DIR/templates/codex-instructions.md" "$PROJECT/codex-instructions.md"
echo "Created $PROJECT/codex-instructions.md"
echo ""

# 3. Print next steps
ABS_PROJECT="$(cd "$PROJECT" && pwd)"
cat <<EOF
Setup complete! To start the dual-agent TUI session:

  $([ -f "$SCRIPT_DIR/launch-agents.sh" ] && echo "$SCRIPT_DIR/launch-agents.sh $ABS_PROJECT" || echo "# See launch-agents.sh")

Or manually in two separate terminals:

  Terminal 1 (Claude Code):
    cd $ABS_PROJECT
    export AGENTMSG_IDENTITY=claude
    claude

  Terminal 2 (Codex):
    cd $ABS_PROJECT
    export AGENTMSG_IDENTITY=codex
    codex

  Terminal 3 (Monitor — optional):
    watch -n2 agentmsg status

Claude Code will automatically read CLAUDE.md and follow the review protocol.
For Codex, paste the first instruction from codex-instructions.md as your
opening prompt, or use the launcher which does this automatically.
EOF
