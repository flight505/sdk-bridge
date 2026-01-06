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

## Step 3: Create Virtual Environment and Install SDK

```bash
VENV_DIR="$HOME/.claude/skills/long-running-agent/.venv"

if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment..."

  # Try uv first (faster), fall back to python3 -m venv
  if command -v uv &> /dev/null; then
    uv venv "$VENV_DIR"
    echo "✅ Created venv using uv"
  else
    python3 -m venv "$VENV_DIR"
    echo "✅ Created venv using python3 -m venv"
  fi
else
  echo "✅ Virtual environment already exists"
fi
```

```bash
VENV_DIR="$HOME/.claude/skills/long-running-agent/.venv"
echo "Installing Claude Agent SDK..."

# Activate venv using portable syntax
. "$VENV_DIR/bin/activate"

# Try uv pip first, fall back to pip
if command -v uv &> /dev/null; then
  uv pip install claude-agent-sdk
  echo "✅ Installed using uv pip"
else
  pip install claude-agent-sdk
  echo "✅ Installed using pip"
fi

deactivate
echo "✅ Claude Agent SDK installed"
```

## Step 4: Verify Installation

```bash
~/.claude/skills/long-running-agent/.venv/bin/python -c "import claude_agent_sdk; print(f'✅ Claude Agent SDK v{claude_agent_sdk.__version__} ready')"
```

## Summary

The long-running-agent harness is now installed with its own Python environment. You can now use `/sdk-bridge:init` to set up your project for autonomous development.

**Installed components:**
- Harness: `~/.claude/skills/long-running-agent/harness/autonomous_agent.py`
- Python venv: `~/.claude/skills/long-running-agent/.venv/`
- SDK: `claude-agent-sdk` (in venv)
