---
description: "Hand off current work to SDK agent for autonomous execution"
argument-hint: ""
---

# Hand Off to SDK Agent

I'll hand off your work to an autonomous SDK agent that will work on implementing features from your feature_list.json.

## Pre-Handoff Validation

First, let me use the **handoff-validator** agent to check that everything is ready for handoff.

Use the Task tool to invoke the handoff-validator agent. The agent will check:
- feature_list.json exists with remaining work
- Git repository is initialized
- Harness and SDK are installed
- No conflicting SDK processes running
- API authentication configured

If the validator finds any issues, it will STOP the handoff and tell you how to fix them.

If validation passes, proceed to launch the SDK agent.

## Launch SDK Agent

After validation passes, launch the harness:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-harness.sh .
```

This script will:
1. Read configuration from `.claude/sdk-bridge.local.md`
2. Launch `autonomous_agent.py` in background with `nohup`
3. Save process ID to `.claude/sdk-bridge.pid`
4. Redirect output to `.claude/sdk-bridge.log`
5. Create `.claude/handoff-context.json` tracking file

## Post-Handoff Instructions

After the SDK agent launches successfully, inform the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Handoff Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The SDK agent is now working autonomously on your project.

What happens now:
  • SDK agent works through features in feature_list.json
  • One feature implemented per session
  • Commits after each successful feature
  • Logs progress to claude-progress.txt
  • Stops when all features pass or max sessions reached

You can:
  • Close this CLI - the agent continues running
  • Monitor anytime: /sdk-bridge:status
  • View live logs: tail -f .claude/sdk-bridge.log
  • Cancel if needed: /sdk-bridge:cancel
  • Resume when done: /sdk-bridge:resume

The SDK agent will work until:
  ✓ All features in feature_list.json pass, or
  ✓ Max sessions limit reached, or
  ✓ Progress stalls (no completion for 3+ sessions), or
  ✓ You cancel it with /sdk-bridge:cancel

When the agent completes, it will create .claude/sdk_complete.json
and you can review its work with /sdk-bridge:resume.
```

## Important Notes

- **Do NOT invoke the handoff-validator agent yourself** - use the Task tool to launch it as a subagent
- **Wait for validation to complete** before proceeding to launch
- **If validation fails**, stop immediately and show the user the error message
- **The CLI can close** after handoff - the SDK agent runs independently
- **Only launch once** - the script checks for existing processes
