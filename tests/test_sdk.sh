#!/bin/bash
# Claude Agent SDK Validation Test
# Verifies SDK is installed and functional
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Agent SDK Validation Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

if [ ! -f "$PYTHON" ]; then
  echo "❌ FAIL: Python venv not found"
  echo "   Expected: $PYTHON"
  echo "   Run: /sdk-bridge:lra-setup"
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
