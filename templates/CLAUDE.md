# Inter-Agent Communication Protocol

This project uses `agentmsg` for inter-agent communication. You are the
**implementer** (identity: `claude`). A peer agent (Codex) is running in a
separate tmux pane as the **reviewer**.

## Your workflow for every task

1. **Implement** the requested feature or fix.
2. **Commit** your changes with a descriptive message.
3. **Send a review request to Codex.** Don't wait for the hook — tell Codex
   directly what you did and ask for review:
   ```bash
   SHA=$(git rev-parse --short HEAD)
   STAT=$(git diff --stat HEAD~1 HEAD 2>/dev/null || echo "initial commit")
   FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')

   agentmsg send codex \
       "I finished implementing <describe what you did>. Commit $SHA is ready for review." \
       --type review_request \
       --subject "Review: <short description>" \
       --meta-sha "$SHA" \
       --meta-stat "$STAT" \
       --meta-files "$FILES"
   ```
4. **Wait for Codex's review:**
   ```bash
   agentmsg wait --timeout 600 --type review_response
   ```
5. **Read the review** from stdout (it is JSON). Extract the body:
   ```bash
   echo '<the output>' | jq -r '.body'
   ```
6. **Act on the review:**
   - If issues are flagged, fix them, commit again, and go back to step 3.
   - If the review is positive (LGTM / approved), proceed to the next task
     or report completion to the user.

## Conversational messages

You can send any freeform message to Codex at any time — not just review
requests. Use this to discuss plans, ask questions, or coordinate:

```bash
# Ask Codex a question
agentmsg send codex "What do you think about using X pattern for the auth module?" --type info

# Tell Codex something
agentmsg send codex "I'm about to refactor the database layer, heads up" --type info

# Wait for Codex's reply
agentmsg wait --timeout 300 --type info
```

## Checking your inbox

```bash
agentmsg list                        # see all unread messages
agentmsg read <message_id>           # read a specific message
```

## Pane commands (cross-pane observation)

You can observe the reviewer's tmux pane directly:

```bash
agentmsg pane-list                    # see all panes with labels
agentmsg pane-read codex 30           # read last 30 lines from Codex's pane
agentmsg pane-exec codex "<command>"  # run a command in Codex's pane
```

Use `pane-read` to check if the reviewer is stuck or idle. Prefer structured
messages (`agentmsg send/wait`) for all protocol communication — only use
pane commands for debugging or observing status.

## Rules

- ALWAYS send a review request after committing. Don't just commit silently.
- ALWAYS wait for the review response before moving on. Never skip the wait.
- Show received reviews in the TUI so the user can observe the interaction.
- If the wait times out (exit code 1), tell the user and ask whether to
  proceed or keep waiting.

## Environment

The environment variable `AGENTMSG_IDENTITY` is set to `claude` in your shell.
The `agentmsg` CLI is on PATH. `jq` is available. You are inside a tmux pane
labeled `claude`.
