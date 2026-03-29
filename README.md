# agentmsg

A filesystem-based messaging system that lets Claude Code and Codex (or any two
CLI agents) exchange structured messages with blocking wait semantics.

## Quick Start

```bash
# Install
./install.sh                  # installs to /usr/local/bin
# or: ./install.sh ~/.local/bin  # install without sudo

# Dependencies
sudo apt-get install jq                  # required
sudo apt-get install inotify-tools       # optional, faster detection

# Initialize in your project
cd ~/my-project
agentmsg init .    # creates /tmp/agentmsg/ + installs git hooks
```

## Tmux Session Setup

```bash
# Create a 3-pane tmux session
tmux new-session -d -s agents -c ~/my-project

# Pane 0: Claude Code (left)
# Pane 1: Codex (top-right)
tmux split-window -h -t agents -c ~/my-project
# Pane 2: Monitor (bottom-right)
tmux split-window -v -t agents:0.1 -c ~/my-project

# Set identities in each pane
tmux send-keys -t agents:0.0 'export AGENTMSG_IDENTITY=claude' Enter
tmux send-keys -t agents:0.1 'export AGENTMSG_IDENTITY=codex'  Enter
tmux send-keys -t agents:0.2 'watch -n2 agentmsg status'       Enter

tmux attach -t agents
```

```
┌────────────────────────┬────────────────────────┐
│                        │                        │
│   Pane 0: Claude       │   Pane 1: Codex        │
│                        │                        │
│ export AGENTMSG_       │ export AGENTMSG_       │
│   IDENTITY=claude      │   IDENTITY=codex       │
│                        ├────────────────────────┤
│                        │   Pane 2: Monitor      │
│                        │ watch agentmsg status  │
└────────────────────────┴────────────────────────┘
```

## Usage Patterns

### Pattern A: Automatic (Git Hook Driven)

Claude commits code. The post-commit hook auto-sends a `review_request` to
Codex. Codex is blocking on `agentmsg wait`.

**Pane 0 — Claude's workflow:**

```bash
export AGENTMSG_IDENTITY=claude

# Claude writes code (however you invoke it)
claude "Implement JWT auth in src/auth.py"

# Claude committed, hook fires automatically.
# Now wait for Codex's review before proceeding:
REVIEW=$(agentmsg wait --timeout 600 --type review_response)
echo "$REVIEW" | jq -r '.body'

# Feed the review back to Claude if fixes are needed:
ISSUES=$(echo "$REVIEW" | jq -r '.body')
if echo "$ISSUES" | grep -qi "fix\|bug\|issue\|error"; then
    claude "Fix these review issues: $ISSUES"
fi
```

**Pane 1 — Codex's workflow:**

```bash
export AGENTMSG_IDENTITY=codex

while true; do
    # Block until a review request arrives
    MSG=$(agentmsg wait --timeout 3600 --type review_request)
    [ $? -ne 0 ] && continue

    SHA=$(echo "$MSG" | jq -r '.metadata.commit_sha')
    BODY=$(echo "$MSG" | jq -r '.body')
    MSG_ID=$(echo "$MSG" | jq -r '.id')

    # Get the diff
    DIFF=$(git diff "${SHA}~1".."${SHA}" 2>/dev/null || git show "$SHA")

    # Run Codex review
    REVIEW=$(codex "Review this code change. Be specific about issues.

${BODY}

Diff:
${DIFF}" 2>&1)

    # Send review back to Claude
    agentmsg send claude "$REVIEW" \
        --type review_response \
        --subject "Review of ${SHA}" \
        --reply-to "$MSG_ID"
done
```

### Pattern B: Explicit Messaging

Agents send messages directly without relying on git hooks.

```bash
# Claude sends a specific request
agentmsg send codex "I refactored the DB layer in src/db/. \
Check the connection pooling logic for race conditions." \
    --type review_request

# Claude blocks waiting for reply
REPLY=$(agentmsg wait --timeout 600)
echo "$REPLY" | jq -r '.body'
```

```bash
# Codex receives and responds
MSG=$(agentmsg wait --timeout 600)
# ... do the review ...
agentmsg send claude "Found 2 issues: ..." --type review_response \
    --reply-to "$(echo "$MSG" | jq -r '.id')"
```

### Pattern C: Full Automated Loop

```bash
#!/bin/bash
export AGENTMSG_IDENTITY=orchestrator
TASKS=(
    "Implement user registration with email validation"
    "Add rate limiting middleware"
    "Write unit tests for auth module"
)

for task in "${TASKS[@]}"; do
    echo "=== Task: $task ==="

    # Tell Claude to implement
    tmux send-keys -t agents:0.0 "claude \"$task\"" Enter

    # Wait for Codex's review (it auto-triggers via hook)
    export AGENTMSG_IDENTITY=claude
    REVIEW=$(agentmsg wait --timeout 900 --type review_response)
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        echo "Review received:"
        echo "$REVIEW" | jq -r '.body' | head -20
    else
        echo "Review timed out, moving on"
    fi
    echo ""
done
```

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
  "subject": "feat: implement user auth module",
  "body": "Committed auth module in src/auth.py. Please review.",
  "metadata": {
    "commit_sha": "a1b2c3d",
    "files_changed": ["src/auth.py", "src/models.py"],
    "diff_stat": "2 files changed, 145 insertions(+)"
  },
  "reply_to": null,
  "status": "pending"
}
```

## Runtime File Layout

```
/tmp/agentmsg/
├── inbox/
│   ├── claude/          # messages waiting for Claude
│   └── codex/           # messages waiting for Codex
├── archive/             # read/acknowledged messages
│   ├── claude/
│   └── codex/
├── lock/                # lockfiles for atomic sends
└── agentmsg.log         # append-only event log
```

## Debugging

```bash
# See all messages on disk
find /tmp/agentmsg -name '*.json' -exec jq -r \
    '"[\(.id)] \(.from)->\(.to) \(.type): \(.subject)"' {} \;

# Tail the log
tail -f /tmp/agentmsg/agentmsg.log

# Manually inspect a message
cat /tmp/agentmsg/inbox/codex/*.json | jq .

# Reset everything
rm -rf /tmp/agentmsg && agentmsg init .
```

## License

MIT
