# SDK Bridge Plugin

**v3.0**: End-to-end autonomous development assistant with intelligent task decomposition, dependency validation, and automated planning.

## Overview

The SDK Bridge plugin transforms natural language descriptions into fully implemented features through intelligent decomposition and autonomous execution:

1. **Describe your task** in natural language or point to a spec document
2. **Review AI-generated features** with interactive multi-select UI
3. **Automatic validation** detects dependencies, cycles, and optimal ordering
4. **Autonomous implementation** by SDK agent with live progress tracking
5. **Comprehensive completion report** with file validation and next steps

**No manual feature_list.json creation required.** The plugin handles task decomposition, dependency analysis, and execution planning automatically.

## Installation

The plugin is installed at: `~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/`

Prerequisites:
- Claude Code CLI
- Python 3.8+
- Claude Agent SDK: `pip install claude-agent-sdk`

> **Self-Contained**: The plugin bundles its own `autonomous_agent.py` harness - no external dependencies required.

## Quick Start

## 🚨 Important: Use the v3.0 Workflow

If you're new to SDK Bridge, **use the modern v3.0 workflow** with intelligent task decomposition.

### ✅ Recommended: v3.0 Workflow (Natural Language → Implementation)

**Option 1: Fully integrated (one command)**

```bash
/sdk-bridge:start
```

If you don't have a `feature_list.json`, the command will:
1. Ask how you want to describe your task (text, file, or file with focus)
2. Decompose your description into structured features
3. Show interactive review UI (multi-select to include/exclude features)
4. Validate dependencies and detect cycles
5. Configure execution settings (model, parallel, advanced features)
6. Launch autonomous agent

**Option 2: Decompose first, launch later**

```bash
/sdk-bridge:decompose "Build a REST API for todo list with authentication"
# Reviews features, validates, creates feature_list.json

/sdk-bridge:start
# Detects existing plan, offers to use/edit/replace
```

**After SDK completes:**

```bash
/sdk-bridge:resume   # Comprehensive completion report with file validation
```

**Optional monitoring:**

```bash
/sdk-bridge:watch    # Live progress updates (30 sec polling)
/sdk-bridge:status   # Quick status check
/sdk-bridge:observe  # View agent logs
```

### ⚠️ Legacy: v1.x Workflow (Deprecated)

<details>
<summary>Click to expand legacy workflow (not recommended)</summary>

### 1. Setup Harness (First Time Only)

```bash
/sdk-bridge:lra-setup
```

Installs the bundled `autonomous_agent.py` to `~/.claude/skills/long-running-agent/harness/`.

### 2. Initialize Your Project

```bash
cd my-project
/sdk-bridge:init
```

This creates `.claude/sdk-bridge.local.md` with configuration defaults.

### 3. Create a Plan

```bash
/plan
```

This creates `feature_list.json` with features to implement.

### 4. Hand Off to SDK

```bash
/sdk-bridge:handoff
```

The validator checks prerequisites, then launches the SDK agent in background.

### 5. Monitor Progress

```bash
/sdk-bridge:status
```

Check feature completion, session count, and recent activity.

### 6. Resume When Complete

```bash
/sdk-bridge:resume
```

Review SDK work, see completion report, continue in CLI.

**Note**: This workflow is deprecated. Use `/sdk-bridge:start` instead.

</details>

## Commands

### Primary Commands (v3.0+)
- `/sdk-bridge:start` - **[RECOMMENDED]** Interactive setup with automatic task decomposition & launch
- `/sdk-bridge:decompose` - **[NEW v3.0]** Intelligent task decomposition from natural language
- `/sdk-bridge:watch` - Live progress monitoring with TodoWrite
- `/sdk-bridge:status` - Quick status check
- `/sdk-bridge:plan` - Analyze dependencies for parallel execution
- `/sdk-bridge:enable-parallel` - Enable parallel execution mode
- `/sdk-bridge:observe` - View agent logs
- `/sdk-bridge:approve` - Review pending high-risk operations
- `/sdk-bridge:resume` - Resume in CLI after completion
- `/sdk-bridge:cancel` - Stop running SDK agent

### Legacy Commands (v1.x - Removed in v3.0)
- `/sdk-bridge:init` - ❌ **REMOVED** - Use `/sdk-bridge:start` instead
- `/sdk-bridge:handoff` - ❌ **REMOVED** - Now part of `/sdk-bridge:start`
- `/sdk-bridge:lra-setup` - ❌ **REMOVED** - Auto-installs during `/sdk-bridge:start`

## Configuration

Edit `.claude/sdk-bridge.local.md` to customize:

```markdown
---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 20
reserve_sessions: 2
progress_stall_threshold: 3
auto_handoff_after_plan: false
---
```

## State Files

**Plugin-managed**:
- `.claude/sdk-bridge.local.md` - Configuration
- `.claude/handoff-context.json` - Handoff tracking
- `.claude/sdk-bridge.pid` - Process ID
- `.claude/sdk-bridge.log` - SDK agent logs
- `.claude/sdk_complete.json` - Completion signal

**Harness-managed** (existing):
- `feature_list.json` - Feature tracking
- `claude-progress.txt` - Session memory
- `CLAUDE.md` - Session protocol
- `init.sh` - Bootstrap script

## How It Works

The SDK Bridge plugin bundles a self-contained `autonomous_agent.py` harness with CLI-friendly commands:

1. **Setup**: `/sdk-bridge:lra-setup` installs bundled harness to `~/.claude/skills/`
2. **Handoff**: Validator checks prerequisites → Launch script starts harness in background
3. **SDK runs**: Implements features one per session, commits after each, logs progress
4. **Completion**: SDK creates `.claude/sdk_complete.json` when done
5. **Resume**: Review completion report, continue in CLI

## Workflow Example

```bash
# Day 1: Planning
$ /plan
# Creates feature_list.json with 50 features

$ /sdk-bridge:init
✅ SDK Bridge initialized

$ /sdk-bridge:handoff
✅ Handoff validation passed
🚀 SDK agent launched (PID: 12345)

# Close laptop, agent continues working...

# Day 2: Check progress
$ /sdk-bridge:status
Features: 42 / 50 passing (84%)
Sessions: 15 / 20

# Day 3: SDK completes
$ /sdk-bridge:resume
🎉 SDK completed 48/50 features
2 features remaining, 3 tests failing

# Fix issues manually, continue development
```

## Architecture

```
~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/
├── .claude-plugin/plugin.json      # Manifest
├── commands/                        # Slash commands
│   ├── lra-setup.md                 # Installs bundled harness
│   ├── init.md
│   ├── handoff.md
│   ├── status.md
│   ├── resume.md
│   └── cancel.md
├── agents/                          # Validation agents
│   ├── handoff-validator.md
│   └── completion-reviewer.md
└── scripts/                         # Helper scripts
    ├── autonomous_agent.py          # Bundled harness (self-contained)
    ├── launch-harness.sh
    ├── monitor-progress.sh
    └── parse-state.sh
```

## Migration Guide: v1.x → v2.0

### Quick Summary
- **Old**: `/sdk-bridge:init` + `/sdk-bridge:handoff` (2 commands, manual config)
- **New**: `/sdk-bridge:start` (1 command, interactive UI)

### Why Migrate?
- ✅ 67% fewer commands
- ✅ Interactive configuration (AskUserQuestion)
- ✅ Live progress tracking (TodoWrite)
- ✅ Auto-launch (no separate handoff)

### Deprecated Commands
- `/sdk-bridge:init` → Use `/sdk-bridge:start`
- `/sdk-bridge:handoff` → Included in `/sdk-bridge:start`
- `/sdk-bridge:lra-setup` → Auto-installs during `/sdk-bridge:start`

### When to Use Legacy Commands
- Scripting/automation (init creates config files programmatically)
- CI/CD pipelines (non-interactive environments)
- Advanced users who prefer manual configuration

For most users, `/sdk-bridge:start` is the recommended approach.

## Troubleshooting

**SDK won't start**:
- Check logs: `cat .claude/sdk-bridge.log`
- Verify API key: `echo $ANTHROPIC_API_KEY` or `claude setup-token`
- Verify SDK installed: `python3 -c "import claude_agent_sdk"`

**Progress stalled**:
- Check status: `/sdk-bridge:status`
- View logs: `tail -50 .claude/sdk-bridge.log`
- Feature may be too vague - edit `feature_list.json` to clarify

**Completion not detected**:
- Check for `.claude/sdk_complete.json`
- Check process: `ps aux | grep autonomous_agent`
- View logs to see what happened

## License

MIT

## Author

Built with Claude Code and the Claude Agent SDK.

Based on Anthropic's "Effective harnesses for long-running agents" pattern.
