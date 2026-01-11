#!/bin/bash
# Command Consolidation Test
# Verifies no duplicate commands exist
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Command Consolidation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find marketplace.json
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKETPLACE_JSON="$SCRIPT_DIR/../.claude-plugin/marketplace.json"

if [ ! -f "$MARKETPLACE_JSON" ]; then
  echo "❌ FAIL: marketplace.json not found at $MARKETPLACE_JSON"
  exit 1
fi

echo "✅ Found marketplace.json"
echo ""

# Check handoff commands
echo "Checking handoff commands..."
HANDOFF_COMMANDS=$(jq -r '.plugins[0].commands[] | select(contains("handoff"))' "$MARKETPLACE_JSON")
HANDOFF_COUNT=$(echo "$HANDOFF_COMMANDS" | grep -c "handoff" || true)

echo "Found handoff-related commands:"
echo "$HANDOFF_COMMANDS"
echo ""

if [ "$HANDOFF_COUNT" -eq 1 ]; then
  echo "✅ Only 1 handoff command registered (IDEAL)"
  HANDOFF_PASS=true
elif [ "$HANDOFF_COUNT" -eq 2 ]; then
  echo "⚠️  2 handoff commands found (handoff + handoff-v2)"
  echo "   Recommendation: Consolidate into unified command"
  HANDOFF_PASS=false
else
  echo "❌ FAIL: $HANDOFF_COUNT handoff commands found (unexpected)"
  HANDOFF_PASS=false
fi

echo ""

# Check plan commands
echo "Checking plan commands..."
PLAN_COMMANDS=$(jq -r '.plugins[0].commands[] | select(contains("plan"))' "$MARKETPLACE_JSON")
PLAN_COUNT=$(echo "$PLAN_COMMANDS" | grep -c "plan" || true)

if [ "$PLAN_COUNT" -eq 0 ]; then
  echo "⚠️  No plan commands found"
  PLAN_PASS=true
elif [ "$PLAN_COUNT" -eq 1 ]; then
  echo "✅ 1 plan command: $(echo "$PLAN_COMMANDS" | head -1)"
  PLAN_PASS=true
else
  echo "⚠️  $PLAN_COUNT plan commands found"
  echo "$PLAN_COMMANDS"
  PLAN_PASS=true  # Not critical
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$HANDOFF_PASS" = true ]; then
  echo "  ✅ COMMAND STRUCTURE OPTIMAL"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "  ⚠️  COMMAND CONSOLIDATION RECOMMENDED"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Consider merging handoff.md and handoff-v2.md into a unified"
  echo "command that auto-detects v1 vs v2 based on configuration."
  exit 1
fi
