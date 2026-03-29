# agentmsg

A filesystem-based messaging system that lets two AI coding agents running in
interactive TUI mode (Claude Code + Codex) communicate with each other via
structured messages. Watch them review each other's code in real-time across
tmux panes.

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
post-commit hook automatically notifies the reviewer after each commit.
You observe everything live in the TUI.

## Quick Start

```bash
# 1. Install agentmsg
cd ~/agentmsg
./install.sh

# 2. Set up your project
./setup-project.sh ~/my-project

# 3. Launch the dual-agent tmux session
./launch-agents.sh ~/my-project
```

That's it. In Claude's pane, give it a task. It will implement, commit, and
wait for review. In Codex's pane, tell it to follow `codex-instructions.md`
and start the review loop.

## Manual Setup

If you prefer to set things up yourself instead of using the launcher:

**Terminal 1 — Claude Code:**
```bash
cd ~/my-project
export AGENTMSG_IDENTITY=claude
claude
```
Claude Code automatically reads `CLAUDE.md` from the project root, which
contains the review protocol instructions.

**Terminal 2 — Codex:**
```bash
cd ~/my-project
export AGENTMSG_IDENTITY=codex
codex
```
Give Codex this opening prompt:
> Follow the instructions in codex-instructions.md. Start by running
> `agentmsg wait --timeout 3600 --type review_request` and review
> whatever comes in.

**Terminal 3 — Monitor (optional):**
```bash
watch -n2 agentmsg status
```

## What You'll See

In **Claude's TUI**, you'll see it:
1. Write code and commit
2. Run `agentmsg wait --timeout 600 --type review_response`
3. Receive the review JSON and display the feedback
4. Fix issues if needed and commit again

In **Codex's TUI**, you'll see it:
1. Run `agentmsg wait --timeout 3600 --type review_request`
2. Receive the commit notification
3. Run `git diff` to examine changes
4. Write a review and send it with `agentmsg send claude "..." --type review_response`
5. Go back to waiting

In the **Monitor pane**, you'll see message counts update in real-time.

## Project Files

`setup-project.sh` creates these files in your project:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions Claude Code reads automatically — tells it to use the review protocol |
| `codex-instructions.md` | Instructions you give Codex — tells it to run the review-wait loop |

Both files are templates you can customize. The key instructions are:
- Claude: commit, then run `agentmsg wait`, then act on review
- Codex: run `agentmsg wait`, review the diff, send response, repeat

## Command Reference

| Command | Description |
|---------|-------------|
| `agentmsg init [path]` | Create message dirs + install git hooks |
| `agentmsg send <to> <body> [opts]` | Send a message (atomic write) |
| `agentmsg wait [--timeout N]` | Block until message arrives (exit 0) or timeout (exit 1) |
| `agentmsg wait --type T` | Wait for specific message type only |
| `agentmsg list` | Show pending messages in your inbox |
| `agentmsg read <id>` | Read + acknowledge a specific message |
| `agentmsg history [N]` | Show last N log entries |
| `agentmsg status` | Show pending/archived counts for all agents |
| `agentmsg install-hook <path>` | Install hooks into an existing repo |

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
| `AGENTMSG_DIR` | `/tmp/agentmsg` | Root directory for all message files |
| `AGENTMSG_POLL_INTERVAL` | `2` | Seconds between polls in `wait` |
| `AGENTMSG_STALE_SECONDS` | `3600` | Auto-archive messages older than this |

## Message Format

Each message is a JSON file written atomically (write `.tmp`, then `mv`):

```json
{
  "id": "003-1711700000-claude",
  "timestamp": "2026-03-29T14:30:00Z",
  "from": "claude",
  "to": "codex",
  "type": "review_request",
  "subject": "a1b2c3d feat: implement user auth module",
  "body": "Committed: a1b2c3d feat: implement user auth module\n...",
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
│   └── agentmsg              # CLI tool (bash, ~500 lines)
├── hooks/
│   ├── post-commit            # Auto-sends review_request on commit
│   └── pre-push               # Blocks push if unread reviews pending
├── templates/
│   ├── CLAUDE.md              # Project instructions for Claude Code
│   └── codex-instructions.md  # Project instructions for Codex
├── install.sh                 # Install agentmsg to PATH
├── setup-project.sh           # Bootstrap a project for dual-agent workflow
├── launch-agents.sh           # Launch tmux session with both agents
└── README.md
```

## Runtime File Layout

```
/tmp/agentmsg/
├── inbox/
│   ├── claude/     # messages waiting for Claude
│   └── codex/      # messages waiting for Codex
├── archive/        # read/acknowledged messages
│   ├── claude/
│   └── codex/
├── lock/           # lockfiles for atomic sends
└── agentmsg.log    # append-only event log
```

## Debugging

```bash
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
- `inotify-tools` (optional, for faster message detection)
- `tmux` (for the launcher)

## License

MIT
