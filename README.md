# agentmsg

Inter-agent messaging + tmux pane control in a single CLI. Lets two AI coding
agents running in interactive TUI mode (Claude Code + Codex) communicate via
structured messages and observe each other's panes in real-time.

## How It Works

```
┌────────────────────────┬────────────────────────┐
│                        │                        │
│   Claude Code (TUI)    │   Codex (TUI)          │
│                        │                        │
│   1. Implements code   │   4. Receives request  │
│   2. Commits           │   5. Reviews the diff  │
│   3. Waits for review  │   6. Sends review back │
│                        │                        │
│   7. Reads review      │   8. Waits for next    │
│   8. Fixes if needed   │      review request    │
│   9. Commits again...  │                        │
│                        ├────────────────────────┤
│                        │   agentmsg status      │
│                        │   (live monitor)       │
└────────────────────────┴────────────────────────┘
```

Both agents run in their normal interactive TUI mode. They communicate by
calling `agentmsg` shell commands from within their sessions. A git
post-commit hook automatically notifies the reviewer after each commit. The
`launch` command sets up everything and injects the first prompt into Codex
so the review loop starts immediately.

## Quick Start

```bash
# 1. Install
cd ~/agentmsg
./install.sh

# 2. Launch (does everything: init, hooks, templates, tmux, agent bootstrap)
agentmsg launch ~/my-project
```

That's it. Give Claude a task in its pane. Watch the review cycle happen live.

## What `launch` Does

1. Creates `/tmp/agentmsg/` directory structure
2. Installs git hooks in the project (`post-commit`, `pre-push`)
3. Copies `CLAUDE.md` and `codex-instructions.md` into the project
4. Creates a 3-pane tmux session (Claude, Codex, monitor)
5. Labels the panes so agents can address each other by name
6. Sets `AGENTMSG_IDENTITY` env var in each pane
7. Starts both agents in TUI mode
8. **Injects the first prompt into Codex's pane** so it begins the review loop

## Manual Setup

If you prefer not to use `launch`:

**Terminal 1 — Claude Code:**
```bash
cd ~/my-project
export AGENTMSG_IDENTITY=claude
claude
```
Claude Code reads `CLAUDE.md` automatically.

**Terminal 2 — Codex:**
```bash
cd ~/my-project
export AGENTMSG_IDENTITY=codex
codex
```
Give Codex: "Follow codex-instructions.md. Start by running
`agentmsg wait --timeout 3600 --type review_request`"

**Terminal 3 — Monitor (optional):**
```bash
watch -n2 agentmsg status
```

## Command Reference

### Messaging

| Command | Description |
|---------|-------------|
| `agentmsg init [path]` | Create message dirs + install git hooks |
| `agentmsg send <to> <body> [opts]` | Send a message (atomic write) |
| `agentmsg wait [--timeout N] [--type T]` | Block until message arrives |
| `agentmsg list` | Show pending messages |
| `agentmsg read <id>` | Read + acknowledge a message |
| `agentmsg history [N]` | Show log entries |
| `agentmsg status` | Show message counts |
| `agentmsg install-hook <path>` | Install hooks into a repo |

### Pane Control

| Command | Description |
|---------|-------------|
| `agentmsg pane-list` | List all tmux panes with labels, processes, sizes |
| `agentmsg pane-read <target> [lines]` | Capture last N lines from a pane (default: 50) |
| `agentmsg pane-type <target> <text>` | Type text into a pane (no Enter) |
| `agentmsg pane-keys <target> <key>...` | Send keys: Enter, Escape, C-c, etc. |
| `agentmsg pane-name <target> <label>` | Label a pane for easy addressing |
| `agentmsg pane-exec <target> <cmd>` | Type command + press Enter |

### Session

| Command | Description |
|---------|-------------|
| `agentmsg launch [project-path]` | Create tmux session with both agents + monitor |

### Pane Targets

Targets can be:
- A **label**: `codex`, `claude` (set via `pane-name`)
- A **tmux pane ID**: `%0`, `%3`
- A **tmux address**: `agents:0.1`
- A **window index**: `0`, `1`

### Send Options

| Flag | Description |
|------|-------------|
| `--type <type>` | `review_request`, `review_response`, `fix_request`, `fix_complete`, `info`, `ack` |
| `--subject <text>` | Subject line (defaults to body) |
| `--reply-to <id>` | ID of message being replied to |
| `--meta-sha <sha>` | Commit SHA |
| `--meta-files <json>` | Changed files as JSON array |
| `--meta-stat <text>` | Diff stat text |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENTMSG_IDENTITY` | *(required)* | Agent name: `claude`, `codex`, etc. |
| `AGENTMSG_DIR` | `/tmp/agentmsg` | Root directory for message files |
| `AGENTMSG_POLL_INTERVAL` | `2` | Seconds between polls in `wait` |
| `AGENTMSG_STALE_SECONDS` | `3600` | Auto-archive messages older than this |
| `AGENTMSG_CLAUDE_CMD` | `claude` | Command to start Claude Code |
| `AGENTMSG_CODEX_CMD` | `codex` | Command to start Codex |

## Message Format

```json
{
  "id": "003-1711700000-claude",
  "timestamp": "2026-03-29T14:30:00Z",
  "from": "claude",
  "to": "codex",
  "type": "review_request",
  "subject": "a1b2c3d feat: implement user auth module",
  "body": "Committed: a1b2c3d feat: implement user auth ...",
  "metadata": {
    "commit_sha": "a1b2c3d",
    "files_changed": ["src/auth.py", "src/models.py"],
    "diff_stat": "2 files changed, 145 insertions(+)"
  },
  "reply_to": null,
  "status": "pending"
}
```

## Repo Structure

```
agentmsg/
├── bin/
│   └── agentmsg              # CLI: messaging + pane control + launch (~700 lines)
├── hooks/
│   ├── post-commit            # Auto-sends review_request on commit
│   └── pre-push               # Blocks push if unread reviews pending
├── templates/
│   ├── CLAUDE.md              # Project instructions for Claude Code
│   └── codex-instructions.md  # Project instructions for Codex
├── install.sh                 # Install agentmsg to PATH
├── setup-project.sh           # Bootstrap a project (without launching)
├── launch-agents.sh           # Thin wrapper around agentmsg launch
└── README.md
```

## Runtime File Layout

```
/tmp/agentmsg/
├── inbox/
│   ├── claude/     # messages waiting for Claude
│   └── codex/      # messages waiting for Codex
├── archive/        # read/acknowledged messages
├── lock/           # lockfiles for atomic sends
└── agentmsg.log    # append-only event log
```

## Debugging

```bash
# See all panes
agentmsg pane-list

# Read what Codex is doing
agentmsg pane-read codex 50

# See all messages on disk
find /tmp/agentmsg -name '*.json' -exec jq -r \
    '"[\(.id)] \(.from)->\(.to) \(.type): \(.subject)"' {} \;

# Tail the log
tail -f /tmp/agentmsg/agentmsg.log

# Reset everything
rm -rf /tmp/agentmsg && agentmsg init .
```

## Dependencies

- `bash` (4.0+)
- `jq`
- `tmux` (3.2+ recommended)
- `inotify-tools` (optional, for faster message detection)

## Credits

Pane control concepts inspired by [smux](https://github.com/ShawnPana/smux/).

## License

MIT
