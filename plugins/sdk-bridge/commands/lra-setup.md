---
description: "Install the long-running-agent harness required by SDK bridge"
allowed-tools: ["Bash", "Read", "Write"]
---

# Setup Long-Running Agent Harness

I'll set up the `autonomous_agent.py` harness in your `~/.claude` directory. This is the background process that handles autonomous work.

## Step 1: Create Directories

```bash
mkdir -p ~/.claude/skills/long-running-agent/harness
echo "✅ Created directory: ~/.claude/skills/long-running-agent/harness"
```

## Step 2: Install Harness Script

```bash
cp "${CLAUDE_PLUGIN_ROOT}/scripts/autonomous_agent.py" ~/.claude/skills/long-running-agent/harness/autonomous_agent.py
chmod +x ~/.claude/skills/long-running-agent/harness/autonomous_agent.py
echo "✅ Installed harness to ~/.claude/skills/long-running-agent/harness/autonomous_agent.py"
```

## Step 3: Verify Dependencies

```bash
if python3 -c "import claude_agent_sdk" 2>/dev/null; then
  echo "✅ Claude Agent SDK is already installed"
else
  echo "⚠️  Claude Agent SDK not found. Please run:"
  echo "   pip install claude-agent-sdk"
fi
```

## Summary

The long-running-agent harness is now installed. You can now use `/sdk-bridge:init` to set up your project for autonomous development.
