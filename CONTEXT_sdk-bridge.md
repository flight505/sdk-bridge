# CONTEXT: SDK Bridge Plugin

**Version**: 2.0.0
**Last Updated**: 2026-01-13
**Purpose**: Ground truth architecture and consolidated context for sdk-bridge plugin

This document consolidates critical information from all markdown files for quick developer onboarding.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Plugin Discovery & Installation](#plugin-discovery--installation)
4. [File-Based State Management](#file-based-state-management)
5. [Commands & Workflow](#commands--workflow)
6. [Harness Scripts](#harness-scripts)
7. [Configuration System](#configuration-system)
8. [Monitoring System](#monitoring-system)
9. [Version History](#version-history)
10. [Testing & Validation](#testing--validation)
11. [Development Patterns](#development-patterns)

---

## Overview

SDK Bridge seamlessly bridges Claude Code CLI with the Claude Agent SDK for long-running autonomous development. It implements Anthropic's two-agent harness pattern, enabling hours or days of autonomous work while maintaining CLI integration.

### Core Capabilities

**SOTA Features (v2.0)**:
- **Generative UI**: Interactive setup, live progress, proactive notifications
- **Hybrid Loops** (Phase 1): Same-session self-healing + multi-session progression (60% cost reduction)
- **Semantic Memory** (Phase 1): Cross-project learning from past implementations
- **Adaptive Models** (Phase 2): Smart Sonnet/Opus routing based on complexity/risk
- **Approval Workflow** (Phase 2): Human-in-the-loop for high-risk operations
- **Parallel Execution** (Phase 3): Dependency-aware parallel features (2-4x speedup)
- **File Validation**: Verifies deliverables exist (no phantom completions)

### Use Cases

✅ **Use when**:
- 10+ well-defined features to implement
- Want autonomous progress while away
- Task benefits from multi-session iteration
- Features are testable with clear completion criteria

❌ **Don't use for**:
- Exploratory work (stay in CLI)
- Tasks requiring frequent user input
- Simple single-feature changes
- Iterating on prompts/approaches

---

## Architecture

### Two-Agent Harness Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                      CLI Agent (Claude Code)                │
│  - Interactive commands, user-facing                        │
│  - Validates prerequisites, creates configuration           │
│  - Monitors progress, reviews completion                    │
│  - Uses hooks for proactive notifications                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ File-based communication
                       │ (.claude/*.json, feature_list.json)
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                    SDK Agent (subprocess)                    │
│  - Autonomous execution in background                       │
│  - Multi-session loop with state persistence                │
│  - Advanced features (hybrid loops, memory, parallel)       │
│  - Runs independently (survives CLI close)                  │
└─────────────────────────────────────────────────────────────┘
```

### Plugin Component Structure

```
~/.claude/plugins/cache/[marketplace]/sdk-bridge/[version]/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/                     # 12 slash commands
│   ├── lra-setup.md             # Install harness (manual, v2.0)
│   ├── start.md                 # ⭐ One-command setup (v2.1+)
│   ├── init.md                  # Create config
│   ├── plan.md                  # Dependency analysis
│   ├── enable-parallel.md       # Enable parallel mode
│   ├── handoff.md               # Launch agent (auto-detects mode)
│   ├── approve.md               # Approve high-risk ops
│   ├── watch.md                 # ⭐ Live progress (v2.0)
│   ├── status.md                # Quick status check
│   ├── observe.md               # Tail log file
│   ├── resume.md                # ⭐ Comprehensive report (v2.0)
│   └── cancel.md                # Stop agent
├── agents/                       # 2 validation agents
│   ├── handoff-validator.md     # Pre-handoff checks (8 points)
│   └── completion-reviewer.md   # Post-completion analysis
├── hooks/
│   ├── hooks.json               # Event handler registration
│   └── scripts/
│       └── check-sdk-completion.sh  # SessionStart detection
├── skills/
│   └── sdk-bridge-patterns/     # Comprehensive documentation
│       ├── SKILL.md             # 2800+ line guide
│       ├── references/
│       │   ├── state-files.md   # File lifecycle docs
│       │   └── configuration.md # Config options
│       └── examples/
│           ├── workflow-example.md      # TaskFlow 3-day build
│           └── handoff-scenarios.md     # 10 common scenarios
└── scripts/                      # Bundled harness + helpers
    ├── autonomous_agent.py      # v1.4.0 harness (bundled)
    ├── hybrid_loop_agent.py     # v2.0 harness (bundled)
    ├── semantic_memory.py       # (bundled)
    ├── model_selector.py        # (bundled)
    ├── approval_system.py       # (bundled)
    ├── dependency_graph.py      # (bundled)
    ├── parallel_coordinator.py  # (bundled)
    ├── launch-harness.sh        # Launch wrapper
    ├── monitor-progress.sh      # Progress updater
    └── parse-state.sh           # JSON parser
```

---

## Plugin Discovery & Installation

### Critical Learning: Plugin Discovery System

**The Problem**: Manually placing plugins in `~/.claude/plugins/` doesn't work. Claude Code uses an automatic plugin management system that only recognizes plugins installed through its marketplace mechanism.

**How It Actually Works**:

1. **Marketplace Registration**: Claude Code reads from `~/.claude/plugins/known_marketplaces.json` and `~/.claude/plugins/config.json`
2. **Plugin Installation**: `/plugin install plugin-name@marketplace-name` triggers:
   - Copy plugin to `~/.claude/plugins/cache/[marketplace]/[plugin]/[version]/`
   - Add entry to `~/.claude/plugins/installed_plugins.json` (auto-managed)
   - Register commands, agents, skills for auto-discovery
3. **Component Loading**: On startup, Claude Code scans registered plugins and loads components
4. **Command Availability**: Slash commands become available as `/namespace:command`

**CRITICAL: Command Registration**: Commands MUST have `allowed-tools` field in YAML frontmatter or they won't appear in CLI.

### Installation Methods

**From flight505-marketplace (Recommended)**:
```bash
/plugin marketplace add flight505/flight505-marketplace
/plugin install sdk-bridge@flight505-marketplace
```

**From standalone marketplace**:
```bash
/plugin marketplace add flight505/sdk-bridge-marketplace
/plugin install sdk-bridge@sdk-bridge-marketplace
```

**First-time setup** (v2.0 and earlier):
```bash
/sdk-bridge:lra-setup  # Installs 7 harness scripts
```

**One-command setup** (v2.1+):
```bash
/sdk-bridge:start  # Auto-installs if needed, then launches
```

### Component Auto-Discovery

Claude Code auto-discovers from standard directories:
- `commands/` → All `.md` files become `/namespace:command` slash commands
- `agents/` → All `.md` files register as subagents
- `skills/` → Subdirectories with `SKILL.md` register as skills
- `hooks/hooks.json` → Event handlers register automatically
- `.mcp.json` → MCP servers start automatically

**Path Reference Rules**:
- In JSON manifests (hooks, MCP): Use `${CLAUDE_PLUGIN_ROOT}`
- In bash scripts: Use absolute paths like `$HOME/.claude/...`
- In markdown commands: Use `${CLAUDE_PLUGIN_ROOT}/scripts/...`
- Never use hardcoded absolute paths or relative paths from working directory

---

## File-Based State Management

The plugin uses file-based state sharing between CLI and SDK.

### State File Overview

```
project/
├── feature_list.json          # Source of truth (SDK reads/writes 'passes' field)
├── claude-progress.txt        # Session-to-session memory (SDK appends)
├── CLAUDE.md                  # Session protocol (project-specific, different from plugin CLAUDE.md!)
├── init.sh                    # Environment bootstrap (SDK executes)
└── .claude/
    ├── sdk-bridge.local.md    # Configuration with YAML frontmatter
    ├── handoff-context.json   # Handoff state, session count, progress
    ├── sdk-bridge.pid         # Running process ID
    ├── sdk-bridge.log         # SDK stdout/stderr
    ├── sdk_complete.json      # Completion signal
    ├── feature-graph.json     # Dependency graph (if /plan run)
    ├── execution-plan.json    # Execution levels (if /plan run)
    └── worker-sessions.json   # Parallel worker stats (if parallel mode)
```

### Plugin-Managed Files

**`.claude/sdk-bridge.local.md`**:
- Configuration with YAML frontmatter + markdown content
- Created by `/sdk-bridge:init` or `/sdk-bridge:start`
- Fields: `enabled`, `model`, `max_sessions`, `reserve_sessions`, `enable_v2_features`, `enable_parallel_execution`, etc.
- Committed to git (project-specific config)

**`.claude/handoff-context.json`**:
- Tracks handoff state and progress
- Created by `launch-harness.sh` during handoff
- Fields: `timestamp`, `git_commit`, `features_total`, `features_passing`, `session_count`, `pid`, `model`, `status`
- NOT committed (ephemeral state)

**`.claude/sdk-bridge.pid`**:
- Process ID of running SDK agent
- Used by `/status` and `/cancel` commands
- Deleted on normal completion

**`.claude/sdk-bridge.log`**:
- SDK stdout/stderr output
- Continuously appended during execution
- Useful for debugging with `/observe` or `tail -f`

**`.claude/sdk_complete.json`**:
- Completion signal from SDK or monitor
- Created when SDK finishes or user runs `/cancel`
- Fields: `timestamp`, `reason` (all_features_passing, session_limit_reached, user_cancelled), `sessions_used`, `features_completed`
- Archived by `/resume` command

**`.claude/feature-graph.json`** (if using parallel execution):
- Dependency graph with nodes and edges
- Created by `/sdk-bridge:plan`
- Format: `{"nodes": [...], "edges": [...], "metadata": {...}}`

**`.claude/execution-plan.json`** (if using parallel execution):
- Execution levels for parallel workers
- Created by `/sdk-bridge:plan`
- Format: `{"execution_levels": [[feat1, feat2], [feat3]], "metadata": {...}}`

**`.claude/worker-sessions.json`** (if parallel mode used):
- Worker statistics and session breakdown
- Created by `parallel_coordinator.py`
- Shows per-worker progress and speedup calculations

### Harness-Managed Files

**`feature_list.json`**:
- Source of truth for features
- SDK only updates `passes` field (true/false)
- CLI reads for progress tracking
- Format: `[{"id": "feat-001", "description": "...", "test": "...", "passes": false, "dependencies": [...], "priority": 10}, ...]`

**`claude-progress.txt`**:
- Session-to-session memory log
- SDK appends summary after each session
- Format: Plain text with "=== Session N ===" markers
- Helps SDK remember what was done previously

**`CLAUDE.md`** (project-specific):
- Session protocol and project rules
- Different from plugin's CLAUDE.md
- SDK reads this for project-specific instructions

**`init.sh`**:
- Environment bootstrap script
- SDK executes before each session if present
- Useful for activating venvs, setting env vars

---

## Commands & Workflow

### Simplified Workflow (v2.1+)

```
/sdk-bridge:start
  ↓ Auto-detects if harness installed
  ↓ Silently installs if needed (output → .claude/setup.log)
  ↓ Shows AskUserQuestion menu (model, parallel, features)
  ↓ Creates config + validates + launches

Work on other tasks...
  ↓ UserPromptSubmit hook shows passive progress

[SessionStart hook detects completion]
  ↓ Rich notification with progress bars

/sdk-bridge:resume
  ↓ Comprehensive report with file validation
```

### Legacy Workflow (v2.0 and earlier)

```
/sdk-bridge:lra-setup        # First time: Install 7 harness scripts
/plan                        # Create feature_list.json
/sdk-bridge:init             # Create config
/sdk-bridge:plan             # Optional: Analyze dependencies
/sdk-bridge:enable-parallel  # Optional: Enable parallel mode
/sdk-bridge:handoff          # Launch agent (auto-detects mode)
/sdk-bridge:status           # Check progress
/sdk-bridge:resume           # Review completion
```

### Command Reference

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/sdk-bridge:start` | ⭐ One-command setup + launch (v2.1+) | Primary entry point (replaces init+handoff) |
| `/sdk-bridge:lra-setup` | Install harness scripts manually | First-time setup (v2.0), troubleshooting |
| `/sdk-bridge:init` | Create configuration manually | Custom config before handoff |
| `/sdk-bridge:plan` | Analyze dependencies for parallel | Before enabling parallel mode |
| `/sdk-bridge:enable-parallel` | Enable parallel execution | After running `/plan` |
| `/sdk-bridge:handoff` | Launch agent (auto-detects mode) | Manual launch after custom config |
| `/sdk-bridge:approve` | Review high-risk operations | When SDK pauses for approval |
| `/sdk-bridge:watch` | ⭐ Live progress updates (v2.0) | Dedicated monitoring session |
| `/sdk-bridge:status` | Quick status check | Non-blocking progress check |
| `/sdk-bridge:observe` | Tail log file | Debugging, see SDK's work |
| `/sdk-bridge:resume` | ⭐ Comprehensive report (v2.0) | After completion, get detailed analysis |
| `/sdk-bridge:cancel` | Stop running agent | Emergency stop, change plans |

### Agent Invocation

**handoff-validator**:
- Invoked by `/handoff` and `/start` commands
- Validates 8 prerequisites:
  1. `feature_list.json` exists with failing features
  2. Git repository initialized
  3. Harness scripts installed
  4. Claude Agent SDK installed
  5. No conflicting SDK processes
  6. API authentication configured (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY)
  7. `.claude/` directory writable
  8. Config valid (if exists)
- Returns: Pass/fail with specific error messages

**completion-reviewer**:
- Invoked by `/resume` command
- Post-completion analysis:
  - Parses completion signal
  - Analyzes feature progress
  - Reviews git commits
  - Validates deliverable files (✅/❌ per file)
  - Calculates speedup (if parallel mode)
  - Identifies issues in logs
  - Generates comprehensive report
- Returns: Executive summary, feature breakdown, next steps

---

## Harness Scripts

SDK Bridge bundles 7 harness scripts installed to `~/.claude/skills/long-running-agent/harness/`:

### 1. autonomous_agent.py (v1.4.0)

**Original harness** - multi-session loop implementation.

**Features**:
- Reads `feature_list.json`, implements features one by one
- Updates `passes` field, commits after each feature
- Creates `sdk_complete.json` on completion
- Session-to-session memory via `claude-progress.txt`

**When used**: Default for v1.4.0, or when v2 features disabled

**Launch**: Via `launch-harness.sh` with `--max-iterations` flag

### 2. hybrid_loop_agent.py (v2.0 Phase 1)

**Default v2.0 harness** - combines same-session self-healing with multi-session progression.

**Features**:
- **Ralph Wiggum pattern**: Fast inner loops for simple fixes (no API overhead)
- Automatically escalates to new session when stuck
- Reduces costs by up to 60% compared to autonomous_agent.py
- Same-session retries before giving up

**When used**: Default when `enable_v2_features: true` in config

**Launch**: Via `launch-harness.sh` with `--max-iterations` and `--max-inner-loops` flags

**Key difference**: Tries multiple times within same session before starting new session

### 3. semantic_memory.py (v2.0 Phase 1)

**Cross-project learning system**.

**Features**:
- SQLite database of past successful implementations
- Feature similarity matching using TF-IDF
- Suggests proven solutions from other projects
- Learns continuously across all user projects

**When used**: When `enable_semantic_memory: true` in config

**Database location**: `~/.claude/semantic_memory.db`

**Integration**: Called by harness before implementing feature

### 4. model_selector.py (v2.0 Phase 2)

**Adaptive Sonnet/Opus routing**.

**Features**:
- Complexity analysis (LOC, dependencies, scope)
- Risk assessment (architectural changes, data migrations, security)
- Performance tracking (past failures trigger Opus escalation)
- Cost optimization (Sonnet for 90% of standard work)

**When used**: When `enable_adaptive_models: true` in config

**Decision logic**:
- Sonnet: Standard features, CRUD, repetitive patterns
- Opus: Complex refactoring, architectural changes, novel algorithms, retry failures

**Integration**: Called by harness before each feature to select model

### 5. approval_system.py (v2.0 Phase 2)

**Human-in-the-loop workflow**.

**Features**:
- Risk assessment for high-impact operations
- Pauses for database migrations, API changes, architectural refactors
- Presents alternatives with impact analysis
- Non-blocking (other features continue while waiting)

**When used**: When `enable_approval_nodes: true` in config

**Triggers**:
- Database schema changes
- Breaking API changes
- Security-sensitive operations
- Major architectural refactors

**Workflow**:
1. SDK detects high-risk operation
2. Creates `.claude/pending-approval.json`
3. Pauses that feature
4. Continues with other features (non-blocking)
5. User runs `/sdk-bridge:approve`
6. SDK resumes approved feature

### 6. dependency_graph.py (v2.0 Phase 3)

**Parallel execution planning**.

**Features**:
- Automatic dependency detection (explicit via `dependencies` field + implicit via code analysis)
- Builds directed acyclic graph (DAG) of features
- Critical path analysis for bottleneck identification
- Execution level planning for parallel workers

**When used**: Called by `/sdk-bridge:plan` command

**Output**: Creates `.claude/feature-graph.json` and `.claude/execution-plan.json`

**Graph structure**:
- **Nodes**: Features with metadata
- **Edges**: Dependencies between features
- **Levels**: Groups of features that can run in parallel

### 7. parallel_coordinator.py (v2.0 Phase 3)

**Multi-worker orchestration**.

**Features**:
- Git-isolated workers (separate branches per feature)
- Concurrent execution of independent features
- Merge coordination and conflict resolution
- Progress aggregation and reporting
- 2-4x speedup for projects with independent features

**When used**: When `enable_parallel_execution: true` and execution plan exists

**Launch**: Via `launch-harness.sh` with `--max-workers`, `--max-sessions`, `--execution-plan` flags

**Workflow**:
1. Creates `feature/worker-N` branches for each worker
2. Assigns features from execution levels to workers
3. Workers execute concurrently
4. Coordinator merges completed features to main
5. Handles conflicts with smart merge strategy
6. Creates `.claude/worker-sessions.json` on completion

---

## Configuration System

Configuration stored in `.claude/sdk-bridge.local.md` with YAML frontmatter:

### Basic Settings

```yaml
---
enabled: true
model: claude-sonnet-4-5-20250929  # or claude-opus-4-5-20251101
max_sessions: 20
reserve_sessions: 2
log_level: INFO
progress_stall_threshold: 3
auto_handoff_after_plan: false
---
```

### v2.0 Advanced Features

```yaml
# Phase 1: Hybrid Loops + Semantic Memory
enable_v2_features: true
enable_semantic_memory: true
max_inner_loops: 5  # Same-session retries

# Phase 2: Adaptive Models + Approvals
enable_adaptive_models: true
enable_approval_nodes: true

# Phase 3: Parallel Execution
enable_parallel_execution: false  # Enable via /enable-parallel after /plan
max_parallel_workers: 3
```

### Configuration Parsing

**launch-harness.sh** parses YAML frontmatter:

```bash
# Extract frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$CONFIG_FILE")

# Parse fields
MODEL=$(echo "$FRONTMATTER" | grep '^model:' | sed 's/model: *//')
MAX_SESSIONS=$(echo "$FRONTMATTER" | grep '^max_sessions:' | sed 's/max_sessions: *//')
ENABLE_V2=$(echo "$FRONTMATTER" | grep '^enable_v2_features:' | sed 's/enable_v2_features: *//')
```

### Model Selection

| Model | Speed | Capability | Cost | Best For |
|-------|-------|------------|------|----------|
| Haiku | Fast | Good | Low | Simple features, repetitive tasks |
| Sonnet | Medium | Very Good | Medium | Most projects (recommended) |
| Opus | Slow | Excellent | High | Complex features, creative work |

**Recommendation**: Start with Sonnet, enable adaptive models for automatic Opus escalation on complex features.

---

## Monitoring System

SDK Bridge offers **dual monitoring approaches**:

### 1. Passive Monitoring (v2.1+) - Recommended

**How it works**: UserPromptSubmit hook shows lightweight progress on every user prompt

**When to use**: Monitor progress while working on other tasks

**What you see**:
```
🔄 SDK Bridge: 3/5 features complete (60%) | Session 12/20 | Mode: sequential
```

**Benefits**:
- Non-blocking - continue working in same session
- Automatic - no command needed
- Concise - 1-2 lines, minimal distraction
- Smart - only shows when SDK is actually running

**Implementation**: Prompt-based hook, no bash script needed

### 2. Active Monitoring

**`/sdk-bridge:watch`** (v2.0):
- Live updates every 30 seconds
- TodoWrite progress tracking
- Visual progress bars
- Blocking - occupies the session

**`/sdk-bridge:status`**:
- One-time status check
- Current state, PID, session count, features completed
- Non-blocking - returns immediately

**`/sdk-bridge:observe`**:
- Tail log file (last 50 lines)
- See SDK's actual work
- Non-blocking - snapshot

### 3. Automatic Notifications

**SessionStart hook** (v2.0):
- Detects `.claude/sdk_complete.json` on session start
- Rich visual notification with:
  - Progress bars
  - Completion reason
  - Session count
  - Speedup calculations (if parallel)
- Prompts to run `/sdk-bridge:resume`

**UserPromptSubmit hook** (v2.1+):
- **Dual functionality**:
  1. Shows passive progress (if SDK running)
  2. Provides context-aware help for SDK Bridge questions
- Detects questions about status, errors, cancellation
- Suggests relevant commands

### Recommended Monitoring Workflow

1. Start SDK: `/sdk-bridge:start`
2. Work on other tasks - passive progress shows automatically
3. If curious: `/sdk-bridge:status` for quick check
4. If debugging: `/sdk-bridge:observe` to see logs
5. If impatient: `/sdk-bridge:watch` for live updates
6. On completion: `/sdk-bridge:resume` for full report

---

## Version History

### v2.1.0 (In Progress) - One-Command Setup + Passive Monitoring (2026-01-11)

**Milestone**: Zero-friction startup + work-while-monitoring UX

**Changes**:
- Enhanced `/sdk-bridge:start` command:
  - Auto-detects setup status via `.version` file
  - Silent background installation (output → `.claude/setup.log`)
  - Version tracking (compares plugin v2.1.0 vs installed)
  - Clean UI - TodoWrite + AskUserQuestion only
  - Auto-updates harness when plugin version changes
  - Idempotent (safe to run multiple times)
- NEW: Passive monitoring via UserPromptSubmit hook
  - Shows progress on every user prompt
  - Non-blocking, minimal distraction
  - Complements `/watch` (passive vs active)
- Legacy: `/sdk-bridge:lra-setup` still available

**UX Impact**:
- Setup: 2 commands → 1 command (50% reduction)
- Monitoring: No longer need `/watch` to track progress
- Workflow: Start SDK, work on other tasks, auto-notified

### v2.0.0 - SOTA Generative UI Transformation (2026-01-11)

**Milestone**: Major UX overhaul - intelligent, proactive experience

**NEW Commands**:
- `/sdk-bridge:start`: Interactive onboarding with AskUserQuestion + TodoWrite
- `/sdk-bridge:watch`: Live progress polling (30 sec) with visual updates

**ENHANCED Commands**:
- `/sdk-bridge:resume`: Comprehensive report (+180 lines) with file validation, git analysis, speedup calculations

**NEW Hooks**:
- SessionStart (prompt-based): Rich completion detection with LLM analysis
- UserPromptSubmit: Context-aware help for natural questions

**UX Impact**:
- 67% reduction in commands to start
- Live visibility during execution
- Proactive guidance and notifications
- No phantom completions (file validation)

**Files**: 6 changed, 762 insertions(+), 206 deletions(-)

### v1.9.0 - Phase 3 Complete: Parallel Execution (2026-01-11)

**Milestone**: All v2.0 phases (1-3) fully implemented

**NEW Command**: `/sdk-bridge:enable-parallel`

**ENHANCED**:
- `/sdk-bridge:handoff`: Auto-detects parallel vs sequential mode
- `/sdk-bridge:init`: Added parallel config flags

**Features**:
- Parallel execution with 2-4x speedup
- Multi-worker orchestration with git isolation
- Automatic dependency detection
- Level-based execution
- Seamless fallback to sequential

**Files**: 5 changed, 337 insertions(+), 44 deletions(-)

### v1.8.1 - File Validation Fix (2026-01-11)

**Fix**: Added deliverable file validation to `/sdk-bridge:resume`

**Features**:
- Shows ✅/❌ status for each file
- Troubleshooting guidance for missing files
- Supports 15+ file extensions

### v1.8.0 - Command Consolidation (2026-01-11)

**Change**: Upgraded all commands to v2.0 standard (removed -v2 suffixes)

**Deleted**: Deprecated handoff-v2.md (merged into handoff.md)

**Impact**: Simplified from 10 to 9 commands

### v1.7.1 - Installation Fix (2026-01-10)

**Fix**: Now installs all 7 v2.0 scripts (was only installing 1)

**Added**: Module import validation

### v1.7.0 - v2.0 Features (Phases 1-3) (2026-01-08)

**Phase 1**: Hybrid loops + semantic memory
**Phase 2**: Adaptive models + approval workflow
**Phase 3**: Parallel execution + dependency graphs

**Result**: Complete SOTA autonomous development platform

### v1.4.0-1.6.0 - Foundation (2025)

- v1.4.0: Core harness implementation
- v1.5.0: Validation agents
- v1.6.0: Enhanced state management

---

## Testing & Validation

### Test Suite

Located in `/tests/` directory:

```
tests/
├── README.md                     # Test suite docs
├── test_installation.sh          # ✅ 7/7 scripts installed
├── test_sdk.sh                   # ✅ SDK v0.1.18 working
├── test_command_consolidation.sh # ⚠️ Duplicate commands
├── verify_file_creation.sh       # Filesystem validation
├── verify_git_commits.sh         # Git commit validation
└── verify_expected_files.sh      # Feature→file mapping
```

### Current Test Status

| Test | Status | Result |
|------|--------|--------|
| Installation (7 scripts) | ✅ PASS | All files present |
| SDK functional | ✅ PASS | v0.1.18 working |
| Command consolidation | ⚠️ WARNING | handoff + handoff-v2 duplicates |
| File creation | ⏸️ PENDING | Requires integration test |
| Git commits | ⏸️ PENDING | Requires integration test |

### Known Issues

1. **Command Duplication**: Both `handoff.md` and `handoff-v2.md` exist (causes confusion)
2. **Integration Testing Gap**: End-to-end validation not yet run

### Testing Documents

- **TESTING_STRATEGY.md** (47KB): Complete testing strategy, 9 test categories
- **TEST_RESULTS.md** (8.4KB): Current test execution results
- **TESTING_SUMMARY.md** (13KB): Overview, key findings, recommendations
- **QUICK_TEST_GUIDE.md** (10KB): Copy-paste commands for rapid testing

---

## Development Patterns

### Adding a New Command

1. Create `commands/new-command.md` with YAML frontmatter (must include `allowed-tools` field)
2. Add `./commands/new-command.md` to marketplace.json
3. Implement command logic (invoke agents, run scripts)
4. Test locally:
   ```bash
   /plugin uninstall sdk-bridge@sdk-bridge-marketplace
   /plugin install sdk-bridge@sdk-bridge-marketplace
   # Restart Claude Code
   # Verify: /sdk-bridge:new-command appears
   ```

### Adding a New Script

1. Create `scripts/new-script.sh` with `#!/bin/bash` and `set -euo pipefail`
2. Make executable: `chmod +x scripts/new-script.sh`
3. Reference in commands: `${CLAUDE_PLUGIN_ROOT}/scripts/new-script.sh`
4. Test: commands can execute script with proper permissions
5. Commit with execute bit: `git add --chmod=+x scripts/new-script.sh`

### Updating Configuration Schema

1. Edit `skills/sdk-bridge-patterns/references/configuration.md`
2. Update `scripts/launch-harness.sh` to parse new fields
3. Document in SKILL.md
4. Add example to configuration.md
5. Update `.claude/sdk-bridge.local.md` template in init command

### Integrating New Execution Mode

Example: How Phase 3 parallel execution was integrated in v1.9.0:

1. **Add config flags** (`init.md`): `enable_parallel_execution`, `max_parallel_workers`
2. **Create enable command** (`enable-parallel.md`): Validates plan exists, updates config
3. **Update handoff command** (`handoff.md`): Detect mode, choose harness, different CLI args
4. **Update manifests**: Add command to marketplace.json, bump version
5. **Test integration**: Config parsing, mode detection, fallback behavior

### Debugging Plugin Issues

**Commands not appearing**:
```bash
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | keys'
ls -la ~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/1.0.0/
```

**Hooks not firing**:
```bash
cat plugins/sdk-bridge/hooks/hooks.json | jq .
ls -la plugins/sdk-bridge/hooks/scripts/
```

**Scripts failing**:
```bash
ls -la plugins/sdk-bridge/scripts/
bash -x plugins/sdk-bridge/scripts/launch-harness.sh .
```

---

## Critical Integration Points

### Self-Contained Harness

- Plugin bundles 7 harness scripts in `scripts/`
- `/sdk-bridge:start` auto-installs harness if needed (v2.1+):
  - Silent background installation
  - Version checking via `.version` file
  - Auto-updates when plugin version changes
  - Creates venv + installs `claude-agent-sdk`
  - Installs all 7 scripts to `~/.claude/skills/long-running-agent/harness/`
- `/sdk-bridge:lra-setup` still available for manual installation
- No external dependencies - fully self-contained

### Agent SDK Integration

- Python package: `claude-agent-sdk`
- Harness uses SDK for programmatic Claude control
- Authentication: CLAUDE_CODE_OAUTH_TOKEN (preferred) or ANTHROPIC_API_KEY
- SDK runs in subprocess, survives CLI close

### Claude Code Plugin System

- Plugins must be installed via `/plugin install` to register
- Components auto-discovered from standard directories
- Hooks execute automatically on events
- `${CLAUDE_PLUGIN_ROOT}` expands to plugin installation path

---

## Quick Reference

### Directory Locations

```bash
# Plugin installation
~/.claude/plugins/cache/[marketplace]/sdk-bridge/[version]/

# Harness scripts
~/.claude/skills/long-running-agent/harness/

# Project state files
.claude/

# Semantic memory database
~/.claude/semantic_memory.db
```

### Key Commands Summary

```bash
# Setup (first time)
/sdk-bridge:start  # v2.1+ (auto-installs, interactive setup)

# Legacy setup
/sdk-bridge:lra-setup  # Install harness manually
/sdk-bridge:init       # Create config

# Execution
/plan                        # Create feature_list.json
/sdk-bridge:plan             # Analyze dependencies (optional)
/sdk-bridge:enable-parallel  # Enable parallel mode (optional)
/sdk-bridge:handoff          # Launch agent (or use /start)

# Monitoring
/sdk-bridge:watch   # Live updates (blocking)
/sdk-bridge:status  # Quick check (non-blocking)
/sdk-bridge:observe # Tail logs

# Completion
/sdk-bridge:resume  # Comprehensive report
/sdk-bridge:cancel  # Emergency stop
```

### State File Lifecycle

```
Init → Plan → Handoff → Execute → Complete → Resume
  ↓      ↓       ↓         ↓          ↓         ↓
config  graph  context   progress  complete  archive
        plan   pid       updates   signal    report
               log
```

---

## Documentation Structure

### Core Documentation

- **CLAUDE.md** (33KB): Developer instructions, architecture, patterns
- **README.md** (14KB): Public-facing documentation, features, quick start
- **CONTEXT_sdk-bridge.md** (this file): Consolidated ground truth

### Installation & Testing

- **INSTALLATION.md** (6.2KB): Installation guide, troubleshooting
- **TESTING_STRATEGY.md** (47KB): Complete testing strategy
- **TEST_RESULTS.md** (8.4KB): Test execution results
- **TESTING_SUMMARY.md** (13KB): Testing overview
- **QUICK_TEST_GUIDE.md** (10KB): Rapid testing commands

### Skills & References

- **SKILL.md** (2800+ lines): Comprehensive usage guide
- **state-files.md**: File lifecycle documentation
- **configuration.md**: Config options with examples
- **workflow-example.md**: TaskFlow 3-day build end-to-end
- **handoff-scenarios.md**: 10 common scenarios with workflows

---

## Support & Resources

- **Repository**: https://github.com/flight505/sdk-bridge-marketplace
- **Issues**: https://github.com/flight505/sdk-bridge-marketplace/issues
- **Author**: Jesper Vang (@flight505)
- **License**: MIT

---

**Last Updated**: 2026-01-13
**Consolidated from**: 29 markdown files
**Purpose**: Quick developer onboarding and architectural reference
