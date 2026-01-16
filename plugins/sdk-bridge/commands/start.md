---
description: "✅ RECOMMENDED: Interactive setup & auto-launch (one command)"
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
PLUGIN_VERSION="2.2.2"
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
echo "2.2.2" > "$HOME/.claude/skills/long-running-agent/harness/.version"

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
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Missing feature_list.json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "SDK Bridge requires a feature_list.json file to work."
    echo ""
    echo "Create this file with your features, for example:"
    echo ""
    cat << 'EXAMPLE'
[
  {
    "id": "feature-1",
    "description": "Add user authentication",
    "passes": false
  },
  {
    "id": "feature-2",
    "description": "Create API endpoints",
    "passes": false
  }
]
EXAMPLE
    echo ""
    echo "Then run /sdk-bridge:start again."
    echo ""
    exit 1
  fi

  # Check venv and SDK (should exist after Phase 0)
  VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
  if ! "$VENV_PYTHON" -c "import claude_agent_sdk" 2>/dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ SDK Installation Failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Could not import claude_agent_sdk."
    echo ""
    echo "Troubleshooting:"
    echo "  • Check installation log: cat .claude/setup.log"
    echo "  • Verify Python 3.8+ installed: python3 --version"
    echo "  • Try manual installation: /sdk-bridge:lra-setup"
    echo ""
    exit 1
  fi

  # Check git (warning only)
  if ! command -v git &> /dev/null; then
    echo "⚠️  git not found (recommended for version control)"
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

## Phase 2: Stage 1 Configuration - Essential Settings

Check execution plan availability and SDK status:

```bash
HAS_PLAN="false"
if [ -f ".claude/execution-plan.json" ]; then
  HAS_PLAN="true"
fi

# Check if SDK already running
if [ -f ".claude/sdk-bridge.pid" ]; then
  PID=$(cat ".claude/sdk-bridge.pid")
  if ps -p "$PID" > /dev/null 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  SDK Bridge Already Running"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Process ID: $PID"
    echo ""
    echo "Options:"
    echo "  • /sdk-bridge:status - Check current progress"
    echo "  • /sdk-bridge:watch - Monitor live progress"
    echo "  • /sdk-bridge:cancel - Stop current run and start fresh"
    echo ""
    exit 0
  else
    # Stale PID file, clean it up
    echo "🧹 Cleaned up stale PID file, continuing..."
    rm -f .claude/sdk-bridge.pid
  fi
fi

echo "SDK_READY:HAS_PLAN=$HAS_PLAN"
```

**Use the AskUserQuestion tool** for Stage 1 (Essential Configuration):

Build 3-4 questions dynamically based on HAS_PLAN:

**Question 1 (always shown):**
```
question: "Which Claude model should the agent use?"
header: "Model"
multiSelect: false
options:
  - label: "Sonnet (Recommended)"
    description: "Fast and capable - handles most development tasks efficiently. Best cost/performance ratio for autonomous work."
  - label: "Opus"
    description: "Most capable - use for complex refactoring, architecture changes, or when Sonnet struggles with previous attempts."
```

**Question 2 (always shown - NEW):**
```
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

**Question 3 (only if HAS_PLAN=true):**
```
question: "Enable parallel execution for faster completion?"
header: "Execution"
multiSelect: false
options:
  - label: "Parallel (Recommended)"
    description: "2-4x faster - launches multiple workers for independent features. Uses git-isolated branches with automatic merge coordination."
  - label: "Sequential"
    description: "One feature at a time - safer for tightly coupled features, first-time testing, or when features have hidden dependencies."
```

**Question 4 (always shown):**
```
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

## Phase 2.5: Gate - Advanced Settings Prompt

After Stage 1 answers collected, validate and parse:

```bash
# Check if user cancelled (AskUserQuestion returns empty on cancel/timeout)
if [ -z "$MODEL_ANSWER" ] || [ -z "$SESSIONS_ANSWER" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⏹️  Setup Cancelled"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Run /sdk-bridge:start again when ready to configure."
  echo ""
  exit 0
fi

# Parse Stage 1 answers
MODEL="claude-sonnet-4-5-20250929"
if [[ "$MODEL_ANSWER" == *"Opus"* ]]; then
  MODEL="claude-opus-4-5-20251101"
fi

# Parse max sessions
MAX_SESSIONS=20
if [[ "$SESSIONS_ANSWER" == *"10"* ]]; then
  MAX_SESSIONS=10
elif [[ "$SESSIONS_ANSWER" == *"30"* ]]; then
  MAX_SESSIONS=30
elif [[ "$SESSIONS_ANSWER" == *"50"* ]]; then
  MAX_SESSIONS=50
fi

# Parse execution mode
ENABLE_PARALLEL="false"
if [[ "$EXECUTION_ANSWER" == *"Parallel"* ]]; then
  # Validate plan exists
  if [ ! -f ".claude/execution-plan.json" ]; then
    echo ""
    echo "⚠️  Parallel mode requires execution plan. Falling back to sequential."
    echo "To enable parallel: /sdk-bridge:plan then /sdk-bridge:start"
    echo ""
    ENABLE_PARALLEL="false"
  else
    ENABLE_PARALLEL="true"
  fi
fi

# Parse advanced features
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

# Show summary before gate
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

**Use AskUserQuestion for gate:**
```
question: "Configure advanced settings (parallel workers, logging, webhooks)?"
header: "Advanced"
multiSelect: false
options:
  - label: "Use defaults (Recommended)"
    description: "Start immediately with smart defaults - auto-tuned workers, INFO logging, no webhooks."
  - label: "Customize settings"
    description: "Fine-tune parallel workers, log verbosity, and webhook notifications before starting."
```

## Phase 2.75: Stage 2 Configuration - Advanced Settings (Optional)

**Only execute if user selected "Customize settings"**

```bash
SHOW_ADVANCED="false"
if [[ "$GATE_ANSWER" == *"Customize"* ]]; then
  SHOW_ADVANCED="true"
fi
```

**If SHOW_ADVANCED=true, use AskUserQuestion for Stage 2:**

**Question 1:**
```
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

**Question 2:**
```
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

**Question 3:**
```
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

**Parse Stage 2 answers:**
```bash
# Default values (if Stage 2 skipped or cancelled)
MAX_WORKERS=3
LOG_LEVEL="INFO"
WEBHOOK_URL=""

# If Stage 2 shown, parse answers (fall back to defaults if cancelled)
if [ "$SHOW_ADVANCED" = "true" ]; then
  # Check if user cancelled Stage 2 (fall back to defaults)
  if [ -z "$WORKERS_ANSWER" ]; then
    echo ""
    echo "⚠️  Advanced configuration cancelled, using defaults..."
    echo ""
  else
  # Parse workers
  if [[ "$WORKERS_ANSWER" == *"2"* ]]; then
    MAX_WORKERS=2
  elif [[ "$WORKERS_ANSWER" == *"5"* ]]; then
    MAX_WORKERS=5
  elif [[ "$WORKERS_ANSWER" == *"8"* ]]; then
    MAX_WORKERS=8
  fi

  # Parse log level
  if [[ "$LOG_ANSWER" == *"DEBUG"* ]]; then
    LOG_LEVEL="DEBUG"
  elif [[ "$LOG_ANSWER" == *"WARNING"* ]]; then
    LOG_LEVEL="WARNING"
  fi

  # Parse webhook
  if [[ "$WEBHOOK_ANSWER" == *"Slack"* ]] || \
     [[ "$WEBHOOK_ANSWER" == *"Discord"* ]] || \
     [[ "$WEBHOOK_ANSWER" == *"Custom"* ]]; then
    echo ""
    echo "Enter your webhook URL (or press Enter to skip):"
    read -r WEBHOOK_URL

    # Validate HTTPS
    if [[ -n "$WEBHOOK_URL" ]] && [[ ! "$WEBHOOK_URL" =~ ^https:// ]]; then
      echo "⚠️  Invalid URL format (must start with https://), skipping webhook"
      WEBHOOK_URL=""
    elif [[ -n "$WEBHOOK_URL" ]]; then
      echo "✅ Webhook configured"
    fi
  fi
  fi  # Close the "else" block from cancellation check
fi  # Close the SHOW_ADVANCED check
```

## Phase 2.9: Config File Existence Check

Check if config already exists and handle appropriately:

```bash
if [ -f ".claude/sdk-bridge.local.md" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  Configuration Already Exists"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Found existing configuration at .claude/sdk-bridge.local.md"
  echo ""
  echo "What would you like to do?"
  echo "  1. Overwrite with new configuration (creates backup)"
  echo "  2. Keep existing and skip configuration"
  echo "  3. Cancel setup"
  echo ""
  read -p "Your choice (1/2/3): " CONFIG_CHOICE

  case "$CONFIG_CHOICE" in
    1)
      echo ""
      echo "Creating backup..."
      TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
      cp .claude/sdk-bridge.local.md ".claude/sdk-bridge.local.md.${TIMESTAMP}.bak"
      echo "✅ Backup saved: .claude/sdk-bridge.local.md.${TIMESTAMP}.bak"
      echo ""
      OVERWRITE_CONFIG="true"
      ;;
    2)
      echo ""
      echo "Using existing configuration. Proceeding to launch..."
      echo ""
      SKIP_CONFIG="true"
      ;;
    3|*)
      echo ""
      echo "Setup cancelled."
      echo ""
      exit 0
      ;;
  esac
fi
```

## Phase 3: Create Configuration (Silent)

**Only if SKIP_CONFIG != "true"**

All values already parsed in Phase 2 and 2.75. Create config file:

```bash
if [ "$SKIP_CONFIG" != "true" ]; then
  # Calculate derived values
RESERVE_SESSIONS=2
PROGRESS_STALL_THRESHOLD=3
MAX_INNER_LOOPS=5
AUTO_HANDOFF="false"
ENABLE_V2="true"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Human-readable values for documentation
EXECUTION_MODE="Sequential"
if [ "$ENABLE_PARALLEL" = "true" ]; then
  EXECUTION_MODE="Parallel ($MAX_WORKERS workers)"
fi

WEBHOOK_STATUS="Disabled"
if [ -n "$WEBHOOK_URL" ]; then
  WEBHOOK_STATUS="Enabled"
fi

# Create configuration file (silent)
cat > .claude/sdk-bridge.local.md << EOF
---
# SDK Bridge Configuration
enabled: true
model: $MODEL
max_sessions: $MAX_SESSIONS
reserve_sessions: $RESERVE_SESSIONS
progress_stall_threshold: $PROGRESS_STALL_THRESHOLD
auto_handoff_after_plan: $AUTO_HANDOFF
log_level: $LOG_LEVEL
webhook_url: $WEBHOOK_URL

# v2.0 Advanced Features
enable_v2_features: $ENABLE_V2
enable_semantic_memory: $ENABLE_MEMORY
enable_adaptive_models: $ENABLE_ADAPTIVE
enable_approval_nodes: $ENABLE_APPROVAL
max_inner_loops: $MAX_INNER_LOOPS

# v2.0 Phase 3: Parallel Execution
enable_parallel_execution: $ENABLE_PARALLEL
max_parallel_workers: $MAX_WORKERS
---

# SDK Bridge Configuration

Created by /sdk-bridge:start on $TIMESTAMP

## Essential Settings

- **Model**: $MODEL
- **Max Sessions**: $MAX_SESSIONS
- **Execution Mode**: $EXECUTION_MODE

## Advanced Features

- **Semantic Memory**: $ENABLE_MEMORY
- **Adaptive Models**: $ENABLE_ADAPTIVE
- **Approval Workflow**: $ENABLE_APPROVAL

## Advanced Settings

- **Parallel Workers**: $MAX_WORKERS (only applies in parallel mode)
- **Log Level**: $LOG_LEVEL
- **Webhook URL**: $WEBHOOK_STATUS

## Notes

This configuration was created via the interactive setup UI. You can manually edit this file
to fine-tune settings. See CLAUDE.md for detailed configuration documentation.

To reconfigure, run: /sdk-bridge:start
EOF

# Validate file created
  if [ ! -f ".claude/sdk-bridge.local.md" ] || [ ! -s ".claude/sdk-bridge.local.md" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Failed to Create Configuration File"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Could not write to .claude/sdk-bridge.local.md"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check directory permissions: ls -la .claude/"
    echo "  • Verify disk space: df -h ."
    echo "  • Try creating manually: touch .claude/sdk-bridge.local.md"
    echo ""
    exit 1
  fi

  echo "CONFIG_CREATED"
fi
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
  "version": "2.2.2",
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
