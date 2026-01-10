---
description: "Handoff to SDK Bridge v2.0 with hybrid loops and semantic memory"
argument-hint: "[project-dir]"
allowed-tools: ["Bash", "Read", "Write", "Task", "TodoWrite", "AskUserQuestion"]
---

# SDK Bridge v2.0 Handoff Command

This command hands off feature implementation to the SDK Bridge v2.0 autonomous agent with:
- **Hybrid Loops**: Same-session self-healing + multi-session progression
- **Semantic Memory**: Cross-project learning from past implementations
- **Adaptive Intelligence**: Smart retry strategies and model selection

## Prerequisites Check

Before handoff, run the handoff validator to ensure all prerequisites are met:

```bash
# Use Task tool to invoke handoff-validator agent
```

Invoke the `handoff-validator` agent using the Task tool with `subagent_type: sdk-bridge-expert` or directly if available.

The validator will check:
1. ✅ SDK virtual environment exists and claude-agent-sdk is installed
2. ✅ Project has `feature_list.json`
3. ✅ API authentication is configured (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY)
4. ✅ Git repository is clean or has only intended changes
5. ✅ Configuration file exists (`.claude/sdk-bridge.local.md`)
6. ✅ v2.0 features are enabled
7. ✅ Semantic memory is accessible

## Configuration

Ensure `.claude/sdk-bridge.local.md` has v2.0 settings:

```yaml
---
# v1.4.0 settings
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 20
reserve_sessions: 2
progress_stall_threshold: 3
log_level: INFO
webhook_url: https://example.com/webhook  # optional

# v2.0 settings
enable_v2_features: true
enable_semantic_memory: true
max_inner_loops: 5  # Same-session retries (Ralph pattern)
---
```

If v2 settings are missing, ask the user if they want to enable v2 features.

## Handoff Process

### Step 1: Validate Prerequisites

Use Bash tool to run the validator (or invoke as agent):

```bash
# Run pre-handoff validation
python3 ~/.claude/skills/long-running-agent/harness/validate_prerequisites.py
```

If validation fails, stop and report errors to user.

### Step 2: Create Handoff Context

Create `.claude/handoff-context.json` with v2 metadata:

```json
{
  "version": "2.0.0",
  "handoff_time": "<current ISO timestamp>",
  "mode": "hybrid_loops",
  "features": {
    "semantic_memory": true,
    "adaptive_retry": true,
    "parallel_execution": false  // Phase 2
  },
  "session_count": 0,
  "status": "running"
}
```

### Step 3: Launch Hybrid Loop Agent

Use Bash tool to launch the v2 agent in background:

```bash
HARNESS="$HOME/.claude/skills/long-running-agent/harness/hybrid_loop_agent.py"
PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
PROJECT_DIR="${1:-.}"
LOG_FILE=".claude/sdk-bridge.log"
PID_FILE=".claude/sdk-bridge.pid"

# Read configuration
if [ -f ".claude/sdk-bridge.local.md" ]; then
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' .claude/sdk-bridge.local.md)
  MODEL=$(echo "$FRONTMATTER" | grep '^model:' | sed 's/model: *//')
  MAX_SESSIONS=$(echo "$FRONTMATTER" | grep '^max_sessions:' | sed 's/max_sessions: *//')
  MAX_INNER=$(echo "$FRONTMATTER" | grep '^max_inner_loops:' | sed 's/max_inner_loops: *//')
  LOG_LEVEL=$(echo "$FRONTMATTER" | grep '^log_level:' | sed 's/log_level: *//')
  ENABLE_MEMORY=$(echo "$FRONTMATTER" | grep '^enable_semantic_memory:' | sed 's/enable_semantic_memory: *//')
fi

# Apply defaults
MODEL="${MODEL:-claude-sonnet-4-5-20250929}"
MAX_SESSIONS="${MAX_SESSIONS:-20}"
MAX_INNER="${MAX_INNER:-5}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
ENABLE_MEMORY="${ENABLE_MEMORY:-true}"

# Build command
CMD="$PYTHON $HARNESS --project-dir $PROJECT_DIR --model $MODEL --max-iterations $MAX_SESSIONS --max-inner-loops $MAX_INNER --log-level $LOG_LEVEL"

if [ "$ENABLE_MEMORY" = "false" ]; then
  CMD="$CMD --disable-semantic-memory"
fi

# Launch in background
nohup $CMD > "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

echo "✅ SDK Bridge v2.0 launched (PID: $PID)"
echo "📝 Logs: $LOG_FILE"
echo ""
echo "Monitor progress:"
echo "  tail -f $LOG_FILE"
echo ""
echo "Check status:"
echo "  /sdk-bridge:status"
```

### Step 4: Confirm Handoff

Display success message to user:

```
🚀 Handoff to SDK Bridge v2.0 Complete!

✨ New in v2.0:
  • Hybrid Loops: Same-session self-healing + multi-session progression
  • Semantic Memory: Learning from past implementations
  • Adaptive Intelligence: Smart retry strategies

📊 Configuration:
  Model: <model-name>
  Max Sessions: <max-sessions>
  Inner Loops: <max-inner-loops> (per session)
  Semantic Memory: Enabled

📝 Monitor:
  tail -f .claude/sdk-bridge.log

🔍 Check Status:
  /sdk-bridge:status

⏸  Cancel:
  /sdk-bridge:cancel

The SDK agent is now running autonomously in the background.
You can close this terminal - the agent will continue working.
```

## Error Handling

If any step fails:
1. Log error details to `.claude/sdk-bridge.log`
2. Report to user with specific failure reason
3. Suggest remediation steps
4. Do NOT launch the agent if prerequisites fail

## Notes

- Backward compatible: Falls back to v1.4.0 if `enable_v2_features: false`
- Semantic memory is opt-in via configuration
- Logs everything for transparency
- User can monitor in real-time with `tail -f`

## Implementation

Execute the steps above using appropriate tools:
- **Bash**: For running scripts and launching agent
- **Read**: For reading configuration files
- **Write**: For creating handoff context
- **AskUserQuestion**: If configuration is incomplete or v2 features need enabling
