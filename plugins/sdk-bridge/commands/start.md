---
description: "Start autonomous development (auto-installs if needed)"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion", "TodoWrite", "Task"]
---

# Start SDK Bridge - One Command Setup

I'll set up and launch SDK Bridge with automatic installation and a clean interactive experience.

## Phase 0: Silent Setup Detection

First, let me check if SDK Bridge is installed and up to date:

```bash
# Check installation status silently
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
VERSION_FILE="$HARNESS_DIR/.version"
PLUGIN_VERSION="2.0.0"
NEEDS_INSTALL="false"
NEEDS_UPDATE="false"

# Check if harness exists
if [ ! -d "$HARNESS_DIR" ] || [ ! -f "$HARNESS_DIR/hybrid_loop_agent.py" ]; then
  NEEDS_INSTALL="true"
  echo "SETUP_REQUIRED"
elif [ -f "$VERSION_FILE" ]; then
  INSTALLED_VERSION=$(cat "$VERSION_FILE")
  if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ]; then
    NEEDS_UPDATE="true"
    echo "UPDATE_AVAILABLE"
  else
    echo "UP_TO_DATE"
  fi
else
  # Version file missing - assume needs update
  NEEDS_UPDATE="true"
  echo "UPDATE_AVAILABLE"
fi
```

## Phase 0.5: Auto-Install/Update (Silent Background)

If setup is required, use TodoWrite to show clean progress and install silently:

**If SETUP_REQUIRED or UPDATE_AVAILABLE**, create initial progress tracker:

```
Use TodoWrite to create:
- ⏳ Installing SDK Bridge harness
- ⏳ Setting up Python environment
- ⏳ Validating installation
- ⏳ Checking project prerequisites
- ⏳ Configuring setup options
- ⏳ Creating configuration
- ⏳ Launching autonomous agent
```

Then run silent installation:

```bash
#!/bin/bash
set -euo pipefail

SETUP_LOG=".claude/setup.log"
mkdir -p .claude

# Redirect all output to log file (silent for user)
exec 1>>"$SETUP_LOG" 2>&1

echo "[$(date)] Starting SDK Bridge installation..."

# === STEP 1: Create Directories ===
mkdir -p "$HOME/.claude/skills/long-running-agent/harness"

# === STEP 2: Install Harness Scripts ===
SCRIPTS=(
  "autonomous_agent.py"
  "hybrid_loop_agent.py"
  "semantic_memory.py"
  "model_selector.py"
  "approval_system.py"
  "dependency_graph.py"
  "parallel_coordinator.py"
)

for script in "${SCRIPTS[@]}"; do
  src="${CLAUDE_PLUGIN_ROOT}/scripts/$script"
  dst="$HOME/.claude/skills/long-running-agent/harness/$script"

  if [ -f "$src" ]; then
    cp "$src" "$dst"
    chmod +x "$dst"
  fi
done

# === STEP 3: Create Virtual Environment ===
VENV_DIR="$HOME/.claude/skills/long-running-agent/.venv"

if [ ! -d "$VENV_DIR" ]; then
  if command -v uv &> /dev/null; then
    uv venv "$VENV_DIR"
  else
    python3 -m venv "$VENV_DIR"
  fi
fi

# === STEP 4: Install SDK ===
. "$VENV_DIR/bin/activate"

if command -v uv &> /dev/null; then
  uv pip install --quiet claude-agent-sdk
else
  pip install --quiet claude-agent-sdk
fi

deactivate

# === STEP 5: Write Version File ===
echo "2.0.0" > "$HOME/.claude/skills/long-running-agent/harness/.version"

# === STEP 6: Validate Installation ===
VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
SDK_VERSION=$("$VENV_PYTHON" -c "import claude_agent_sdk; print(claude_agent_sdk.__version__)" 2>&1)

echo "[$(date)] Installation complete. SDK version: $SDK_VERSION"

# Signal success
echo "INSTALL_SUCCESS"
```

After installation completes, update TodoWrite:

```
- ✅ SDK Bridge harness installed
- ✅ Python environment ready
- ✅ Installation validated
- ⏳ Checking project prerequisites
- ⏳ Configuring setup options
- ⏳ Creating configuration
- ⏳ Launching autonomous agent
```

**If UP_TO_DATE**, skip to Phase 1 with initial progress tracker:

```
Use TodoWrite to create:
- ⏳ Checking prerequisites
- ⏳ Configuring setup options
- ⏳ Creating configuration
- ⏳ Launching autonomous agent
```

## Phase 1: Project Prerequisites Check

Check project-specific requirements (silent checks, only show final status):

```bash
# All checks silent, only output final status
{
  mkdir -p .claude

  # Check feature list
  if [ ! -f "feature_list.json" ]; then
    echo "ERROR: No feature_list.json found. Create it with /plan or manually."
    exit 1
  fi

  # Check venv and SDK (should exist after Phase 0)
  VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
  if ! "$VENV_PYTHON" -c "import claude_agent_sdk" 2>/dev/null; then
    echo "ERROR: SDK installation failed. Check .claude/setup.log"
    exit 1
  fi

  # Check git (warning only)
  if ! command -v git &> /dev/null; then
    echo "WARNING: git not found (recommended for version control)"
  fi

  echo "PREREQ_OK"
} 2>/dev/null
```

Update TodoWrite:

```
- ✅ Prerequisites validated
- ⏳ Configuring setup options
- ⏳ Creating configuration
- ⏳ Launching autonomous agent
```

## Phase 2: Interactive Configuration (Clean UI)

Check execution plan availability (silent):

```bash
HAS_PLAN="false"
if [ -f ".claude/execution-plan.json" ]; then
  HAS_PLAN="true"
fi
echo "$HAS_PLAN"
```

**Use the AskUserQuestion tool** to present interactive configuration:

Build questions dynamically based on HAS_PLAN:

**Question 1 (always shown):**
```
question: "Which Claude model should the agent use?"
header: "Model"
multiSelect: false
options:
  - label: "Sonnet (Recommended)"
    description: "Fast and capable - handles most development tasks efficiently. Best cost/performance ratio."
  - label: "Opus"
    description: "Most capable - use for complex refactoring, architecture changes, or when Sonnet struggles."
```

**Question 2 (only if HAS_PLAN=true):**
```
question: "Enable parallel execution for faster completion?"
header: "Execution"
multiSelect: false
options:
  - label: "Parallel (Recommended)"
    description: "2-4x faster - launches multiple workers for independent features. Uses git-isolated branches."
  - label: "Sequential"
    description: "One feature at a time - safer for tightly coupled features or first-time testing."
```

**Question 3 (always shown):**
```
question: "Which advanced features should be enabled?"
header: "Features"
multiSelect: true
options:
  - label: "Semantic Memory (Recommended)"
    description: "Cross-project learning - suggests solutions from past successful implementations."
  - label: "Adaptive Models (Recommended)"
    description: "Smart routing - escalates complex features to Opus automatically."
  - label: "Approval Workflow (Recommended)"
    description: "Human-in-the-loop - pauses for high-risk operations like DB migrations."
```

## Phase 3: Create Configuration (Silent)

Parse user answers and create config file:

```bash
# Parse model selection
MODEL="claude-sonnet-4-5-20250929"
if [[ "$MODEL_ANSWER" == *"Opus"* ]]; then
  MODEL="claude-opus-4-5-20251101"
fi

# Parse execution mode
ENABLE_PARALLEL="false"
if [[ "$EXECUTION_ANSWER" == *"Parallel"* ]]; then
  ENABLE_PARALLEL="true"
fi

# Parse advanced features (default all enabled)
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

# Create configuration file (silent)
cat > .claude/sdk-bridge.local.md << 'EOF'
---
# SDK Bridge Configuration
enabled: true
model: MODEL_PLACEHOLDER
max_sessions: 20
reserve_sessions: 2
progress_stall_threshold: 3
auto_handoff_after_plan: false
log_level: INFO
webhook_url:

# v2.0 Advanced Features
enable_v2_features: true
enable_semantic_memory: MEMORY_PLACEHOLDER
enable_adaptive_models: ADAPTIVE_PLACEHOLDER
enable_approval_nodes: APPROVAL_PLACEHOLDER
max_inner_loops: 5

# v2.0 Phase 3: Parallel Execution
enable_parallel_execution: PARALLEL_PLACEHOLDER
max_parallel_workers: 3
---

# SDK Bridge Configuration

Created by /sdk-bridge:start on TIMESTAMP_PLACEHOLDER

## Settings

- **Model**: MODEL_PLACEHOLDER
- **Parallel Execution**: PARALLEL_PLACEHOLDER
- **Semantic Memory**: MEMORY_PLACEHOLDER
- **Adaptive Models**: ADAPTIVE_PLACEHOLDER
- **Approval Workflow**: APPROVAL_PLACEHOLDER

See CLAUDE.md for detailed configuration documentation.
EOF

# Replace placeholders
sed -i.bak "s|MODEL_PLACEHOLDER|$MODEL|g" .claude/sdk-bridge.local.md
sed -i.bak "s|MEMORY_PLACEHOLDER|$ENABLE_MEMORY|g" .claude/sdk-bridge.local.md
sed -i.bak "s|ADAPTIVE_PLACEHOLDER|$ENABLE_ADAPTIVE|g" .claude/sdk-bridge.local.md
sed -i.bak "s|APPROVAL_PLACEHOLDER|$ENABLE_APPROVAL|g" .claude/sdk-bridge.local.md
sed -i.bak "s|PARALLEL_PLACEHOLDER|$ENABLE_PARALLEL|g" .claude/sdk-bridge.local.md
sed -i.bak "s|TIMESTAMP_PLACEHOLDER|$(date +"%Y-%m-%d %H:%M:%S")|g" .claude/sdk-bridge.local.md
rm -f .claude/sdk-bridge.local.md.bak

echo "CONFIG_CREATED"
```

Update TodoWrite:

```
- ✅ Prerequisites validated
- ✅ Setup options configured
- ✅ Configuration created
- ⏳ Launching autonomous agent
```

## Phase 4: Launch Agent (Background Process)

Read configuration and launch harness:

```bash
#!/bin/bash
set -euo pipefail

PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
PROJECT_DIR="."
LOG_FILE=".claude/sdk-bridge.log"
PID_FILE=".claude/sdk-bridge.pid"

# Read configuration
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' .claude/sdk-bridge.local.md)
MODEL=$(echo "$FRONTMATTER" | grep '^model:' | sed 's/model: *//')
MAX_SESSIONS=$(echo "$FRONTMATTER" | grep '^max_sessions:' | sed 's/max_sessions: *//' || echo "20")
RESERVE_SESSIONS=$(echo "$FRONTMATTER" | grep '^reserve_sessions:' | sed 's/reserve_sessions: *//' || echo "2")
MAX_INNER=$(echo "$FRONTMATTER" | grep '^max_inner_loops:' | sed 's/max_inner_loops: *//' || echo "5")
LOG_LEVEL=$(echo "$FRONTMATTER" | grep '^log_level:' | sed 's/log_level: *//' || echo "INFO")
ENABLE_MEMORY=$(echo "$FRONTMATTER" | grep '^enable_semantic_memory:' | sed 's/enable_semantic_memory: *//' || echo "true")
ENABLE_PARALLEL=$(echo "$FRONTMATTER" | grep '^enable_parallel_execution:' | sed 's/enable_parallel_execution: *//' || echo "false")
MAX_WORKERS=$(echo "$FRONTMATTER" | grep '^max_parallel_workers:' | sed 's/max_parallel_workers: *//' || echo "3")

MAX_ITERATIONS=$((MAX_SESSIONS - RESERVE_SESSIONS))

# Determine execution mode
EXECUTION_MODE="sequential"
HARNESS="$HOME/.claude/skills/long-running-agent/harness/hybrid_loop_agent.py"

if [ "$ENABLE_PARALLEL" = "true" ] && [ -f ".claude/execution-plan.json" ]; then
  EXECUTION_MODE="parallel"
  HARNESS="$HOME/.claude/skills/long-running-agent/harness/parallel_coordinator.py"
fi

# Create handoff context (silent)
cat > .claude/handoff-context.json << EOF
{
  "version": "2.0.0",
  "handoff_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "mode": "$EXECUTION_MODE",
  "model": "$MODEL",
  "max_sessions": $MAX_SESSIONS,
  "features": {
    "semantic_memory": $ENABLE_MEMORY,
    "adaptive_models": $(echo "$FRONTMATTER" | grep '^enable_adaptive_models:' | sed 's/enable_adaptive_models: *//'),
    "parallel_execution": $ENABLE_PARALLEL
  },
  "session_count": 0,
  "status": "running"
}
EOF

# Build launch command
if [ "$EXECUTION_MODE" = "parallel" ]; then
  CMD="$PYTHON $HARNESS \
    --project-dir $PROJECT_DIR \
    --model $MODEL \
    --max-workers $MAX_WORKERS \
    --max-sessions $MAX_SESSIONS \
    --execution-plan .claude/execution-plan.json \
    --log-level $LOG_LEVEL"

  if [ "$ENABLE_MEMORY" = "false" ]; then
    CMD="$CMD --disable-semantic-memory"
  fi
else
  CMD="$PYTHON $HARNESS \
    --project-dir $PROJECT_DIR \
    --model $MODEL \
    --max-iterations $MAX_ITERATIONS \
    --max-inner-loops $MAX_INNER \
    --log-level $LOG_LEVEL"

  if [ "$ENABLE_MEMORY" = "false" ]; then
    CMD="$CMD --disable-semantic-memory"
  fi
fi

# Launch in background (silent)
nohup $CMD > "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

# Verify process started
sleep 2
if ! ps -p $PID > /dev/null 2>&1; then
  echo "ERROR: Failed to launch. Check $LOG_FILE"
  exit 1
fi

# Count features
FEATURE_COUNT=$(jq 'length' feature_list.json 2>/dev/null || echo "0")

# Estimate time
if [ "$EXECUTION_MODE" = "parallel" ]; then
  ESTIMATED_MIN=$((FEATURE_COUNT * 15 / MAX_WORKERS))
else
  ESTIMATED_MIN=$((FEATURE_COUNT * 15))
fi

# Output structured status for display
cat << EOF
LAUNCH_SUCCESS
PID=$PID
MODE=$EXECUTION_MODE
WORKERS=$MAX_WORKERS
MODEL=$MODEL
FEATURES=$FEATURE_COUNT
ESTIMATED_MIN=$ESTIMATED_MIN
LOG=$LOG_FILE
EOF
```

## Phase 5: Final Status Display

Update TodoWrite to completion:

```
- ✅ Prerequisites validated
- ✅ Setup options configured
- ✅ Configuration created
- ✅ Agent launched successfully
```

Display clean success message:

```
Parse the launch output and display:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 SDK Bridge Running!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configuration:
  Mode: [sequential/parallel]
  [If parallel: Workers: 3, Speedup: ~3x]
  Model: [model name]
  Features: [count]

Status:
  PID: [pid]
  Estimated time: ~[X] minutes

Monitor Progress:
  • Live updates: /sdk-bridge:watch
  • Check status: /sdk-bridge:status
  • View logs: tail -f .claude/sdk-bridge.log
  • Cancel: /sdk-bridge:cancel

I'll notify you when complete! ✨
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Error Handling

If any phase fails:

1. **Setup fails**: Show "Installation failed. Check .claude/setup.log"
2. **Prerequisites fail**: Show specific missing item (feature_list.json, SDK, etc.)
3. **Launch fails**: Show "Failed to start. Check .claude/sdk-bridge.log"

Always maintain clean UI - technical errors go to log files, user sees actionable messages.
