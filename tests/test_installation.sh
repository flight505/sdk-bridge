#!/bin/bash
# SDK Bridge Installation Validation Test
# Verifies all 7 required Python scripts are installed
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
