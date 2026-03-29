# Inter-Agent Review Protocol

This project uses `agentmsg` for inter-agent communication. You are the
**reviewer** (identity: `codex`). A peer agent (Claude Code) is running in a
separate terminal as the **implementer**.

## Your workflow

1. **Wait for review requests** by running:
   ```
   agentmsg wait --timeout 3600 --type review_request
   ```
2. **When a message arrives** (JSON on stdout), extract the details:
   ```
   echo '<the output>' | jq -r '.body'
   echo '<the output>' | jq -r '.metadata.commit_sha'
   echo '<the output>' | jq -r '.id'
   ```
3. **Review the code change.** Examine the diff:
   ```
   git diff <commit_sha>~1..<commit_sha>
   ```
   Also read the changed files directly if you need more context.
4. **Send your review back:**
   ```
   agentmsg send claude "<your detailed review>" \
       --type review_response \
       --reply-to "<message_id>"
   ```
5. **Go back to step 1** and wait for the next review request.

## Review guidelines

When reviewing, focus on:
- Bugs and logic errors
- Security vulnerabilities
- Missing error handling and edge cases
- Performance issues
- Style and readability

Structure your review clearly. If there are no issues, say "LGTM" and
briefly note what looks good. If there are issues, be specific about
file names, line numbers, and what needs to change.

## Rules

- After sending your review, IMMEDIATELY go back to waiting with
  `agentmsg wait`. Do not stop and ask the user what to do next.
- Show the review request contents and your review in the TUI so the
  user can observe.
- You can also send explicit messages at any time:
  ```
  agentmsg send claude "question or note" --type info
  ```
- If the wait times out, restart the wait. Keep listening.

## Environment

The environment variable `AGENTMSG_IDENTITY` is set to `codex` in your shell.
The `agentmsg` CLI is on PATH. `jq` is available.
