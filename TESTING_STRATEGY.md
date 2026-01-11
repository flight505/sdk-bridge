# SDK Bridge Plugin Testing & Validation Strategy

**Version**: 1.0.0
**Last Updated**: 2026-01-11
**Plugin Version**: 1.7.0

---

## Overview

This document defines a comprehensive testing and validation strategy for the SDK Bridge plugin to address critical issues:

1. **Installation Issues**: `lra-setup` only installs 1 of 7 Python scripts
2. **Command Confusion**: Duplicate commands (handoff/handoff-v2) causing unclear behavior
3. **File Creation Verification**: Files reported as "completed" but not actually created
4. **v2 Feature Validation**: v2.0 features non-functional due to missing installations

---

## 1. Installation Testing

### 1.1 Baseline Installation Test

**Purpose**: Verify all required Python scripts are installed to `~/.claude/skills/long-running-agent/harness/`

**Script to Install** (7 total):
1. `autonomous_agent.py` - v1.4.0 harness (CURRENTLY INSTALLED)
2. `hybrid_loop_agent.py` - v2.0 harness with hybrid loops
3. `semantic_memory.py` - Cross-project learning system
4. `approval_system.py` - User approval gates
5. `model_selector.py` - Dynamic model selection
6. `dependency_graph.py` - Feature dependency analysis
7. `parallel_coordinator.py` - Parallel execution orchestration

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_installation.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installation Validation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
REQUIRED_FILES=(
  "autonomous_agent.py"
  "hybrid_loop_agent.py"
  "semantic_memory.py"
  "approval_system.py"
  "model_selector.py"
  "dependency_graph.py"
  "parallel_coordinator.py"
)

# Check directory exists
if [ ! -d "$HARNESS_DIR" ]; then
  echo "❌ FAIL: Harness directory not found: $HARNESS_DIR"
  echo "   Run: /sdk-bridge:lra-setup"
  exit 1
fi

echo "✅ Harness directory exists: $HARNESS_DIR"
echo ""

# Check each required file
MISSING_COUNT=0
for file in "${REQUIRED_FILES[@]}"; do
  FILEPATH="$HARNESS_DIR/$file"
  if [ -f "$FILEPATH" ]; then
    echo "✅ $file"
  else
    echo "❌ MISSING: $file"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  fi
done

echo ""
if [ $MISSING_COUNT -eq 0 ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✅ ALL FILES INSTALLED ($((${#REQUIRED_FILES[@]} - MISSING_COUNT))/${#REQUIRED_FILES[@]})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ❌ INSTALLATION INCOMPLETE ($((${#REQUIRED_FILES[@]} - MISSING_COUNT))/${#REQUIRED_FILES[@]} files)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Missing $MISSING_COUNT files."
  echo "Run: /sdk-bridge:lra-setup (after fixing the command)"
  exit 1
fi
```

**Expected Outcome**: All 7 files present with execute permissions

**Current Issue**: Only `autonomous_agent.py` is installed

### 1.2 Import Dependency Test

**Purpose**: Verify Python scripts can import required dependencies

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_imports.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Python Import Validation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"

if [ ! -f "$PYTHON" ]; then
  echo "❌ FAIL: Python venv not found: $PYTHON"
  exit 1
fi

echo "✅ Python venv found: $PYTHON"
echo ""

# Test autonomous_agent.py imports
echo "Testing autonomous_agent.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from autonomous_agent import AutonomousAgent
print('✅ autonomous_agent.py imports successfully')
" 2>&1; then
  echo "✅ autonomous_agent.py: PASS"
else
  echo "❌ autonomous_agent.py: FAIL"
fi

echo ""

# Test hybrid_loop_agent.py imports
echo "Testing hybrid_loop_agent.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from hybrid_loop_agent import HybridLoopAgent
print('✅ hybrid_loop_agent.py imports successfully')
" 2>&1; then
  echo "✅ hybrid_loop_agent.py: PASS"
else
  echo "❌ hybrid_loop_agent.py: FAIL"
fi

echo ""

# Test semantic_memory.py imports
echo "Testing semantic_memory.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from semantic_memory import SemanticMemorySystem
print('✅ semantic_memory.py imports successfully')
" 2>&1; then
  echo "✅ semantic_memory.py: PASS"
else
  echo "❌ semantic_memory.py: FAIL"
fi

echo ""

# Test dependency_graph.py imports
echo "Testing dependency_graph.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from dependency_graph import DependencyGraph, build_graph_from_feature_list
print('✅ dependency_graph.py imports successfully')
" 2>&1; then
  echo "✅ dependency_graph.py: PASS"
else
  echo "❌ dependency_graph.py: FAIL"
fi

echo ""

# Test approval_system.py imports
echo "Testing approval_system.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from approval_system import ApprovalSystem
print('✅ approval_system.py imports successfully')
" 2>&1; then
  echo "✅ approval_system.py: PASS"
else
  echo "❌ approval_system.py: FAIL"
fi

echo ""

# Test model_selector.py imports
echo "Testing model_selector.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from model_selector import ModelSelector
print('✅ model_selector.py imports successfully')
" 2>&1; then
  echo "✅ model_selector.py: PASS"
else
  echo "❌ model_selector.py: FAIL"
fi

echo ""

# Test parallel_coordinator.py imports
echo "Testing parallel_coordinator.py imports..."
if $PYTHON -c "
import sys
sys.path.append('$HARNESS_DIR')
from parallel_coordinator import ParallelCoordinator
print('✅ parallel_coordinator.py imports successfully')
" 2>&1; then
  echo "✅ parallel_coordinator.py: PASS"
else
  echo "❌ parallel_coordinator.py: FAIL"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Import Tests Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Expected Outcome**: All imports succeed without errors

### 1.3 SDK Installation Test

**Purpose**: Verify Claude Agent SDK is installed in venv and functional

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_sdk.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Agent SDK Validation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

if [ ! -f "$PYTHON" ]; then
  echo "❌ FAIL: Python venv not found"
  exit 1
fi

# Test SDK installation
echo "Testing Claude Agent SDK installation..."
SDK_VERSION=$($PYTHON -c "import claude_agent_sdk; print(claude_agent_sdk.__version__)" 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Claude Agent SDK installed: v$SDK_VERSION"
else
  echo "❌ Claude Agent SDK NOT installed"
  echo ""
  echo "Install with:"
  echo "  ~/.claude/skills/long-running-agent/.venv/bin/pip install claude-agent-sdk"
  exit 1
fi

echo ""

# Test SDK can import query function
echo "Testing SDK query function..."
if $PYTHON -c "from claude_agent_sdk import query, ClaudeAgentOptions; print('✅ SDK query function available')" 2>&1; then
  echo "✅ SDK query function: PASS"
else
  echo "❌ SDK query function: FAIL"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ SDK VALIDATION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Expected Outcome**: SDK installed and query function available

---

## 2. Integration Testing

### 2.1 Full Workflow Test (v1.4.0)

**Purpose**: Test complete workflow from init to completion

**Test Project Setup**:
```bash
#!/bin/bash
# Filename: tests/test_v1_workflow.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  v1.4.0 Workflow Integration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create test project
TEST_DIR="/tmp/sdk-bridge-test-v1-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "✅ Created test project: $TEST_DIR"

# Initialize git
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "# Test Project" > README.md
git add README.md
git commit -m "Initial commit"

echo "✅ Initialized git repository"

# Create feature_list.json
cat > feature_list.json <<'EOF'
[
  {
    "description": "Create hello.txt file with 'Hello World'",
    "test": "File hello.txt exists with content 'Hello World'",
    "passes": false
  },
  {
    "description": "Create goodbye.txt file with 'Goodbye World'",
    "test": "File goodbye.txt exists with content 'Goodbye World'",
    "passes": false
  }
]
EOF

echo "✅ Created feature_list.json with 2 simple features"

# Create CLAUDE.md protocol
cat > CLAUDE.md <<'EOF'
# Test Project Protocol

When implementing features:
1. Read feature_list.json
2. Implement the feature as described
3. Create the specified files with exact content
4. Say SUCCESS when done
EOF

echo "✅ Created CLAUDE.md protocol"

# Verify feature_list.json
echo ""
echo "Feature List:"
cat feature_list.json | jq -r '.[] | "  - \(.description)"'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test project ready: $TEST_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  cd $TEST_DIR"
echo "  /sdk-bridge:init"
echo "  /sdk-bridge:handoff"
echo ""
echo "Expected behavior:"
echo "  1. SDK creates hello.txt with 'Hello World'"
echo "  2. SDK commits changes"
echo "  3. SDK creates goodbye.txt with 'Goodbye World'"
echo "  4. SDK commits changes"
echo "  5. SDK creates .claude/sdk_complete.json"
echo ""
echo "Validation:"
echo "  [ -f hello.txt ] && grep 'Hello World' hello.txt"
echo "  [ -f goodbye.txt ] && grep 'Goodbye World' goodbye.txt"
echo "  git log --oneline | grep 'SDK: completed feature'"
```

**Workflow Steps**:
1. Run `/sdk-bridge:init` → creates `.claude/sdk-bridge.local.md`
2. Run `/sdk-bridge:handoff` → launches autonomous agent
3. Monitor with `/sdk-bridge:status`
4. Wait for completion (check `.claude/sdk_complete.json`)
5. Run `/sdk-bridge:resume` → generates report

**Validation Criteria**:
```bash
#!/bin/bash
# Filename: tests/validate_v1_workflow.sh

echo "Validating v1 workflow completion..."
echo ""

# Check files were actually created
if [ -f "hello.txt" ] && grep -q "Hello World" hello.txt; then
  echo "✅ hello.txt created with correct content"
else
  echo "❌ FAIL: hello.txt missing or incorrect content"
fi

if [ -f "goodbye.txt" ] && grep -q "Goodbye World" goodbye.txt; then
  echo "✅ goodbye.txt created with correct content"
else
  echo "❌ FAIL: goodbye.txt missing or incorrect content"
fi

# Check git commits exist
COMMIT_COUNT=$(git log --oneline | grep "SDK: completed feature" | wc -l)
if [ "$COMMIT_COUNT" -eq 2 ]; then
  echo "✅ 2 git commits created by SDK"
else
  echo "❌ FAIL: Expected 2 commits, found $COMMIT_COUNT"
fi

# Check completion signal
if [ -f ".claude/sdk_complete.json" ]; then
  REASON=$(jq -r '.reason' .claude/sdk_complete.json)
  echo "✅ Completion signal created: $REASON"
else
  echo "❌ FAIL: .claude/sdk_complete.json not found"
fi

# Check feature_list.json updated
PASSES=$(jq '[.[] | select(.passes == true)] | length' feature_list.json)
if [ "$PASSES" -eq 2 ]; then
  echo "✅ All features marked as passes: true"
else
  echo "❌ FAIL: Only $PASSES features marked as passing"
fi

echo ""
echo "Test project: $PWD"
echo "Review logs: tail -50 .claude/sdk-bridge.log"
```

**Expected Outcome**: All files created, commits exist, features marked complete

**Current Issue**: Files reported as completed but not actually created in filesystem

### 2.2 v2.0 Workflow Test

**Purpose**: Test v2.0 features (hybrid loops, semantic memory, planning)

**Test Project Setup**:
```bash
#!/bin/bash
# Filename: tests/test_v2_workflow.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  v2.0 Workflow Integration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create test project
TEST_DIR="/tmp/sdk-bridge-test-v2-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "✅ Created test project: $TEST_DIR"

# Initialize git
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "# v2 Test Project" > README.md
git add README.md
git commit -m "Initial commit"

echo "✅ Initialized git repository"

# Create feature_list.json with dependencies
cat > feature_list.json <<'EOF'
[
  {
    "id": "feat-001",
    "description": "Create config.json with base settings",
    "test": "File config.json exists with JSON content",
    "dependencies": [],
    "priority": 10,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Create main.py that reads config.json",
    "test": "File main.py exists and imports json",
    "dependencies": ["feat-001"],
    "priority": 5,
    "passes": false
  },
  {
    "id": "feat-003",
    "description": "Create utils.py with helper functions",
    "test": "File utils.py exists with at least one function",
    "dependencies": [],
    "priority": 5,
    "passes": false
  }
]
EOF

echo "✅ Created feature_list.json with 3 features (dependencies)"

# Create CLAUDE.md protocol
cat > CLAUDE.md <<'EOF'
# v2 Test Project Protocol

When implementing features:
1. Read feature_list.json and check dependencies
2. Implement features in dependency order
3. Create files as described
4. Say SUCCESS when done

Features:
- config.json: {"app": "test", "version": "1.0.0"}
- main.py: import json, read config.json
- utils.py: def hello(): return "hello"
EOF

echo "✅ Created CLAUDE.md protocol"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  v2 Test project ready: $TEST_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  cd $TEST_DIR"
echo "  /sdk-bridge:init"
echo "  /sdk-bridge:plan-v2  # Should show dependency graph"
echo "  /sdk-bridge:handoff-v2"
echo ""
```

**Workflow Steps**:
1. Run `/sdk-bridge:init`
2. Run `/sdk-bridge:plan-v2` → creates dependency graph
3. Verify `.claude/feature-graph.json` and `.claude/execution-plan.json`
4. Run `/sdk-bridge:handoff-v2` → launches hybrid loop agent
5. Monitor progress
6. Validate files created in dependency order

**Validation Criteria**:
```bash
#!/bin/bash
# Filename: tests/validate_v2_workflow.sh

echo "Validating v2 workflow completion..."
echo ""

# Check planning outputs
if [ -f ".claude/feature-graph.json" ]; then
  NODE_COUNT=$(jq '.nodes | length' .claude/feature-graph.json)
  echo "✅ Dependency graph created: $NODE_COUNT nodes"
else
  echo "❌ FAIL: .claude/feature-graph.json not found"
fi

if [ -f ".claude/execution-plan.json" ]; then
  LEVEL_COUNT=$(jq '.execution_levels | length' .claude/execution-plan.json)
  echo "✅ Execution plan created: $LEVEL_COUNT levels"
else
  echo "❌ FAIL: .claude/execution-plan.json not found"
fi

# Check files created in dependency order
if [ -f "config.json" ] && jq -e '.app == "test"' config.json > /dev/null; then
  echo "✅ config.json created with correct content"
else
  echo "❌ FAIL: config.json missing or incorrect"
fi

if [ -f "main.py" ] && grep -q "import json" main.py; then
  echo "✅ main.py created with json import"
else
  echo "❌ FAIL: main.py missing or incorrect"
fi

if [ -f "utils.py" ] && grep -q "def hello" utils.py; then
  echo "✅ utils.py created with function"
else
  echo "❌ FAIL: utils.py missing or incorrect"
fi

# Check git commit order matches dependency order
echo ""
echo "Git commit history:"
git log --oneline --reverse | grep "SDK:"

# Check v2 features logged
if [ -f ".claude/sdk-bridge.log" ]; then
  if grep -q "hybrid_loop_agent" .claude/sdk-bridge.log; then
    echo "✅ v2 hybrid loop agent used"
  else
    echo "⚠️  WARNING: v2 agent may not have been used"
  fi
fi
```

**Expected Outcome**:
- Dependency graph created
- Execution plan shows 2 levels (feat-001 → [feat-002, feat-003])
- Files created in dependency order
- All v2 features functional

**Current Issue**: v2 features non-functional due to missing Python script installations

---

## 3. Version Testing

### 3.1 Backward Compatibility Test (v1.4.0)

**Purpose**: Ensure v1.4.0 workflows still work after v2.0 installation

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_backward_compatibility.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Backward Compatibility Test (v1.4.0)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create test project WITHOUT v2 config
TEST_DIR="/tmp/sdk-bridge-compat-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

git init
git config user.email "test@example.com"
git config user.name "Test User"

# Create v1.4.0 style feature_list.json (no id, dependencies, priority)
cat > feature_list.json <<'EOF'
[
  {
    "description": "Create file1.txt",
    "test": "File exists",
    "passes": false
  }
]
EOF

# Create v1.4.0 style config (no v2 features)
mkdir -p .claude
cat > .claude/sdk-bridge.local.md <<'EOF'
---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 5
reserve_sessions: 1
progress_stall_threshold: 3
log_level: INFO
---
EOF

echo "✅ Created v1.4.0 style project"

# Try to handoff with v1.4.0 command
echo ""
echo "Testing /sdk-bridge:handoff (v1.4.0 command)..."
echo "  Should launch autonomous_agent.py"
echo "  Should NOT require v2 features"
echo ""

# Validate it uses v1 harness
# Expected: launch-harness.sh calls autonomous_agent.py
# NOT: hybrid_loop_agent.py

echo "Validation:"
echo "  1. Check .claude/sdk-bridge.log for 'autonomous_agent' (not 'hybrid_loop')"
echo "  2. Verify handoff works without v2 config fields"
echo "  3. Feature completes using v1.4.0 retry logic"
```

**Success Criteria**:
- v1.4.0 command works without v2 configuration
- Uses `autonomous_agent.py` not `hybrid_loop_agent.py`
- No errors about missing v2 dependencies

### 3.2 v2.0 Feature Enablement Test

**Purpose**: Test auto-detection of v2 features and graceful fallback

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_v2_auto_detection.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  v2.0 Auto-Detection Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Unified handoff command with v2 enabled
TEST_DIR="/tmp/sdk-bridge-v2-auto-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

git init
git config user.email "test@example.com"
git config user.name "Test User"

mkdir -p .claude
cat > .claude/sdk-bridge.local.md <<'EOF'
---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 5

# v2 features ENABLED
enable_v2_features: true
enable_semantic_memory: true
max_inner_loops: 5
---
EOF

echo "✅ Created project with v2 features enabled"
echo ""
echo "Testing unified /sdk-bridge:handoff command..."
echo "  Should detect enable_v2_features: true"
echo "  Should launch hybrid_loop_agent.py"
echo ""

# Test 2: Unified handoff command with v2 disabled
TEST_DIR2="/tmp/sdk-bridge-v2-disabled-$$"
mkdir -p "$TEST_DIR2"
cd "$TEST_DIR2"

git init
git config user.email "test@example.com"
git config user.name "Test User"

mkdir -p .claude
cat > .claude/sdk-bridge.local.md <<'EOF'
---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 5

# v2 features DISABLED
enable_v2_features: false
---
EOF

echo "✅ Created project with v2 features disabled"
echo ""
echo "Testing unified /sdk-bridge:handoff command..."
echo "  Should detect enable_v2_features: false"
echo "  Should launch autonomous_agent.py (v1.4.0)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Validation Checklist"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "[ ] Unified command detects v2 config"
echo "[ ] Launches correct harness based on config"
echo "[ ] Graceful error if v2 enabled but scripts missing"
echo "[ ] Clear message telling user how to fix"
```

**Success Criteria**:
- Unified command auto-detects v2 configuration
- Launches appropriate harness (v1 or v2)
- Clear error messages if v2 scripts missing

### 3.3 Command Consolidation Test

**Purpose**: Verify duplicate commands are resolved

**Current State**:
- `handoff.md` - v1.4.0 command
- `handoff-v2.md` - v2.0 command (causes confusion)

**Recommended Solution**:
```markdown
# Option A: Unified handoff.md with auto-detection

---
description: "Hand off to SDK agent (auto-detects v1/v2)"
allowed-tools: ["Task", "Bash", "Read", "Write"]
---

# SDK Bridge Handoff

I'll hand off your work to the autonomous SDK agent. I'll automatically detect
whether to use v1.4.0 or v2.0 features based on your configuration.

## Configuration Detection

Read `.claude/sdk-bridge.local.md` and check:
- If `enable_v2_features: true` → use v2.0 harness
- Otherwise → use v1.4.0 harness

## Validation

Use Task tool to invoke handoff-validator agent...

## Launch (v1.4.0)

If v2 features NOT enabled:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/launch-harness.sh .
```

## Launch (v2.0)

If v2 features enabled:
```bash
# Launch hybrid_loop_agent.py with v2 args
HARNESS="$HOME/.claude/skills/long-running-agent/harness/hybrid_loop_agent.py"
# ... (rest of v2 launch logic)
```
```

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_command_consolidation.sh

echo "Testing command consolidation..."
echo ""

# Check only ONE handoff command exists in marketplace
HANDOFF_COUNT=$(jq '[.plugins[0].commands[] | select(contains("handoff"))] | length' \
  .claude-plugin/marketplace.json)

if [ "$HANDOFF_COUNT" -eq 1 ]; then
  echo "✅ Only 1 handoff command registered"
else
  echo "❌ FAIL: $HANDOFF_COUNT handoff commands found (expected 1)"
  echo "   Found:"
  jq -r '.plugins[0].commands[] | select(contains("handoff"))' \
    .claude-plugin/marketplace.json
fi

# Check plan command behavior
PLAN_COUNT=$(jq '[.plugins[0].commands[] | select(contains("plan"))] | length' \
  .claude-plugin/marketplace.json)

echo ""
echo "Plan commands: $PLAN_COUNT"
if [ "$PLAN_COUNT" -le 1 ]; then
  echo "✅ Plan command consolidated or v2-only"
else
  echo "⚠️  Multiple plan commands - consider consolidation"
fi
```

**Success Criteria**:
- Only ONE handoff command in marketplace
- Command auto-detects v1 vs v2 based on config
- Clear documentation on which features require v2

---

## 4. Error Handling Testing

### 4.1 Missing SDK Test

**Purpose**: Test behavior when SDK not installed

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_missing_sdk.sh

echo "Testing error handling for missing SDK..."
echo ""

# Remove SDK from venv
VENV_DIR="$HOME/.claude/skills/long-running-agent/.venv"
if [ -d "$VENV_DIR" ]; then
  mv "$VENV_DIR" "$VENV_DIR.backup"
  echo "✅ Temporarily removed SDK venv"
fi

# Try to run handoff
echo ""
echo "Attempting handoff without SDK..."
echo "Expected: Clear error message with installation instructions"
echo ""

# Restore venv
if [ -d "$VENV_DIR.backup" ]; then
  mv "$VENV_DIR.backup" "$VENV_DIR"
  echo "✅ Restored SDK venv"
fi
```

**Expected Behavior**:
```
❌ ERROR: Claude Agent SDK not installed

The SDK is required to run autonomous agents in the background.

To fix this:
  1. Run: /sdk-bridge:lra-setup
  2. This will install the SDK in a virtual environment
  3. Then try /sdk-bridge:handoff again

Details:
  SDK path: ~/.claude/skills/long-running-agent/.venv/
  Missing: claude-agent-sdk package
```

### 4.2 Missing Python Scripts Test

**Purpose**: Test behavior when v2 Python scripts missing

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_missing_scripts.sh

echo "Testing error handling for missing v2 scripts..."
echo ""

# Create project with v2 enabled
TEST_DIR="/tmp/sdk-bridge-missing-scripts-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

git init
mkdir -p .claude

cat > .claude/sdk-bridge.local.md <<'EOF'
---
enable_v2_features: true
enable_semantic_memory: true
---
EOF

# Remove v2 script (simulate incomplete installation)
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
if [ -f "$HARNESS_DIR/hybrid_loop_agent.py" ]; then
  mv "$HARNESS_DIR/hybrid_loop_agent.py" "$HARNESS_DIR/hybrid_loop_agent.py.backup"
fi

echo "✅ Simulated missing hybrid_loop_agent.py"
echo ""
echo "Attempting handoff-v2..."
echo "Expected: Error with fix instructions"
echo ""

# Restore
if [ -f "$HARNESS_DIR/hybrid_loop_agent.py.backup" ]; then
  mv "$HARNESS_DIR/hybrid_loop_agent.py.backup" "$HARNESS_DIR/hybrid_loop_agent.py"
fi
```

**Expected Behavior**:
```
❌ ERROR: v2.0 features enabled but required scripts missing

Your configuration enables v2 features:
  enable_v2_features: true
  enable_semantic_memory: true

But the following scripts are not installed:
  ❌ hybrid_loop_agent.py
  ❌ semantic_memory.py

To fix this:
  1. Run: /sdk-bridge:lra-setup (fixes installation)
  2. Or disable v2: Set enable_v2_features: false in .claude/sdk-bridge.local.md
  3. Then try handoff again

v1.4.0 is still available - just disable v2 features in your config.
```

### 4.3 Invalid Configuration Test

**Purpose**: Test behavior with malformed config files

**Test Commands**:
```bash
#!/bin/bash
# Filename: tests/test_invalid_config.sh

echo "Testing invalid configuration handling..."
echo ""

# Test 1: Invalid YAML
TEST_DIR="/tmp/sdk-bridge-invalid-yaml-$$"
mkdir -p "$TEST_DIR/.claude"
cd "$TEST_DIR"

cat > .claude/sdk-bridge.local.md <<'EOF'
---
enabled: true
model claude-sonnet-4-5  # MISSING COLON
max_sessions: invalid_number
---
EOF

echo "Test 1: Invalid YAML syntax"
echo "Expected: Error with line number and fix suggestion"
echo ""

# Test 2: Missing required fields
mkdir -p "/tmp/sdk-bridge-missing-fields-$$/.claude"
cd "/tmp/sdk-bridge-missing-fields-$$"

cat > .claude/sdk-bridge.local.md <<'EOF'
---
# Missing 'model' field
max_sessions: 10
---
EOF

echo "Test 2: Missing required fields"
echo "Expected: Error listing required fields"
echo ""

# Test 3: Invalid model name
mkdir -p "/tmp/sdk-bridge-invalid-model-$$/.claude"
cd "/tmp/sdk-bridge-invalid-model-$$"

cat > .claude/sdk-bridge.local.md <<'EOF'
---
enabled: true
model: claude-invalid-model-999
max_sessions: 10
---
EOF

echo "Test 3: Invalid model name"
echo "Expected: Warning with suggested models"
```

**Expected Behaviors**:
- YAML parse errors: Show line number and syntax issue
- Missing fields: List required fields with defaults
- Invalid model: Suggest valid model names

---

## 5. File Creation Verification Testing

### 5.1 Post-Execution Filesystem Validation

**Purpose**: Verify files are ACTUALLY created, not just reported

**Test Implementation**:
```bash
#!/bin/bash
# Filename: tests/verify_file_creation.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  File Creation Verification Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Load feature list
if [ ! -f "feature_list.json" ]; then
  echo "❌ feature_list.json not found"
  exit 1
fi

echo "Checking files for each feature..."
echo ""

# Extract all features marked as passes: true
COMPLETED=$(jq -r '.[] | select(.passes == true) | .description' feature_list.json)

FEATURE_COUNT=0
FILE_FOUND=0
FILE_MISSING=0

while IFS= read -r feature; do
  FEATURE_COUNT=$((FEATURE_COUNT + 1))
  echo "Feature: $feature"

  # Try to extract filename from description
  # Common patterns: "Create X file", "Add X.py", "Implement X.js"
  FILENAME=$(echo "$feature" | grep -oE '\b[a-zA-Z0-9_-]+\.(txt|py|js|json|md|sh)\b' | head -1)

  if [ -n "$FILENAME" ]; then
    if [ -f "$FILENAME" ]; then
      echo "  ✅ File exists: $FILENAME"
      FILE_FOUND=$((FILE_FOUND + 1))
    else
      echo "  ❌ FILE MISSING: $FILENAME"
      FILE_MISSING=$((FILE_MISSING + 1))
    fi
  else
    echo "  ⚠️  Could not extract filename from description"
  fi

  echo ""
done <<< "$COMPLETED"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Features marked complete: $FEATURE_COUNT"
echo "  Files found: $FILE_FOUND"
echo "  Files missing: $FILE_MISSING"
echo ""

if [ "$FILE_MISSING" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED: $FILE_MISSING files not created"
  exit 1
else
  echo "✅ VERIFICATION PASSED: All files created"
  exit 0
fi
```

### 5.2 Git Commit Content Validation

**Purpose**: Verify git commits contain actual file changes, not empty commits

**Test Implementation**:
```bash
#!/bin/bash
# Filename: tests/verify_git_commits.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Git Commit Content Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Get all SDK commits
SDK_COMMITS=$(git log --oneline --grep="SDK: completed feature" --reverse | awk '{print $1}')

if [ -z "$SDK_COMMITS" ]; then
  echo "❌ No SDK commits found"
  exit 1
fi

TOTAL_COMMITS=0
EMPTY_COMMITS=0
COMMITS_WITH_CHANGES=0

while IFS= read -r commit; do
  TOTAL_COMMITS=$((TOTAL_COMMITS + 1))

  # Get commit message
  MSG=$(git log -1 --pretty=%B "$commit")

  # Check if commit has file changes
  CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "$commit")
  CHANGE_COUNT=$(echo "$CHANGED_FILES" | wc -l)

  echo "Commit: $commit"
  echo "  Message: $MSG"

  if [ -z "$CHANGED_FILES" ] || [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "  ❌ EMPTY COMMIT (no files changed)"
    EMPTY_COMMITS=$((EMPTY_COMMITS + 1))
  else
    echo "  ✅ Changes: $CHANGE_COUNT file(s)"
    echo "$CHANGED_FILES" | sed 's/^/     - /'
    COMMITS_WITH_CHANGES=$((COMMITS_WITH_CHANGES + 1))
  fi

  echo ""
done <<< "$SDK_COMMITS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total SDK commits: $TOTAL_COMMITS"
echo "  Commits with changes: $COMMITS_WITH_CHANGES"
echo "  Empty commits: $EMPTY_COMMITS"
echo ""

if [ "$EMPTY_COMMITS" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED: $EMPTY_COMMITS empty commits"
  exit 1
else
  echo "✅ VERIFICATION PASSED: All commits have file changes"
  exit 0
fi
```

### 5.3 Feature-File Mapping Validation

**Purpose**: Create explicit mapping between features and expected files

**Enhanced feature_list.json Format**:
```json
[
  {
    "id": "feat-001",
    "description": "Create hello.txt file with 'Hello World'",
    "test": "File hello.txt exists with content 'Hello World'",
    "expected_files": [
      {
        "path": "hello.txt",
        "content_pattern": "Hello World",
        "must_exist": true
      }
    ],
    "passes": false
  }
]
```

**Validation Script**:
```bash
#!/bin/bash
# Filename: tests/verify_expected_files.sh

echo "Validating expected files from feature_list.json..."
echo ""

# Check if features have expected_files field
FEATURES_WITH_FILES=$(jq '[.[] | select(.expected_files)] | length' feature_list.json)

if [ "$FEATURES_WITH_FILES" -eq 0 ]; then
  echo "⚠️  No features have 'expected_files' field"
  echo "   Using legacy validation (filename extraction)"
  exit 0
fi

# Validate each feature's expected files
jq -c '.[] | select(.passes == true and .expected_files)' feature_list.json | while read -r feature; do
  FEAT_ID=$(echo "$feature" | jq -r '.id // .description')
  echo "Feature: $FEAT_ID"

  # Check each expected file
  echo "$feature" | jq -c '.expected_files[]' | while read -r expected; do
    FILEPATH=$(echo "$expected" | jq -r '.path')
    PATTERN=$(echo "$expected" | jq -r '.content_pattern // empty')
    MUST_EXIST=$(echo "$expected" | jq -r '.must_exist // true')

    if [ "$MUST_EXIST" = "true" ]; then
      if [ -f "$FILEPATH" ]; then
        if [ -n "$PATTERN" ]; then
          if grep -q "$PATTERN" "$FILEPATH"; then
            echo "  ✅ $FILEPATH (with pattern '$PATTERN')"
          else
            echo "  ❌ $FILEPATH exists but missing pattern '$PATTERN'"
          fi
        else
          echo "  ✅ $FILEPATH"
        fi
      else
        echo "  ❌ MISSING: $FILEPATH"
      fi
    fi
  done

  echo ""
done
```

---

## 6. Automated Test Suite

### 6.1 Master Test Runner

**Purpose**: Run all tests in sequence and generate report

**Test Script**:
```bash
#!/bin/bash
# Filename: tests/run_all_tests.sh
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SDK Bridge Plugin - Complete Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$(date)"
echo ""

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="/tmp/sdk-bridge-test-results-$(date +%s).txt"

echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Initialize results
cat > "$RESULTS_FILE" <<EOF
SDK Bridge Plugin Test Results
Generated: $(date)
==================================================

EOF

# Track results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
  local test_name="$1"
  local test_script="$2"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Running: $test_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  TESTS_RUN=$((TESTS_RUN + 1))

  if bash "$test_script"; then
    echo "" >> "$RESULTS_FILE"
    echo "✅ PASS: $test_name" >> "$RESULTS_FILE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo ""
    echo "✅ PASSED"
  else
    echo "" >> "$RESULTS_FILE"
    echo "❌ FAIL: $test_name" >> "$RESULTS_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo ""
    echo "❌ FAILED"
  fi

  echo ""
  echo ""
}

# Run installation tests
echo "=========================================="
echo "  Phase 1: Installation Tests"
echo "=========================================="
echo ""

run_test "Installation Validation" "$TEST_DIR/test_installation.sh"
run_test "Import Dependencies" "$TEST_DIR/test_imports.sh"
run_test "SDK Installation" "$TEST_DIR/test_sdk.sh"

# Run integration tests
echo "=========================================="
echo "  Phase 2: Integration Tests"
echo "=========================================="
echo ""

# Note: These require manual `/sdk-bridge:handoff` invocation
echo "⚠️  Integration tests require manual CLI execution"
echo "    Run these manually:"
echo "      - test_v1_workflow.sh (setup, then run /sdk-bridge:handoff)"
echo "      - test_v2_workflow.sh (setup, then run /sdk-bridge:handoff-v2)"
echo ""

# Run version tests
echo "=========================================="
echo "  Phase 3: Version Tests"
echo "=========================================="
echo ""

run_test "Backward Compatibility" "$TEST_DIR/test_backward_compatibility.sh"
run_test "Command Consolidation" "$TEST_DIR/test_command_consolidation.sh"

# Run error handling tests
echo "=========================================="
echo "  Phase 4: Error Handling Tests"
echo "=========================================="
echo ""

run_test "Missing SDK" "$TEST_DIR/test_missing_sdk.sh"
run_test "Missing Scripts" "$TEST_DIR/test_missing_scripts.sh"

# Generate summary
echo "" >> "$RESULTS_FILE"
echo "==========================================" >> "$RESULTS_FILE"
echo "  Test Summary" >> "$RESULTS_FILE"
echo "==========================================" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"
echo "Total Tests: $TESTS_RUN" >> "$RESULTS_FILE"
echo "Passed: $TESTS_PASSED" >> "$RESULTS_FILE"
echo "Failed: $TESTS_FAILED" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
  echo "✅ ALL TESTS PASSED" >> "$RESULTS_FILE"
else
  echo "❌ $TESTS_FAILED TEST(S) FAILED" >> "$RESULTS_FILE"
fi

# Display results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Suite Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat "$RESULTS_FILE"
echo ""
echo "Full results: $RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
  exit 0
else
  exit 1
fi
```

### 6.2 Continuous Integration Hook

**Purpose**: Run tests automatically on git commit

**Git Hook** (`.git/hooks/pre-commit`):
```bash
#!/bin/bash

echo "Running SDK Bridge plugin tests..."

# Only run tests if plugin files changed
CHANGED_FILES=$(git diff --cached --name-only)

if echo "$CHANGED_FILES" | grep -q "^plugins/sdk-bridge/"; then
  echo "Plugin files changed - running validation tests..."

  # Run quick validation
  bash tests/test_installation.sh || {
    echo ""
    echo "❌ Installation tests failed"
    echo "   Fix issues before committing"
    exit 1
  }

  bash tests/test_command_consolidation.sh || {
    echo ""
    echo "❌ Command structure tests failed"
    echo "   Fix issues before committing"
    exit 1
  }

  echo "✅ Pre-commit tests passed"
fi
```

---

## 7. Success Criteria Matrix

| Test Category | Test Name | Pass Criteria | Current Status |
|--------------|-----------|---------------|----------------|
| **Installation** | All 7 scripts installed | All files present in `~/.claude/skills/long-running-agent/harness/` | ❌ FAIL (only 1/7) |
| | Python imports work | All scripts import without errors | ❌ UNKNOWN |
| | SDK installed | `claude-agent-sdk` in venv | ✅ LIKELY PASS |
| **Integration v1** | Init → Handoff → Resume | Complete workflow with file creation | ❌ FAIL (files not created) |
| | Feature completion tracking | `passes: true` matches reality | ❌ FAIL |
| | Git commits | Non-empty commits with file changes | ❌ FAIL (empty commits) |
| **Integration v2** | Plan generates graph | `.claude/feature-graph.json` created | ❌ FAIL (script missing) |
| | Handoff v2 launches | `hybrid_loop_agent.py` runs | ❌ FAIL (script missing) |
| | Dependency ordering | Features execute in order | ❌ FAIL |
| **Version** | v1.4.0 backward compat | v1 works without v2 config | ⚠️ UNTESTED |
| | v2 auto-detection | Unified command chooses harness | ⚠️ UNTESTED |
| | Command consolidation | No duplicate commands | ❌ FAIL (handoff + handoff-v2) |
| **Error Handling** | Missing SDK | Clear error + fix steps | ⚠️ UNTESTED |
| | Missing scripts | Clear error + fix steps | ⚠️ UNTESTED |
| | Invalid config | Parse errors with line numbers | ⚠️ UNTESTED |
| **File Verification** | Files created | Filesystem matches features | ❌ FAIL |
| | Commit content | Git commits not empty | ❌ FAIL |
| | Expected files mapping | Feature → file validation | ⚠️ NOT IMPLEMENTED |

---

## 8. Recommended Fix Priority

Based on testing strategy, fix issues in this order:

### Priority 1: Critical Blockers (Required for ANY functionality)

1. **Fix lra-setup to install all 7 Python scripts**
   - Update `commands/lra-setup.md` to copy all scripts
   - Add validation step to verify all files installed
   - Estimated impact: Enables ALL v2 features

2. **Verify autonomous_agent.py actually creates files**
   - Root cause analysis: Why files aren't created
   - Fix SDK session execution
   - Add filesystem validation after each feature
   - Estimated impact: Fixes core functionality

3. **Fix git commits to contain actual changes**
   - Ensure files are staged before commit
   - Add `git add .` before `git commit`
   - Validate commit is non-empty
   - Estimated impact: Makes progress trackable

### Priority 2: High Impact (Enables major features)

4. **Consolidate duplicate commands**
   - Merge `handoff.md` + `handoff-v2.md` into unified command
   - Add auto-detection based on config
   - Deprecate `-v2` suffix
   - Estimated impact: Reduces confusion

5. **Add comprehensive error messages**
   - Missing SDK detection
   - Missing v2 scripts detection
   - Config validation with helpful errors
   - Estimated impact: Improves user experience

### Priority 3: Quality of Life (Makes testing easier)

6. **Implement file verification system**
   - Add `expected_files` field to feature_list.json
   - Create validation scripts
   - Add to resume command report
   - Estimated impact: Prevents false completion reports

7. **Create automated test suite**
   - Package all test scripts in `tests/` directory
   - Add master test runner
   - Document how to run tests
   - Estimated impact: Catches regressions early

---

## 9. Test Execution Checklist

Before releasing a fix:

- [ ] Run `tests/test_installation.sh` → All 7 files installed
- [ ] Run `tests/test_imports.sh` → All Python imports work
- [ ] Run `tests/test_sdk.sh` → SDK functional
- [ ] Create test project and run full v1 workflow
- [ ] Verify files ACTUALLY created in filesystem
- [ ] Check git commits are non-empty (`git log -p`)
- [ ] Test v2 plan command creates graph
- [ ] Test v2 handoff launches hybrid agent
- [ ] Test backward compatibility (v1 config → v1 harness)
- [ ] Test auto-detection (v2 config → v2 harness)
- [ ] Test error messages for missing dependencies
- [ ] Run `tests/run_all_tests.sh` and achieve 100% pass rate

---

## 10. Test Documentation

All test scripts should be stored in `/tests/` directory:

```
sdk-bridge-marketplace/
├── tests/
│   ├── README.md                          # Test suite documentation
│   ├── run_all_tests.sh                   # Master test runner
│   ├── test_installation.sh               # Verify all 7 scripts installed
│   ├── test_imports.sh                    # Verify Python imports
│   ├── test_sdk.sh                        # Verify SDK functional
│   ├── test_v1_workflow.sh                # v1.4.0 integration test
│   ├── test_v2_workflow.sh                # v2.0 integration test
│   ├── validate_v1_workflow.sh            # v1 completion validation
│   ├── validate_v2_workflow.sh            # v2 completion validation
│   ├── test_backward_compatibility.sh     # v1 still works
│   ├── test_v2_auto_detection.sh          # Unified command detection
│   ├── test_command_consolidation.sh      # No duplicate commands
│   ├── test_missing_sdk.sh                # Error handling
│   ├── test_missing_scripts.sh            # Error handling
│   ├── test_invalid_config.sh             # Error handling
│   ├── verify_file_creation.sh            # Filesystem validation
│   ├── verify_git_commits.sh              # Git commit validation
│   └── verify_expected_files.sh           # Feature→file mapping
├── TESTING_STRATEGY.md                    # This document
└── plugins/sdk-bridge/
    └── ... (plugin code)
```

Each test script should:
- Return exit code 0 on success, non-zero on failure
- Print clear success/failure messages
- Be runnable independently
- Be documented with purpose and expected outcomes

---

## Appendix: Quick Reference

### Run Full Test Suite
```bash
bash tests/run_all_tests.sh
```

### Run Individual Test
```bash
bash tests/test_installation.sh
```

### Validate After Handoff
```bash
cd your-project/
bash /path/to/sdk-bridge-marketplace/tests/verify_file_creation.sh
bash /path/to/sdk-bridge-marketplace/tests/verify_git_commits.sh
```

### Check Installation Status
```bash
ls -la ~/.claude/skills/long-running-agent/harness/
# Should show 7 Python files
```

### Verify SDK
```bash
~/.claude/skills/long-running-agent/.venv/bin/python -c \
  "import claude_agent_sdk; print(claude_agent_sdk.__version__)"
```

---

**End of Testing Strategy**
