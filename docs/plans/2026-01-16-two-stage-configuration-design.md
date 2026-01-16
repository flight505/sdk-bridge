# Two-Stage Configuration UI Design

**Date:** 2026-01-16
**Version:** v2.2.0
**Status:** Approved for Implementation

## Overview

This design moves hidden configuration parameters into a two-stage generative UI for the `/sdk-bridge:start` command. The primary goal is to make `max_sessions` visible before starting (user feedback: "max_sessions is something people want to check before running") while keeping advanced parameters accessible without overwhelming beginners.

## Current State (v2.0-2.1)

**Exposed in UI (3 questions):**
- Model selection (Sonnet/Opus)
- Execution mode (Parallel/Sequential) - conditional on plan
- Advanced features (multi-select: Memory, Adaptive, Approval)

**Hidden in YAML (manual editing required):**
- `max_sessions: 20` ← **User wants this visible**
- `reserve_sessions: 2`
- `max_parallel_workers: 3`
- `progress_stall_threshold: 3`
- `max_inner_loops: 5`
- `log_level: INFO`
- `webhook_url: ""`

## Design Goals

1. ✅ Make `max_sessions` always visible (critical requirement)
2. ✅ Expose important parameters (workers, logging) without overwhelming
3. ✅ Keep advanced parameters accessible (no file editing needed)
4. ✅ Maintain simple flow for beginners (skip advanced if not needed)
5. ✅ Stay within AskUserQuestion constraints (4 questions max per call)

## Parameter Prioritization

Based on user feedback and usage patterns:

**A) Critical (must-see before starting):**
- `max_sessions` - Cost/commitment upfront visibility

**B) Important (should be configurable):**
- `max_parallel_workers` - Affects speed/resource usage
- `log_level` - Useful for debugging

**C) Advanced (rarely changed):**
- `reserve_sessions` - Derivative of max_sessions
- `progress_stall_threshold` - Good defaults work
- `max_inner_loops` - Good defaults work
- `webhook_url` - Power user feature

## Two-Stage Architecture

### Stage 1: Essential Configuration (Always shown)

**4 questions via single AskUserQuestion call:**

1. Model selection (Sonnet/Opus)
2. Max sessions budget (10/20/30/50) ← **NEW**
3. Execution mode (Parallel/Sequential) - conditional on plan
4. Advanced features (multi-select: Memory, Adaptive, Approval)

### Gate: Advanced Settings Prompt

**Simple text prompt + single yes/no question:**

```
✅ Essential Configuration Complete

Advanced settings will use recommended defaults:
  • Parallel workers: Auto-tuned based on CPU cores
  • Log level: INFO (standard verbosity)
  • Webhook notifications: Disabled

Configure advanced settings (parallel workers, logging, webhooks)?
  1. Use defaults (Recommended)
  2. Customize settings
```

### Stage 2: Advanced Configuration (Optional)

**3 questions via second AskUserQuestion call (only if user selects "Customize"):**

1. Max parallel workers (2/3/5/8)
2. Log level (INFO/DEBUG/WARNING)
3. Webhook notifications (Disabled/Slack/Discord/Custom)

If webhook selected, follow-up text prompt for URL.

## Detailed Question Design

### Stage 1: Question 1 - Model Selection

```yaml
question: "Which Claude model should the agent use?"
header: "Model"
multiSelect: false
options:
  - label: "Sonnet (Recommended)"
    description: "Fast and capable - handles most development tasks efficiently. Best cost/performance ratio for autonomous work."

  - label: "Opus"
    description: "Most capable - use for complex refactoring, architecture changes, or when Sonnet struggles with previous attempts."
```

**Answer parsing:**
```bash
MODEL="claude-sonnet-4-5-20250929"
if [[ "$MODEL_ANSWER" == *"Opus"* ]]; then
  MODEL="claude-opus-4-5-20251101"
fi
```

### Stage 1: Question 2 - Max Sessions Budget (NEW)

```yaml
question: "How many sessions should the agent have?"
header: "Sessions"
multiSelect: false
options:
  - label: "10 sessions"
    description: "Quick experiments - suitable for small features or testing SDK Bridge for the first time."

  - label: "20 sessions (Recommended)"
    description: "Typical workload - handles most feature implementations with room for retries and learning."

  - label: "30 sessions"
    description: "Complex refactors - architectural changes, multi-file refactoring, or tightly coupled features."

  - label: "50 sessions"
    description: "Major projects - large feature sets, complete system overhauls, or when thoroughness matters most."
```

**Answer parsing:**
```bash
MAX_SESSIONS=20  # default
if [[ "$SESSIONS_ANSWER" == *"10"* ]]; then
  MAX_SESSIONS=10
elif [[ "$SESSIONS_ANSWER" == *"30"* ]]; then
  MAX_SESSIONS=30
elif [[ "$SESSIONS_ANSWER" == *"50"* ]]; then
  MAX_SESSIONS=50
fi
```

**Rationale:**
- Exposes critical budget parameter (user requirement)
- Provides context for each tier (helps decision-making)
- Uses familiar "Recommended" pattern from other questions

### Stage 1: Question 3 - Execution Mode

```yaml
question: "Enable parallel execution for faster completion?"
header: "Execution"
multiSelect: false
options:
  - label: "Parallel (Recommended)"
    description: "2-4x faster - launches multiple workers for independent features. Uses git-isolated branches with automatic merge coordination."

  - label: "Sequential"
    description: "One feature at a time - safer for tightly coupled features, first-time testing, or when features have hidden dependencies."
```

**Conditional display:**
```bash
# Only show if execution-plan.json exists
if [ -f ".claude/execution-plan.json" ]; then
  # Include this question
fi
```

**Answer parsing:**
```bash
ENABLE_PARALLEL="false"
if [[ "$EXECUTION_ANSWER" == *"Parallel"* ]]; then
  ENABLE_PARALLEL="true"
fi
```

### Stage 1: Question 4 - Advanced Features

```yaml
question: "Which advanced features should be enabled?"
header: "Features"
multiSelect: true
options:
  - label: "Semantic Memory (Recommended)"
    description: "Cross-project learning - suggests proven solutions from past successful implementations in other projects."

  - label: "Adaptive Models (Recommended)"
    description: "Smart routing - automatically escalates complex features to Opus based on complexity and past failure patterns."

  - label: "Approval Workflow (Recommended)"
    description: "Human-in-the-loop - pauses execution for high-risk operations like database migrations, API changes, architectural refactors."
```

**Answer parsing:**
```bash
ENABLE_MEMORY="false"
ENABLE_ADAPTIVE="false"
ENABLE_APPROVAL="false"

if [[ "$FEATURES_ANSWER" == *"Semantic Memory"* ]]; then
  ENABLE_MEMORY="true"
fi
if [[ "$FEATURES_ANSWER" == *"Adaptive Models"* ]]; then
  ENABLE_ADAPTIVE="true"
fi
if [[ "$FEATURES_ANSWER" == *"Approval Workflow"* ]]; then
  ENABLE_APPROVAL="true"
fi
```

### Gate: Advanced Settings Prompt

**Implementation:**
```bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Essential Configuration Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Advanced settings will use recommended defaults:"
echo "  • Parallel workers: Auto-tuned based on CPU cores"
echo "  • Log level: INFO (standard verbosity)"
echo "  • Webhook notifications: Disabled"
echo ""
```

**Single question via AskUserQuestion:**
```yaml
question: "Configure advanced settings (parallel workers, logging, webhooks)?"
header: "Advanced"
multiSelect: false
options:
  - label: "Use defaults (Recommended)"
    description: "Start immediately with smart defaults - auto-tuned workers, INFO logging, no webhooks."

  - label: "Customize settings"
    description: "Fine-tune parallel workers, log verbosity, and webhook notifications before starting."
```

**Answer parsing:**
```bash
SHOW_ADVANCED="false"
if [[ "$GATE_ANSWER" == *"Customize"* ]]; then
  SHOW_ADVANCED="true"
fi
```

### Stage 2: Question 1 - Max Parallel Workers

```yaml
question: "How many parallel workers should run simultaneously?"
header: "Workers"
multiSelect: false
options:
  - label: "2 workers"
    description: "Conservative - low memory usage, good for laptops or when running other heavy processes."

  - label: "3 workers (Recommended)"
    description: "Balanced - good speed without excessive resource usage. Works well on most machines."

  - label: "5 workers"
    description: "Fast - requires more memory and CPU. Best for desktop machines with 16GB+ RAM."

  - label: "8 workers"
    description: "Maximum speed - high resource usage. Only for powerful machines with 32GB+ RAM and 8+ cores."
```

**Answer parsing:**
```bash
MAX_WORKERS=3  # default
if [[ "$WORKERS_ANSWER" == *"2"* ]]; then
  MAX_WORKERS=2
elif [[ "$WORKERS_ANSWER" == *"5"* ]]; then
  MAX_WORKERS=5
elif [[ "$WORKERS_ANSWER" == *"8"* ]]; then
  MAX_WORKERS=8
fi
```

**Note:** Only applies when `enable_parallel_execution: true`

### Stage 2: Question 2 - Log Level

```yaml
question: "What log verbosity should be used?"
header: "Logging"
multiSelect: false
options:
  - label: "INFO (Recommended)"
    description: "Standard logging - shows important events, progress updates, and errors. Good for normal use."

  - label: "DEBUG"
    description: "Verbose logging - shows detailed execution traces, API calls, and internal state. Use for troubleshooting."

  - label: "WARNING"
    description: "Minimal logging - only shows warnings and errors. Quieter output, harder to debug issues."
```

**Answer parsing:**
```bash
LOG_LEVEL="INFO"  # default
if [[ "$LOG_ANSWER" == *"DEBUG"* ]]; then
  LOG_LEVEL="DEBUG"
elif [[ "$LOG_ANSWER" == *"WARNING"* ]]; then
  LOG_LEVEL="WARNING"
fi
```

### Stage 2: Question 3 - Webhook Notifications

```yaml
question: "Enable webhook notifications?"
header: "Webhooks"
multiSelect: false
options:
  - label: "Disabled (Recommended)"
    description: "No external notifications - check progress with /sdk-bridge:status or /sdk-bridge:watch commands."

  - label: "Slack webhook"
    description: "Send completion notifications to Slack. You'll need to provide a webhook URL."

  - label: "Discord webhook"
    description: "Send completion notifications to Discord. You'll need to provide a webhook URL."

  - label: "Custom webhook"
    description: "Send notifications to a custom HTTPS endpoint. You'll need to provide a webhook URL."
```

**Answer parsing & follow-up:**
```bash
WEBHOOK_URL=""  # default
WEBHOOK_TYPE="$WEBHOOK_ANSWER"

if [[ "$WEBHOOK_ANSWER" == *"Slack"* ]] || \
   [[ "$WEBHOOK_ANSWER" == *"Discord"* ]] || \
   [[ "$WEBHOOK_ANSWER" == *"Custom"* ]]; then
  echo ""
  echo "Enter your webhook URL (or press Enter to skip):"
  read -r WEBHOOK_URL

  # Validate HTTPS requirement
  if [[ -n "$WEBHOOK_URL" ]] && [[ ! "$WEBHOOK_URL" =~ ^https:// ]]; then
    echo "⚠️  Invalid URL format (must start with https://), skipping webhook"
    WEBHOOK_URL=""
  elif [[ -n "$WEBHOOK_URL" ]]; then
    echo "✅ Webhook configured"
  fi
fi
```

## Configuration File Template

**Complete YAML frontmatter with all parameters:**

```yaml
---
# SDK Bridge Configuration
enabled: true
model: MODEL_PLACEHOLDER
max_sessions: MAX_SESSIONS_PLACEHOLDER
reserve_sessions: 2
progress_stall_threshold: 3
auto_handoff_after_plan: false
log_level: LOG_LEVEL_PLACEHOLDER
webhook_url: WEBHOOK_URL_PLACEHOLDER

# v2.0 Advanced Features
enable_v2_features: true
enable_semantic_memory: ENABLE_MEMORY_PLACEHOLDER
enable_adaptive_models: ENABLE_ADAPTIVE_PLACEHOLDER
enable_approval_nodes: ENABLE_APPROVAL_PLACEHOLDER
max_inner_loops: 5

# v2.0 Phase 3: Parallel Execution
enable_parallel_execution: ENABLE_PARALLEL_PLACEHOLDER
max_parallel_workers: MAX_WORKERS_PLACEHOLDER
---

# SDK Bridge Configuration

Created by /sdk-bridge:start on TIMESTAMP_PLACEHOLDER

## Essential Settings

- **Model**: MODEL_PLACEHOLDER
- **Max Sessions**: MAX_SESSIONS_PLACEHOLDER
- **Execution Mode**: EXECUTION_MODE_PLACEHOLDER

## Advanced Features

- **Semantic Memory**: ENABLE_MEMORY_PLACEHOLDER
- **Adaptive Models**: ENABLE_ADAPTIVE_PLACEHOLDER
- **Approval Workflow**: ENABLE_APPROVAL_PLACEHOLDER

## Advanced Settings

- **Parallel Workers**: MAX_WORKERS_PLACEHOLDER (only applies in parallel mode)
- **Log Level**: LOG_LEVEL_PLACEHOLDER
- **Webhook URL**: WEBHOOK_STATUS_PLACEHOLDER

## Notes

This configuration was created via the interactive setup UI. You can manually edit this file
to fine-tune settings. See CLAUDE.md for detailed configuration documentation.

To reconfigure, run: /sdk-bridge:start
```

## Error Handling & Edge Cases

### 1. SDK Already Running

**Detection:**
```bash
if [ -f ".claude/sdk-bridge.pid" ]; then
  PID=$(cat ".claude/sdk-bridge.pid")
  if ps -p "$PID" > /dev/null 2>&1; then
    echo "⚠️  SDK Bridge Already Running (PID: $PID)"
    echo "Use /sdk-bridge:status, /sdk-bridge:watch, or /sdk-bridge:cancel"
    exit 0
  fi
fi
```

**Action:** Block restart, show monitoring commands

### 2. Missing feature_list.json

**Detection:**
```bash
if [ ! -f "feature_list.json" ]; then
  echo "❌ Missing feature_list.json"
  # Show example format
  exit 1
fi
```

**Action:** Fail early with helpful example

### 3. Parallel Mode Without Execution Plan

**Detection:**
```bash
if [[ "$EXECUTION_ANSWER" == *"Parallel"* ]] && [ ! -f ".claude/execution-plan.json" ]; then
  echo "⚠️  Parallel requires execution plan, falling back to sequential"
  ENABLE_PARALLEL="false"
fi
```

**Action:** Automatic fallback with explanation

### 4. Harness Installation Failure

**Detection:**
```bash
if [ ! -f "$HARNESS_DIR/hybrid_loop_agent.py" ]; then
  echo "❌ Harness installation failed"
  echo "Check .claude/setup.log for details"
  exit 1
fi
```

**Action:** Fail with diagnostic steps

### 5. Invalid Webhook URL

**Validation:**
```bash
if [[ -n "$WEBHOOK_URL" ]] && [[ ! "$WEBHOOK_URL" =~ ^https:// ]]; then
  echo "⚠️  Invalid webhook URL (must be HTTPS), disabling"
  WEBHOOK_URL=""
fi
```

**Action:** Warn and disable

### 6. User Cancels AskUserQuestion

**Handling:**
```bash
# Stage 1 cancellation
if [ -z "$MODEL_ANSWER" ]; then
  echo "⏹️  Setup cancelled"
  exit 0
fi

# Stage 2 cancellation
if [ "$SHOW_ADVANCED" = "true" ] && [ -z "$WORKERS_ANSWER" ]; then
  echo "⚠️  Using default advanced settings"
  MAX_WORKERS=3
  LOG_LEVEL="INFO"
  WEBHOOK_URL=""
fi
```

**Action:**
- Stage 1: Exit cleanly
- Stage 2: Fall back to defaults

### 7. Config File Already Exists

**Detection:**
```bash
if [ -f ".claude/sdk-bridge.local.md" ]; then
  echo "⚠️  Configuration already exists"
  echo "1. Overwrite with backup"
  echo "2. Keep existing"
  echo "3. Cancel"
  read -r CONFIG_CHOICE
  # Handle choice
fi
```

**Action:** Offer overwrite/keep/cancel options

### 8. Permission Errors

**Validation:**
```bash
if [ ! -f ".claude/sdk-bridge.local.md" ] || [ ! -s ".claude/sdk-bridge.local.md" ]; then
  echo "❌ Failed to create configuration"
  echo "Check permissions and disk space"
  exit 1
fi
```

**Action:** Fail with diagnostic steps

### 9. Conflicting Feature Selections

**Detection:**
```bash
if [[ "$FEATURES_ANSWER" == *"Approval"* ]] && \
   [[ ! "$FEATURES_ANSWER" == *"Adaptive"* ]]; then
  echo "💡 Approval Workflow works best with Adaptive Models"
  echo "Continue anyway? (yes/no):"
  read -r CONTINUE
fi
```

**Action:** Warn about suboptimal combinations

### 10. Custom Text Input Handling

**Validation:**
```bash
# If user types custom text instead of selecting
if [[ ! "$SESSIONS_ANSWER" =~ [0-9]+ ]]; then
  echo "⚠️  Defaulting to 20 sessions"
  MAX_SESSIONS=20
else
  # Extract and validate number
  MAX_SESSIONS=$(echo "$SESSIONS_ANSWER" | grep -oE '[0-9]+' | head -1)
  # Clamp to 10-100 range
fi
```

**Action:** Parse, validate, clamp, or default

## Implementation Flow

```
/sdk-bridge:start invoked
    ↓
Check SDK not already running
    ↓
Check feature_list.json exists
    ↓
Auto-install harness if needed (silent)
    ↓
Detect execution-plan.json existence
    ↓
Stage 1: AskUserQuestion (3-4 questions)
  - Q1: Model
  - Q2: Max Sessions ← NEW
  - Q3: Execution (if plan exists)
  - Q4: Features
    ↓
Parse Stage 1 answers
Validate parallel fallback if no plan
    ↓
Gate: Show defaults, ask "Customize?"
    ↓
If "Use defaults":              If "Customize":
  MAX_WORKERS=3                   Stage 2: AskUserQuestion (3 questions)
  LOG_LEVEL="INFO"                  - Q1: Max Workers
  WEBHOOK_URL=""                    - Q2: Log Level
    ↓                                 - Q3: Webhooks
    |                                    ↓
    |                               If webhook selected:
    |                                 Prompt for URL
    |                                 Validate HTTPS
    |                                    ↓
    └─────────────────────────────────┘
                ↓
Check if config exists (offer overwrite/keep/cancel)
    ↓
Create/update .claude/sdk-bridge.local.md
Validate file created successfully
    ↓
TodoWrite: Show launch progress
    ↓
Detect harness (parallel vs sequential)
Launch with appropriate arguments
Save PID to .claude/sdk-bridge.pid
    ↓
Display success message with monitoring commands
```

## User Experience Flow

**Typical user (no advanced customization):**
```
1. Run: /sdk-bridge:start
2. Answer 4 questions (Model, Sessions, Execution, Features)
3. See: "✅ Configuration complete, using defaults"
4. Gate: Select "Use defaults"
5. Agent launches immediately
   Total: ~30 seconds
```

**Power user (full customization):**
```
1. Run: /sdk-bridge:start
2. Answer 4 questions (Model, Sessions, Execution, Features)
3. See: "✅ Configuration complete, configure advanced?"
4. Gate: Select "Customize settings"
5. Answer 3 more questions (Workers, Logging, Webhooks)
6. If webhook: Enter URL
7. Agent launches
   Total: ~60 seconds
```

**First-time user:**
```
1. Run: /sdk-bridge:start
2. Silent harness installation (~30 seconds)
3. Answer 4 questions with "(Recommended)" guidance
4. Gate: Select "Use defaults" (recommended)
5. Agent launches
   Total: ~60 seconds
```

## Benefits

### For Users

1. **Visibility**: Max sessions always shown (key requirement ✅)
2. **Control**: All parameters accessible via UI (no file editing)
3. **Simplicity**: Beginners can skip advanced settings (4 questions only)
4. **Flexibility**: Power users get full control (7 questions total)
5. **Guidance**: "(Recommended)" labels guide good choices

### For Developers

1. **Maintainability**: All config in one command
2. **Discoverability**: No hidden YAML parameters
3. **Validation**: Catch errors before launch
4. **Consistency**: Single source of truth for defaults
5. **Extensibility**: Easy to add new parameters in future

## Trade-offs

**Pros:**
- Max sessions always visible (solves user pain point)
- Advanced control without file editing
- Graceful degradation (defaults if Stage 2 skipped)
- Stays within AskUserQuestion limits (4 per call)
- Two-stage keeps beginners from being overwhelmed

**Cons:**
- More questions total (4-7 vs current 3-4)
- Two AskUserQuestion calls if customizing (slight latency)
- More complex implementation (two stages to maintain)
- Gate adds extra decision point (but improves UX)

**Decision:** Pros outweigh cons. User feedback indicates `max_sessions` visibility is critical, and two-stage pattern is familiar from installers/config wizards.

## Future Enhancements

**v2.3.0+ possibilities:**

1. **Auto-tune workers**: Detect CPU cores and suggest optimal worker count
2. **Session cost estimation**: Show estimated API cost based on session budget
3. **Config profiles**: Save/load named configurations (dev/production/test)
4. **Webhook testing**: "Test webhook" option to verify URL before starting
5. **Interactive defaults**: Show current/previous config values as defaults
6. **Smart recommendations**: Suggest sessions based on feature count

## Testing Plan

### Manual Testing Checklist

- [ ] Happy path: Stage 1 → defaults → launch
- [ ] Happy path: Stage 1 → Stage 2 → launch
- [ ] Cancel at Stage 1
- [ ] Cancel at Stage 2 (falls back to defaults)
- [ ] Parallel mode with execution plan
- [ ] Parallel mode without plan (fallback)
- [ ] All session tiers (10/20/30/50)
- [ ] All worker counts (2/3/5/8)
- [ ] All log levels (INFO/DEBUG/WARNING)
- [ ] Webhook: Disabled
- [ ] Webhook: Slack with valid URL
- [ ] Webhook: Invalid URL (no https)
- [ ] Config file already exists (overwrite)
- [ ] Config file already exists (keep)
- [ ] Missing feature_list.json
- [ ] SDK already running
- [ ] Harness installation failure

### Integration Testing

- [ ] Generated config file has all fields
- [ ] Agent launches with correct arguments
- [ ] Sequential mode uses correct harness
- [ ] Parallel mode uses correct harness
- [ ] PID file created
- [ ] Log file created
- [ ] TodoWrite progress updates
- [ ] Final success message shows correct values

## Success Criteria

1. ✅ Max sessions visible in Stage 1 (requirement met)
2. ✅ All parameters accessible via UI (no file editing needed)
3. ✅ Beginners can use defaults (4 questions + gate)
4. ✅ Power users get full control (7 questions total)
5. ✅ Graceful error handling (10 edge cases covered)
6. ✅ Clear user feedback at each step
7. ✅ Generated config matches user selections
8. ✅ Agent launches successfully with config

## References

- **Current implementation**: `plugins/sdk-bridge/commands/start.md` (v2.1.0)
- **AskUserQuestion docs**: Claude Agent SDK documentation
- **Configuration schema**: `skills/sdk-bridge-patterns/references/configuration.md`
- **User feedback**: "max_sessions is something people want to check before running"

---

**Status:** Ready for implementation
**Target Release:** v2.2.0
**Estimated Implementation Time:** 2-3 hours
