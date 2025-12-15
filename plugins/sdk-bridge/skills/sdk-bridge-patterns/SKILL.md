---
name: SDK Bridge Patterns
description: |
  Use when user wants to "hand off to SDK", "run autonomous agent", "bridge CLI and SDK", "long-running tasks", "autonomous development", or mentions SDK bridge workflows. Provides comprehensive patterns for hybrid CLI/SDK development with the Claude Agent SDK.
version: 1.0.0
---

# SDK Bridge Patterns

Bridge Claude Code CLI and Agent SDK for seamless hybrid workflows. Hand off long-running tasks to autonomous agents, monitor progress, and resume in CLI when complete.

## Quick Reference

**Commands**:
- `/sdk-bridge:init` - Initialize project for SDK bridge
- `/sdk-bridge:handoff` - Hand off work to autonomous SDK agent
- `/sdk-bridge:status` - Monitor progress
- `/sdk-bridge:resume` - Resume in CLI after completion
- `/sdk-bridge:cancel` - Stop running SDK agent

**Workflow**: Plan → Init → Handoff → Monitor → Resume

## When to Use SDK Bridge

✅ **Use SDK Bridge when:**
- Task has 10+ well-defined features to implement
- You want autonomous progress while away
- Task benefits from multi-session iteration
- You've created a plan and want unattended execution
- Features are testable and have clear completion criteria

❌ **Don't use for:**
- Exploratory work (stay in CLI for interactivity)
- Tasks requiring frequent user input or decisions
- Simple single-feature changes
- When you need to iterate on prompts or approaches

## Core Workflow Pattern

### Phase 1: Plan in CLI (Interactive)

Work interactively to create a comprehensive plan:

```bash
# Create plan with feature list
/plan

# Review generated feature_list.json
cat feature_list.json | jq '.[] | {description, test}'

# Refine if needed
# Edit feature_list.json to clarify vague features
# Ensure each feature has clear test criteria

# Commit the plan
git add feature_list.json CLAUDE.md
git commit -m "Initial project plan"
```

**Best practices**:
- Make features specific and testable
- Order features by dependency
- Include test criteria in each feature
- 15-50 features is ideal (too few: not worth automation, too many: risk of drift)

### Phase 2: Initialize SDK Bridge

```bash
/sdk-bridge:init
```

This creates `.claude/sdk-bridge.local.md` with configuration:
- Model selection (Sonnet vs Opus)
- Session limits
- Progress stall threshold
- Auto-handoff settings

**Review and customize** the configuration for your project needs.

### Phase 3: Handoff to SDK (Autonomous)

```bash
/sdk-bridge:handoff
```

What happens:
1. **Validation**: Handoff-validator agent checks:
   - `feature_list.json` exists with failing features
   - Git repository initialized
   - Harness and SDK installed
   - No conflicting SDK processes
   - API authentication configured

2. **Launch**: If validation passes:
   - Harness starts in background with `nohup`
   - PID saved to `.claude/sdk-bridge.pid`
   - Output logged to `.claude/sdk-bridge.log`
   - Tracking created in `.claude/handoff-context.json`

3. **Autonomous Work**: SDK agent:
   - Reads `feature_list.json` and `claude-progress.txt`
   - Implements ONE feature per session
   - Tests implementation
   - Updates `passes: true` in `feature_list.json`
   - Logs progress to `claude-progress.txt`
   - Commits to git
   - Repeats until complete or limit reached

**You can close the CLI** - the SDK agent runs independently.

### Phase 4: Monitor (Optional)

```bash
/sdk-bridge:status
```

Shows:
- SDK agent process status (running/stopped)
- Feature completion progress (e.g., "28/50 passing")
- Session count (e.g., "8/20 sessions used")
- Recent log activity

**Monitoring options**:
- Periodic checks: `/sdk-bridge:status`
- Live logs: `tail -f .claude/sdk-bridge.log`
- Git commits: `git log --oneline`
- Feature progress: `jq '.[] | select(.passes==true) | .description' feature_list.json`

### Phase 5: Resume in CLI (Interactive)

```bash
/sdk-bridge:resume
```

What happens:
1. **Completion check**: Verifies `.claude/sdk_complete.json` exists
2. **Analysis**: Completion-reviewer agent:
   - Parses completion signal (reason, sessions used)
   - Analyzes feature progress
   - Reviews git commits
   - Runs tests and checks build
   - Identifies next features
   - Detects issues in logs

3. **Report**: Presents comprehensive summary:
   - What was completed
   - Test/build status
   - Remaining work
   - Issues found
   - Recommended next steps

4. **Continue**: You're back in interactive CLI mode
   - Can continue manually
   - Can fix issues
   - Can hand off again

## File Structure

During SDK bridge workflows, these files coordinate state:

```
project/
├── feature_list.json          # Source of truth for features (SDK reads/writes)
├── claude-progress.txt        # Session-to-session memory (SDK writes)
├── CLAUDE.md                  # Session protocol (SDK reads)
├── init.sh                    # Environment bootstrap (SDK executes)
├── .git/                      # Version control (SDK commits)
└── .claude/
    ├── sdk-bridge.local.md    # Configuration (plugin reads)
    ├── handoff-context.json   # Handoff tracking (plugin writes)
    ├── sdk-bridge.log         # SDK output (harness writes)
    ├── sdk-bridge.pid         # Process ID (plugin writes)
    └── sdk_complete.json      # Completion signal (harness/plugin writes)
```

## Configuration

Edit `.claude/sdk-bridge.local.md` to customize:

```markdown
---
enabled: true
model: claude-sonnet-4-5-20250929  # or claude-opus-4-5-20251101
max_sessions: 20
reserve_sessions: 2
progress_stall_threshold: 3
auto_handoff_after_plan: false
---

# SDK Bridge Configuration

[Your project-specific notes]
```

### Configuration Options

**`model`**: Which Claude model SDK uses
- `claude-sonnet-4-5-20250929` (default) - Fast, capable, cost-effective
- `claude-opus-4-5-20251101` - Most capable, slower, more expensive
- Use Sonnet for standard features, Opus for complex/creative work

**`max_sessions`**: Total sessions before stopping (default: 20)
- 1 session = 1 complete feature implementation attempt
- Recommend: 15-30 for small projects, 30-50 for large projects
- SDK stops at `max_sessions - reserve_sessions`

**`reserve_sessions`**: Keep N for manual intervention (default: 2)
- Reserved for wrap-up or recovery
- SDK stops early to leave these available

**`progress_stall_threshold`**: Stop if no progress for N sessions (default: 3)
- Prevents wasted sessions on blocked features
- If same feature fails 3 times in a row → stop

**`auto_handoff_after_plan`**: Auto-launch after /plan (default: false)
- `true`: Immediately hand off after plan creation
- `false`: Manual handoff with `/sdk-bridge:handoff`

## Common Patterns

### Pattern 1: Standard Long-Running Development

```bash
# Day 1: Planning
/plan
# Create 40 features for a new web app

/sdk-bridge:init
/sdk-bridge:handoff
# Close laptop, go home

# Day 2: Check progress
/sdk-bridge:status
# 32/40 features passing, 12 sessions used

# Day 3: SDK completes
/sdk-bridge:resume
# Review: 38/40 done, 2 features need clarification
# Fix issues manually, continue development
```

### Pattern 2: Iterative Refinement

```bash
# Round 1: Bulk implementation
/sdk-bridge:handoff
# ... SDK completes 30/50 features ...
/sdk-bridge:resume

# Review quality, fix issues
# Improve implementations, add tests
git commit -m "Refine SDK implementations"

# Round 2: Continue remaining features
/sdk-bridge:handoff
# ... SDK completes remaining 20 ...
/sdk-bridge:resume
```

### Pattern 3: Feature Batching

```bash
# Implement core features first
jq '.[0:20]' all-features.json > feature_list.json
git add feature_list.json && git commit -m "Phase 1 features"

/sdk-bridge:handoff
# ... SDK completes 20 features ...
/sdk-bridge:resume

# Add next batch
jq '.[20:40]' all-features.json > feature_list.json
git add feature_list.json && git commit -m "Phase 2 features"

/sdk-bridge:handoff
# ... continue ...
```

### Pattern 4: Emergency Cancel and Recovery

```bash
# SDK heading wrong direction
/sdk-bridge:status
# Only 3/50 passing after 10 sessions - something's wrong

/sdk-bridge:cancel

# Review what happened
git log --oneline -10
tail -100 .claude/sdk-bridge.log
cat claude-progress.txt

# Identify issue: Feature #1 was too vague
vim feature_list.json
# Clarify feature descriptions, add better test criteria

git commit -m "Clarify feature requirements"

# Try again with better guidance
/sdk-bridge:handoff
```

### Pattern 5: Auto-Handoff

```markdown
# .claude/sdk-bridge.local.md
---
auto_handoff_after_plan: true
---
```

```bash
/plan
# Automatically hands off immediately
# Check progress later with /sdk-bridge:status
```

## Best Practices

### 1. Write Clear, Testable Features

**Good**:
```json
{
  "description": "User can register with email and password",
  "passes": false,
  "test": "POST /api/register with valid data returns 201 and JWT token"
}
```

**Bad**:
```json
{
  "description": "Authentication",
  "passes": false,
  "test": "it works"
}
```

### 2. Order Features by Dependency

Put foundational features first:
1. Database schema
2. Core models
3. API endpoints
4. Business logic
5. UI components
6. Edge cases
7. Polish

### 3. Use Progressive Complexity

Start simple, add complexity:
- Feature 1: "Basic user model with email/password"
- Feature 10: "Password reset flow with email"
- Feature 20: "OAuth integration with Google"

### 4. Monitor Periodically

Check status every few hours:
```bash
/sdk-bridge:status

# If progress seems slow
tail -50 .claude/sdk-bridge.log

# If stuck on one feature
grep "Feature #N" claude-progress.txt
```

### 5. Commit Often (Manually)

Before handoff, commit your plan:
```bash
git add .
git commit -m "Initial plan with 40 features"
```

After resume, review and commit:
```bash
git log --oneline -20  # Review SDK commits
# If satisfied
git commit -m "SDK completed features 1-38"
# If not
git reset --hard HEAD~5  # Revert last 5 commits
```

### 6. Reserve Sessions Wisely

If SDK uses 18/20 sessions and stops:
- 2 sessions reserved for you to:
  - Manually complete hard features
  - Fix issues SDK couldn't resolve
  - Wrap up and test

### 7. Use Stall Detection

If SDK attempts same feature 3+ times:
- Feature description likely too vague
- Feature may be blocked on external dependency
- Edit `feature_list.json` to clarify or skip

### 8. Test Before Large Handoffs

Try with a small test:
```bash
# Create 5-feature test plan
echo '[...]' > feature_list.json

/sdk-bridge:handoff
# Wait 15 minutes
/sdk-bridge:status
# If working well, scale up to full plan
```

## Troubleshooting

### SDK Won't Start

```bash
# Check logs
cat .claude/sdk-bridge.log

# Common issues:
# 1. API key not set
echo $ANTHROPIC_API_KEY  # Should not be empty
# Or use OAuth: claude setup-token

# 2. SDK not installed
python3 -c "import claude_agent_sdk"

# 3. Harness missing
ls ~/.claude/skills/long-running-agent/harness/autonomous_agent.py
# If missing: /user:lra-setup

# 4. Git not initialized
git status
# If not a repo: git init
```

### Progress Stalled

```bash
/sdk-bridge:status
# Sessions: 10/20, Features: 3/50 (only 3 done in 10 sessions!)

# Check what's failing
tail -100 .claude/sdk-bridge.log
cat claude-progress.txt | tail -50

# Common causes:
# - Feature too vague
# - Tests failing repeatedly
# - External dependency missing

# Fix:
/sdk-bridge:cancel
vim feature_list.json  # Clarify or skip stuck feature
git commit -m "Clarify feature requirements"
/sdk-bridge:handoff
```

### Tests Failing After Resume

```bash
/sdk-bridge:resume
# Shows: "❌ Tests failing"

# Check which tests
npm test  # or pytest

# Common issues:
# - SDK implemented feature but tests need update
# - Edge cases not covered
# - Environment differences (API keys, DB)

# Fix:
# Update tests or implementation
git add .
git commit -m "Fix edge cases found by tests"
```

### Completion Not Detected

```bash
# SDK stopped but no completion signal
ps aux | grep autonomous_agent  # Not running

# Check logs for errors
tail -100 .claude/sdk-bridge.log

# Manually check progress
jq '.[] | select(.passes==false) | .description' feature_list.json

# If work complete, manually resume
cat > .claude/sdk_complete.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "reason": "manual_completion",
  "session_count": 15
}
EOF

/sdk-bridge:resume
```

### High API Costs

```bash
# Use Sonnet instead of Opus
# Edit .claude/sdk-bridge.local.md:
model: claude-sonnet-4-5-20250929

# Reduce max sessions
max_sessions: 15  # Instead of 30

# Better features = fewer retries
# Make feature descriptions clearer
```

## Advanced Patterns

### Custom Completion Signals

SDK can signal early completion:

```json
{
  "timestamp": "2025-12-15T10:30:00Z",
  "reason": "blocked_on_external_dependency",
  "session_count": 8,
  "exit_code": 2,
  "message": "Need Stripe API keys before continuing",
  "blocking_features": [23, 24, 25]
}
```

This allows graceful handback when SDK encounters blockers.

### Project-Specific Protocols

Create `.claude/CLAUDE.md` with project-specific guidance:

```markdown
# Project Protocol

## Code Standards
- Use TypeScript strict mode
- All functions must have JSDoc comments
- Tests required for all public APIs

## Testing
- Run `npm test` after each feature
- Feature passes only if all tests pass
- Add tests before implementation

## Git
- Commit after each passing feature
- Use conventional commit format
- Never force push
```

The SDK reads this before each session.

### Multi-Agent Workflows

Use different models for different work:

```bash
# Use Opus for complex features
model: claude-opus-4-5-20251101
/sdk-bridge:handoff
# ... completes complex features ...
/sdk-bridge:resume

# Switch to Sonnet for simple features
# Edit .claude/sdk-bridge.local.md:
model: claude-sonnet-4-5-20250929
/sdk-bridge:handoff
# ... completes remaining simple features ...
```

## Resources

**Examples**:
- `examples/workflow-example.md` - Complete end-to-end workflow
- `examples/handoff-scenarios.md` - Common handoff patterns

**References**:
- `references/state-files.md` - State file formats and meanings
- `references/configuration.md` - Complete configuration reference

**Scripts**:
- `scripts/launch-harness.sh` - Harness subprocess management
- `scripts/monitor-progress.sh` - Progress tracking
- `scripts/parse-state.sh` - State file parsing

## Integration with Long-Running Agent Skill

SDK Bridge wraps the existing long-running-agent harness:

**Relationship**:
- **Harness**: `~/.claude/skills/long-running-agent/harness/autonomous_agent.py`
- **SDK Bridge**: CLI-friendly plugin wrapper

**Direct harness use**:
```bash
python ~/.claude/skills/long-running-agent/harness/autonomous_agent.py \
    --project-dir . \
    --spec ./requirements.txt
```

**SDK Bridge use**:
```bash
/sdk-bridge:handoff  # Wraps the above
```

**Coexistence**:
- Both approaches work
- SDK Bridge adds: validation, monitoring, resume, hooks
- Direct harness gives: full control, custom arguments

Choose SDK Bridge for ease of use, direct harness for advanced control.

---

For detailed examples and references, see the `examples/` and `references/` directories in this skill.
