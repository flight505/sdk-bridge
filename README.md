# SDK Bridge Marketplace

**Version 1.9.0** - Bridge Claude Code CLI with the Claude Agent SDK for long-running autonomous development tasks.

## Overview

This marketplace provides the **sdk-bridge** plugin, which enables seamless handoff between interactive Claude Code CLI sessions and autonomous Agent SDK execution. Perfect for long-running projects that need to run for hours or days without manual supervision.

**SOTA autonomous development plugin** featuring hybrid loops, semantic memory, parallel execution, adaptive intelligence, and human-in-the-loop approvals.

## Features

### Core Capabilities

- **Autonomous Multi-Session Development**: Hand off to SDK agent that works through features independently
- **Hybrid Loop Pattern**: Combines same-session self-healing with multi-session progression
- **Semantic Memory**: Cross-project learning from past implementations
- **Adaptive Model Selection**: Smart Sonnet/Opus routing based on complexity and risk
- **Parallel Execution**: Dependency-aware parallel feature implementation
- **Approval Workflow**: Human-in-the-loop for high-risk operations (non-blocking)
- **File Validation**: Verifies deliverables actually exist (no phantom completions)

### User Experience

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

### 1. Setup Harness (First Time Only)

```bash
/sdk-bridge:lra-setup
# Installs 7 harness scripts to ~/.claude/skills/
# • autonomous_agent.py (v1.4.0 core)
# • hybrid_loop_agent.py (v2.0 - hybrid loops)
# • semantic_memory.py (cross-project learning)
# • model_selector.py (adaptive Sonnet/Opus routing)
# • approval_system.py (risk assessment & approvals)
# • dependency_graph.py (parallel execution planning)
# • parallel_coordinator.py (multi-worker orchestration)
# Verifies claude-agent-sdk is installed
```

### 2. Create a Plan

```bash
/plan
# Describe your project vision
# Result: feature_list.json with all features
```

### 3. Initialize SDK Bridge

```bash
/sdk-bridge:init
# Creates .claude/sdk-bridge.local.md configuration
# Sets up advanced features (all enabled by default)
```

### 4. Analyze Dependencies (Optional - For Parallel Execution)

```bash
/sdk-bridge:plan
# Analyzes feature dependencies
# Creates parallel execution plan with dependency graph
# Shows estimated speedup from parallelization
```

### 5. Enable Parallel Mode (Optional - If Recommended)

```bash
/sdk-bridge:enable-parallel
# Validates execution plan exists
# Updates config to enable parallel execution
# Shows estimated speedup and next steps
# Enables multi-worker parallel mode
```

### 6. Hand Off to SDK

```bash
/sdk-bridge:handoff
# Validates prerequisites
# Auto-detects parallel vs sequential mode
# Launches SDK agent in background with hybrid loops
# Uses semantic memory for learning from past projects
# Adaptive model selection (Sonnet for standard, Opus for complex/risky)
# Parallel mode: Launches multiple workers with git-isolated branches
# You can close CLI - agent continues working
```

### 7. Monitor Progress (Optional)

```bash
/sdk-bridge:status
# Check current progress
# View session count, feature completion

/sdk-bridge:observe
# Real-time dashboard with live worker status (parallel mode)
# Shows current session, progress bars, recent activity
```

### 8. Approve High-Risk Operations (If Prompted)

```bash
/sdk-bridge:approve
# Review pending operations
# Choose from alternatives or proceed with recommendation
# Non-blocking - other features continue while waiting
```

### 9. Resume When Complete

```bash
/sdk-bridge:resume
# Detailed completion report
# Validates deliverable files actually exist (no phantom completions)
# Review achievements and remaining work
# Shows missing files with troubleshooting guidance
```

## Commands

| Command | Description |
|---------|-------------|
| `/sdk-bridge:lra-setup` | Install 7 harness scripts (first-time setup) |
| `/sdk-bridge:init` | Initialize project for SDK bridge with parallel config |
| `/sdk-bridge:plan` | Analyze dependencies and create parallel execution plan |
| `/sdk-bridge:enable-parallel` | Enable parallel execution mode (after plan) |
| `/sdk-bridge:handoff` | Launch autonomous SDK agent (auto-detects mode) |
| `/sdk-bridge:approve` | Approve pending high-risk operations |
| `/sdk-bridge:observe` | Real-time dashboard with live progress (parallel mode) |
| `/sdk-bridge:status` | Check progress and session count |
| `/sdk-bridge:resume` | Return to CLI with completion report & file validation |
| `/sdk-bridge:cancel` | Stop running SDK agent |

## Advanced Features

All advanced features are **enabled by default** in v1.8.0+. You can disable specific features in `.claude/sdk-bridge.local.md`.

### Hybrid Loops (v2.0 Phase 1)

Combines **same-session self-healing** (Ralph Wiggum pattern) with **multi-session progression**:

- Fast iteration on simple fixes (no API overhead)
- Reduces costs by up to 60%
- Automatically escalates to new session when stuck
- Configurable: `max_inner_loops: 5` (default)

### Semantic Memory (v2.0 Phase 1)

**Cross-project learning** that remembers successful implementations:

- SQLite database of past solutions
- Feature similarity matching
- Suggests proven approaches
- Learns from all your projects
- Disable: `enable_semantic_memory: false`

### Adaptive Model Selection (v2.0 Phase 2)

**Smart Sonnet/Opus routing** based on:

- Feature complexity (LOC, dependencies, scope)
- Risk level (architectural changes, data migrations, security)
- Historical performance (past failures trigger Opus)
- Cost optimization (Sonnet for standard work)
- Disable: `enable_adaptive_models: false`

### Approval Workflow (v2.0 Phase 2)

**Human-in-the-loop** for high-risk operations:

- Pauses for database migrations, API changes, architectural refactors
- Presents alternatives with impact analysis
- Non-blocking - other features continue
- `/sdk-bridge:approve` to review and decide
- Disable: `enable_approval_nodes: false`

### Parallel Execution (v2.0 Phase 3 - COMPLETE)

**Dependency-aware parallel implementation** (fully integrated in v1.9.0):

- Automatic dependency detection (explicit + implicit)
- Git-isolated workers (separate branches per feature)
- Critical path analysis for bottleneck identification
- Estimated speedup calculation (2-4x typical)
- Multi-worker orchestration with automatic merge coordination
- Workflow: `/sdk-bridge:plan` → `/sdk-bridge:enable-parallel` → `/sdk-bridge:handoff`
- Monitor with: `/sdk-bridge:observe` (real-time worker dashboard)

### File Validation (v1.8.1)

**No more phantom completions**:

- Resume command verifies files actually exist
- Shows ✅/❌ status for each deliverable
- Identifies missing files with troubleshooting guidance
- Supports 15+ file extensions

## Use Cases

### Fresh Project Start
Plan comprehensively, hand off, and let SDK build the entire project autonomously over 12-24 hours with hybrid loops for efficiency.

### Feature Batch Implementation
Add new features to existing codebase - SDK integrates cleanly with semantic memory suggesting proven patterns.

### Complex Architectural Changes
Adaptive model selection routes high-risk refactors to Opus, with approval workflow for critical decisions.

### Parallel Feature Development
Use `/sdk-bridge:plan` to analyze dependencies and implement multiple independent features simultaneously.

### Technical Debt Cleanup
Create systematic refactoring checklist and let SDK work through improvements with hybrid loops for fast iteration.

### Bug Fix Marathon
Convert issues to features and let SDK tackle multiple bugs systematically with cross-project learning.

### Overnight Development
Hand off before bed, wake up to completed features and comprehensive reports with file validation.

## Configuration

The plugin creates `.claude/sdk-bridge.local.md` with these settings:

```yaml
---
# v1.4.0 Settings
enabled: true
model: claude-sonnet-4-5-20250929          # Sonnet recommended for standard work
max_sessions: 20                            # Total sessions before stopping
reserve_sessions: 2                         # Sessions for manual recovery
progress_stall_threshold: 3                 # Stop if no progress
auto_handoff_after_plan: false             # Manual handoff control
log_level: INFO
webhook_url:                                # Optional webhook for notifications

# Advanced Features (v2.0) - All enabled by default
enable_v2_features: true                    # Master switch for all advanced features
enable_semantic_memory: true                # Cross-project learning
enable_adaptive_models: true                # Smart Sonnet/Opus routing
enable_approval_nodes: true                 # Human-in-the-loop for high-risk ops
max_inner_loops: 5                          # Same-session retries (hybrid loops)

# Phase 3: Parallel Execution (v1.9.0)
enable_parallel_execution: false            # Opt-in after /plan + /enable-parallel
max_parallel_workers: 3                     # 2-4 recommended for parallel mode
---
```

**Configuration Tips**:

- **Sonnet (default)**: Fast, cost-effective, handles 90% of features
- **Opus**: Automatically selected for complex/risky features if `enable_adaptive_models: true`
- **Hybrid Loops**: Set `max_inner_loops: 3-7` for optimal balance
- **Semantic Memory**: Learns across all projects, improves over time
- **Approvals**: Only for high-risk operations (database, API, architecture)
- **Parallel Execution**: Run `/sdk-bridge:plan` first, then `/sdk-bridge:enable-parallel` if recommended
- **Parallel Workers**: 2-4 workers optimal (each uses API tokens and git branches)

## Architecture

Based on [Anthropic's long-running agent pattern](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents):

### Core Pattern

- **Self-Contained**: Plugin bundles 7 harness scripts - no external dependencies
- **Two-Agent Pattern**: Initializer sets up environment, Coding agent implements features
- **Hybrid Loops**: Same-session iteration + multi-session progression
- **File-Based State**: feature_list.json, claude-progress.txt for session memory
- **Session Protocol**: CLAUDE.md defines project-specific rules
- **Bootstrap Script**: init.sh ensures clean environment each session

### v2.0 Enhancements

- **Hybrid Loop Agent** (`hybrid_loop_agent.py`): Combines fast inner loops with session progression
- **Semantic Memory** (`semantic_memory.py`): SQLite-based cross-project learning
- **Model Selector** (`model_selector.py`): Adaptive Sonnet/Opus routing with performance tracking
- **Approval System** (`approval_system.py`): Risk assessment and human-in-the-loop workflow
- **Dependency Graph** (`dependency_graph.py`): Automatic dependency detection for parallel planning
- **Parallel Coordinator** (`parallel_coordinator.py`): Multi-worker orchestration with git isolation

## Documentation

The plugin includes comprehensive documentation:

- **SKILL.md**: Complete usage guide (2800+ lines)
- **workflow-example.md**: End-to-end example building TaskFlow app
- **handoff-scenarios.md**: 10 common scenarios with workflows
- **state-files.md**: Complete reference for all state files
- **configuration.md**: Detailed configuration guide

## Requirements

- **Claude Code CLI**: Latest version
- **Python**: 3.8+
- **Claude Agent SDK**: Installed automatically during `/sdk-bridge:lra-setup`
- **Git**: Repository recommended for version control
- **API Authentication**: CLAUDE_CODE_OAUTH_TOKEN (preferred) or ANTHROPIC_API_KEY

> **Note**: The plugin is self-contained and bundles all 7 harness scripts. Run `/sdk-bridge:lra-setup` once to install them to your `~/.claude/skills/` directory.

## Recent Releases

### v1.9.0 (Current) - Phase 3 Complete: Parallel Execution 🎉
- **MILESTONE**: All v2.0 phases now fully implemented and functional!
- New command: `/sdk-bridge:enable-parallel` - Enable multi-worker parallel mode
- Enhanced `/sdk-bridge:handoff` - Auto-detects parallel vs sequential mode
- Enhanced `/sdk-bridge:init` - Added parallel execution config flags
- Parallel execution: 2-4x speedup for independent features
- Git-isolated branches per worker (safe parallel execution)
- Automatic dependency detection and level-based execution
- Graceful fallback to sequential if no execution plan
- 10 commands total (was 9)

### v1.8.1 - File Validation Fix
- Added deliverable file validation to resume command
- No more phantom completions - verifies files actually exist
- Clear ✅/❌ status for each deliverable
- Troubleshooting guidance for missing files

### v1.8.0 - Command Consolidation
- Upgraded all commands to v2.0 standard
- Removed confusing -v2 suffixes
- Simplified from 10 to 9 commands
- v2.0 features now THE standard (not alternatives)

### v1.7.1 - Installation Fix
- Fixed critical bug: Now installs all 7 v2.0 scripts
- Was only installing 1 of 7 scripts
- Added module import validation
- All advanced features now functional

### v1.7.0 - v2.0 Features (Phases 1-2 Initial)
- Hybrid loops with same-session self-healing
- Semantic memory with cross-project learning
- Adaptive model selection (Sonnet/Opus routing)
- Approval workflow for high-risk operations
- Dependency graph analysis (Phase 3 foundation)
- Note: Phase 3 parallel execution completed in v1.9.0

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/flight505/sdk-bridge-marketplace).

## License

MIT
