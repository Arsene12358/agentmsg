#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: launch-agents.sh <project-path>

Creates a tmux session with three panes:
  - Left:         Claude Code TUI (AGENTMSG_IDENTITY=claude)
  - Top-right:    Codex TUI       (AGENTMSG_IDENTITY=codex)
  - Bottom-right: Live status monitor

Both agents start in TUI mode. Claude Code reads CLAUDE.md automatically.
Codex is started with instructions to begin the review-wait loop.

Prerequisites:
  - tmux installed
  - agentmsg installed and project set up (run setup-project.sh first)
  - claude (Claude Code CLI) installed
  - codex (OpenAI Codex CLI) installed
EOF
    exit 1
}

[ $# -lt 1 ] && usage
PROJECT="$(cd "$1" && pwd)"
SESSION="agents"

[ -d "$PROJECT/.git" ] || { echo "error: $PROJECT is not a git repository"; exit 1; }

# Kill existing session if any
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Create session — Pane 0: Claude Code
tmux new-session -d -s "$SESSION" -c "$PROJECT" -x 220 -y 50

# Pane 1: Codex (right split)
tmux split-window -h -t "$SESSION" -c "$PROJECT"

# Pane 2: Monitor (bottom-right split)
tmux split-window -v -t "$SESSION:0.1" -c "$PROJECT" -l 8

# Pane 0 — Claude Code
tmux send-keys -t "$SESSION:0.0" "export AGENTMSG_IDENTITY=claude" Enter
tmux send-keys -t "$SESSION:0.0" "sleep 1 && claude" Enter

# Pane 1 — Codex
# Codex needs an initial prompt to enter the review-wait loop.
# We feed it via a temp file that codex can read as its system prompt.
CODEX_PROMPT="You are a code reviewer. Follow the instructions in codex-instructions.md exactly. Start by running: agentmsg wait --timeout 3600 --type review_request"
tmux send-keys -t "$SESSION:0.1" "export AGENTMSG_IDENTITY=codex" Enter
tmux send-keys -t "$SESSION:0.1" "sleep 1 && codex" Enter

# Pane 2 — Status monitor
tmux send-keys -t "$SESSION:0.2" "watch -n2 agentmsg status" Enter

# Focus Claude's pane
tmux select-pane -t "$SESSION:0.0"

echo "Launching tmux session '$SESSION'..."
echo ""
echo "Layout:"
echo "┌────────────────────┬────────────────────┐"
echo "│                    │                    │"
echo "│  Claude Code       │  Codex             │"
echo "│  (implementer)     │  (reviewer)        │"
echo "│                    │                    │"
echo "│                    ├────────────────────┤"
echo "│                    │  agentmsg status   │"
echo "│                    │  (live monitor)    │"
echo "└────────────────────┴────────────────────┘"
echo ""
echo "Tip: In Claude's pane, give it a task. After it commits,"
echo "     it will automatically wait for Codex's review."
echo "     In Codex's pane, tell it to follow codex-instructions.md"
echo "     and start the review-wait loop."
echo ""

tmux attach -t "$SESSION"
