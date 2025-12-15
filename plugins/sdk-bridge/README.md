# SDK Bridge Plugin

Bridge Claude Code CLI and Agent SDK for seamless hybrid workflows. Hand off long-running tasks to autonomous SDK agents, then resume in CLI when complete.

## Overview

The SDK Bridge plugin transforms the existing long-running-agent harness into a CLI-integrated workflow:

1. **Plan interactively** in CLI (`/plan` creates feature_list.json)
2. **Hand off to SDK** (`/sdk-bridge:handoff` launches autonomous agent)
3. **Monitor progress** (`/sdk-bridge:status` checks feature completion)
4. **Resume in CLI** (`/sdk-bridge:resume` reviews SDK work and continues)

## Installation

The plugin is installed at: `~/.claude/plugins/sdk-bridge/`

Prerequisites:
- Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
- Claude Agent SDK: `pip install claude-agent-sdk`
- Long-running-agent harness: Run `/user:lra-setup` if not already installed

## Quick Start

### 1. Initialize Your Project

```bash
cd my-project
/sdk-bridge:init
```

This creates `.claude/sdk-bridge.local.md` with configuration defaults.

### 2. Create a Plan

```bash
/plan
```

This creates `feature_list.json` with features to implement.

### 3. Hand Off to SDK

```bash
/sdk-bridge:handoff
```

The validator checks prerequisites, then launches the SDK agent in background.

### 4. Monitor Progress

```bash
/sdk-bridge:status
```

Check feature completion, session count, and recent activity.

### 5. Resume When Complete

```bash
/sdk-bridge:resume
```

Review SDK work, see completion report, continue in CLI.

## Commands

- `/sdk-bridge:init` - Initialize project for SDK bridge
- `/sdk-bridge:handoff` - Hand off work to SDK agent
- `/sdk-bridge:status` - Check SDK agent progress
- `/sdk-bridge:resume` - Resume CLI after SDK completes

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

The SDK Bridge plugin wraps the existing `autonomous_agent.py` harness with CLI-friendly commands:

1. **Handoff**: Validator checks prerequisites → Launch script starts harness in background
2. **SDK runs**: Implements features one per session, commits after each, logs progress
3. **Completion**: SDK creates `.claude/sdk_complete.json` when done
4. **Resume**: Review completion report, continue in CLI

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
~/.claude/plugins/sdk-bridge/
├── .claude-plugin/plugin.json      # Manifest
├── commands/                        # Slash commands
│   ├── init.md
│   ├── handoff.md
│   ├── status.md
│   └── resume.md
├── agents/                          # Validation agents
│   └── handoff-validator.md
└── scripts/                         # Helper scripts
    └── launch-harness.sh
```

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
