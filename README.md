# SDK Bridge Marketplace

Bridge Claude Code CLI with the Claude Agent SDK for long-running autonomous development tasks.

## Overview

This marketplace provides the **sdk-bridge** plugin, which enables seamless handoff between interactive Claude Code CLI sessions and autonomous Agent SDK execution. Perfect for long-running projects that need to run for hours or days without manual supervision.

## Features

- **Autonomous Multi-Session Development**: Hand off to SDK agent that works through features independently
- **Progress Tracking**: Monitor progress with real-time status updates
- **Graceful Handoff/Resume**: Seamlessly transition between CLI and SDK with full state preservation
- **Validation**: Pre-handoff checks ensure environment is ready
- **Comprehensive Reporting**: Detailed completion reports with achievements, issues, and recommendations
- **File-Based State Management**: Reliable state sharing between CLI and SDK

## Installation

### Step 1: Add Marketplace

```bash
/plugin marketplace add flight505/sdk-bridge-marketplace
```

### Step 2: Install Plugin

```bash
/plugin install sdk-bridge@sdk-bridge-marketplace
```

## Quick Start

### 1. Create a Plan

```bash
/plan
# Describe your project vision
# Result: feature_list.json with all features
```

### 2. Initialize SDK Bridge

```bash
/sdk-bridge:init
# Creates .claude/sdk-bridge.local.md configuration
```

### 3. Hand Off to SDK

```bash
/sdk-bridge:handoff
# Validates prerequisites
# Launches SDK agent in background
# You can close CLI - agent continues working
```

### 4. Monitor Progress (Optional)

```bash
/sdk-bridge:status
# Check current progress
# View session count, feature completion
```

### 5. Resume When Complete

```bash
/sdk-bridge:resume
# Detailed completion report
# Review achievements and remaining work
```

## Commands

- `/sdk-bridge:init` - Initialize project for SDK bridge
- `/sdk-bridge:handoff` - Launch autonomous SDK agent
- `/sdk-bridge:status` - Monitor progress
- `/sdk-bridge:resume` - Return to CLI with completion report
- `/sdk-bridge:cancel` - Stop running SDK agent

## Use Cases

### Fresh Project Start
Plan comprehensively, hand off, and let SDK build the entire project autonomously over 12-24 hours.

### Feature Batch Implementation
Add new features to existing codebase - SDK integrates cleanly with your code.

### Technical Debt Cleanup
Create systematic refactoring checklist and let SDK work through improvements.

### Bug Fix Marathon
Convert issues to features and let SDK tackle multiple bugs systematically.

### Overnight Development
Hand off before bed, wake up to completed features and comprehensive reports.

## Configuration

The plugin creates `.claude/sdk-bridge.local.md` with these settings:

```yaml
enabled: true
model: claude-sonnet-4-5-20250929          # Sonnet recommended
max_sessions: 20                            # Total sessions before stopping
reserve_sessions: 2                         # Sessions for manual recovery
progress_stall_threshold: 3                 # Stop if no progress
auto_handoff_after_plan: false             # Manual handoff control
```

## Architecture

Based on [Anthropic's long-running agent pattern](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents):

- **Two-Agent Pattern**: Initializer sets up environment, Coding agent implements features
- **File-Based State**: feature_list.json, claude-progress.txt for session memory
- **Session Protocol**: CLAUDE.md defines project-specific rules
- **Bootstrap Script**: init.sh ensures clean environment each session

## Documentation

The plugin includes comprehensive documentation:

- **SKILL.md**: Complete usage guide
- **workflow-example.md**: End-to-end example building TaskFlow app
- **handoff-scenarios.md**: 10 common scenarios with workflows
- **state-files.md**: Complete reference for all state files
- **configuration.md**: Detailed configuration guide

## Requirements

- Claude Code CLI
- Claude Agent SDK (`claude-agent-sdk` Python package)
- Git repository (recommended)
- API authentication (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY)

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/flight505/sdk-bridge-marketplace).

## License

MIT
