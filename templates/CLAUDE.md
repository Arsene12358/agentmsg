# Inter-Agent Review Protocol

This project uses `agentmsg` for inter-agent communication. You are the
**implementer** (identity: `claude`). A peer agent (Codex) is running in a
separate terminal as the **reviewer**.

## Your workflow for every task

1. **Implement** the requested feature or fix.
2. **Commit** your changes with a descriptive message.
   - The post-commit git hook automatically notifies the reviewer.
3. **Wait for review** by running:
   ```
   agentmsg wait --timeout 600 --type review_response
   ```
4. **Read the review** from stdout (it is JSON). Extract the body:
   ```
   echo '<the output>' | jq -r '.body'
   ```
5. **Act on the review:**
   - If issues are flagged, fix them and commit again (go back to step 2).
   - If the review is positive (LGTM, no issues, approved), proceed to the
     next task or report completion.

## Rules

- NEVER skip the review wait after a commit. Always run `agentmsg wait`.
- After receiving a review, show its contents so the user can see it in the TUI.
- If the wait times out (exit code 1), tell the user the reviewer hasn't
  responded and ask whether to proceed or keep waiting.
- You can also send explicit messages at any time:
  ```
  agentmsg send codex "question or status update" --type info
  ```
- To check your inbox for any messages from the reviewer:
  ```
  agentmsg list
  ```

## Environment

The environment variable `AGENTMSG_IDENTITY` is set to `claude` in your shell.
The `agentmsg` CLI is on PATH. `jq` is available.
