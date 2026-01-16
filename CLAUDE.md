# CLAUDE.md

**Current Version: v2.0.1** | Last Updated: 2026-01-16

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **Claude Code plugin marketplace** containing the `sdk-bridge` plugin. The plugin bridges Claude Code CLI with the Claude Agent SDK for long-running autonomous development tasks, implementing Anthropic's two-agent harness pattern.

**Key Note**: As of v2.0.1, **SOTA Generative UI transformation is STABLE**. SDK Bridge features intelligent, proactive UX with AskUserQuestion-driven setup, TodoWrite progress tracking, and SessionStart hooks for completion detection. All backend v2.0 phases (hybrid loops, semantic memory, adaptive models, approvals, parallel execution) remain fully functional. **Note**: v2.0.1 removes the broken UserPromptSubmit hook that was blocking operations.

## Critical Learning: Plugin Discovery System

**The Problem We Solved**: Manually placing plugins in `~/.claude/plugins/` doesn't work. Claude Code uses an automatic plugin management system that only recognizes plugins installed through its marketplace mechanism.

**CRITICAL: Command Registration Requirements**: Commands must have the `allowed-tools` field in their YAML frontmatter or they will not appear in Claude Code CLI. Without this field, commands exist in the cache but are not registered in the slash command system.

**How Plugin Discovery Actually Works**:

1. **Marketplace Registration**: Claude Code reads from `~/.claude/plugins/known_marketplaces.json` and `~/.claude/plugins/config.json`
2. **Plugin Installation**: `/plugin install plugin-name@marketplace-name` triggers Claude Code to:
   - Copy plugin to `~/.claude/plugins/cache/[marketplace]/[plugin]/[version]/`
   - Add entry to `~/.claude/plugins/installed_plugins.json`
   - Register commands, agents, and skills for auto-discovery
3. **Component Loading**: On startup, Claude Code scans registered plugins and loads their components
4. **Command Availability**: Slash commands become available as `/namespace:command`

**Key Insights**:
- `installed_plugins.json` is **automatically managed** by Claude Code (don't edit manually)
- Plugins must be in `cache/[marketplace]/[plugin]/[version]/` structure
- All working plugins follow `"plugin-name@marketplace-name"` format
- Manual file placement bypasses the registration system entirely

**Correct Installation Pattern**:
```bash
# Wrong: Manual file placement
mv plugin ~/.claude/plugins/my-plugin  # ❌ Won't be discovered

# Right: Marketplace installation
/plugin marketplace add user/repo      # ✅ Registers marketplace
/plugin install plugin@marketplace     # ✅ Proper installation
```

## Development Commands

### Testing Plugin Locally

```bash
# Add local marketplace (for testing before GitHub push)
/plugin marketplace add ~/.claude/plugins/marketplaces/sdk-bridge-marketplace

# Install plugin
/plugin install sdk-bridge@sdk-bridge-marketplace

# Restart Claude Code to load commands
# Verify: /sdk-bridge:init should appear
```

### Testing After GitHub Push

```bash
# Others can install from GitHub
/plugin marketplace add flight505/sdk-bridge-marketplace
/plugin install sdk-bridge@sdk-bridge-marketplace
```

### Git Operations

```bash
# Commit changes
git add .
git commit -m "description"

# Push to GitHub
git push origin main

# Create release
git tag v1.0.0
git push origin main --tags
```

### Validation

Check plugin manifest structure:
```bash
# Marketplace metadata
cat .claude-plugin/marketplace.json | jq .

# Plugin manifest
cat plugins/sdk-bridge/.claude-plugin/plugin.json | jq .

# Verify directory structure matches marketplace patterns
tree -L 3 -I '.git'
```

## Architecture

### Marketplace Structure

```
sdk-bridge-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace metadata (defines plugin entries)
├── plugins/
│   └── sdk-bridge/               # The actual plugin
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin manifest
│       ├── commands/             # 10 slash commands (lra-setup, init, plan, enable-parallel, handoff, approve, observe, status, resume, cancel)
│       ├── agents/               # 2 validation agents (handoff-validator, completion-reviewer)
│       ├── hooks/                # SessionStart and Stop event handlers
│       ├── scripts/              # Bundled harness + utilities (autonomous_agent.py, launch-harness.sh, etc.)
│       └── skills/               # Comprehensive documentation (SKILL.md + references + examples)
├── .gitignore                    # Git ignore patterns
└── README.md                     # User-facing marketplace documentation
```

**Critical Files**:
- `.claude-plugin/marketplace.json`: Defines all plugins in marketplace, their metadata, and component paths
- `plugins/sdk-bridge/.claude-plugin/plugin.json`: Plugin-specific manifest (minimal, only name required)

### Plugin Component Discovery

Claude Code auto-discovers components from standard directories:

**Auto-Discovery Directories** (relative to plugin root):
- `commands/` - All `.md` files become `/namespace:command` slash commands
- `agents/` - All `.md` files register as subagents
- `skills/` - Subdirectories with `SKILL.md` register as skills
- `hooks/hooks.json` - Event handlers register automatically
- `.mcp.json` - MCP servers start automatically

**Path Reference Rules**:
- In JSON manifests (hooks, MCP): Use `${CLAUDE_PLUGIN_ROOT}`
- In bash scripts: Use absolute paths like `$HOME/.claude/...`
- In markdown commands: Use `${CLAUDE_PLUGIN_ROOT}/scripts/...`
- Never use hardcoded absolute paths or relative paths from working directory

### Key Components

**Commands** (`commands/*.md`):
- Markdown files with YAML frontmatter defining slash commands
- Use `${CLAUDE_PLUGIN_ROOT}` for portable script paths
- Each command orchestrates specific workflow phase (init → handoff → status → resume → cancel)
- Format:
  ```markdown
  ---
  description: "Command description"
  argument-hint: "[optional]"
  ---

  Command implementation instructions...
  ```

**Agents** (`agents/*.md`):
- Specialized subagents invoked by commands for validation and review
- `handoff-validator.md`: Pre-handoff prerequisite checks (8 validation points)
- `completion-reviewer.md`: Post-completion analysis and reporting
- Format similar to commands but with agent-specific frontmatter

**Scripts** (`scripts/`):

*Core Harness Scripts (7 files installed via `/sdk-bridge:lra-setup`)*:

- `autonomous_agent.py` (v1.4.0): Original harness - multi-session loop implementation
  - Uses Claude Agent SDK for programmatic Claude control
  - Reads `feature_list.json`, implements features one by one
  - Updates `passes` field, commits after each feature
  - Creates `sdk_complete.json` on completion

- `hybrid_loop_agent.py` (v2.0 Phase 1): **Default harness** - combines same-session self-healing with multi-session progression
  - Ralph Wiggum pattern: Fast inner loops for simple fixes (no API overhead)
  - Automatically escalates to new session when stuck
  - Reduces costs by up to 60% compared to autonomous_agent.py
  - Used by default in `/sdk-bridge:handoff` command

- `semantic_memory.py` (v2.0 Phase 1): Cross-project learning system
  - SQLite database of past successful implementations
  - Feature similarity matching using TF-IDF
  - Suggests proven solutions from other projects
  - Learns continuously across all user projects

- `model_selector.py` (v2.0 Phase 2): Adaptive Sonnet/Opus routing
  - Complexity analysis (LOC, dependencies, scope)
  - Risk assessment (architectural changes, data migrations, security)
  - Performance tracking (past failures trigger Opus escalation)
  - Cost optimization (Sonnet for 90% of standard work)

- `approval_system.py` (v2.0 Phase 2): Human-in-the-loop workflow
  - Risk assessment for high-impact operations
  - Pauses for database migrations, API changes, architectural refactors
  - Presents alternatives with impact analysis
  - Non-blocking - other features continue while waiting for approval

- `dependency_graph.py` (v2.0 Phase 3): Parallel execution planning
  - Automatic dependency detection (explicit + implicit)
  - Builds directed acyclic graph (DAG) of features
  - Critical path analysis for bottleneck identification
  - Execution level planning for parallel workers

- `parallel_coordinator.py` (v2.0 Phase 3): Multi-worker orchestration
  - Git-isolated workers (separate branches per feature)
  - Concurrent execution of independent features
  - Merge coordination and conflict resolution
  - Progress aggregation and reporting

*Helper Scripts*:

- `launch-harness.sh`: Launches the harness with nohup
  - Reads `.claude/sdk-bridge.local.md` for configuration
  - Parses YAML frontmatter to extract model, max_sessions, advanced feature flags
  - Calculates max_iterations = max_sessions - reserve_sessions
  - Redirects output to `.claude/sdk-bridge.log`
  - Saves PID to `.claude/sdk-bridge.pid`

- `monitor-progress.sh`: Updates handoff-context.json, detects completion

- `parse-state.sh`: Parses and validates JSON state files

**Hooks** (`hooks/hooks.json` + `hooks/scripts/*.sh`):
- SessionStart (prompt-based): Auto-detects completion
  - Checks for `.claude/sdk_complete.json`
  - Notifies user if SDK finished while they were away
  - Rich visual notification with progress bars, session count, completion reason
  - Prompts to run `/sdk-bridge:resume`
- UserPromptSubmit: **REMOVED in v2.0.1** (was causing operation blocking)
  - Originally intended for passive progress monitoring
  - Triggered Claude Code security protocols that blocked all operations
  - Removed until proper implementation available
  - Use `/sdk-bridge:watch` or `/sdk-bridge:status` for progress updates
- Stop (command-based): Logs SDK continues running
  - Reminds user SDK process is still running in background
  - Does NOT kill SDK (intentional - allows background work)

**Skills** (`skills/sdk-bridge-patterns/`):
- SKILL.md: 2800+ line comprehensive guide with progressive disclosure
- references/:
  - state-files.md (complete file lifecycle documentation)
  - configuration.md (all configuration options with examples)
- examples/:
  - workflow-example.md (TaskFlow 3-day build end-to-end)
  - handoff-scenarios.md (10 common scenarios with workflows)

### File-Based State Management

The plugin uses file-based state sharing between CLI and SDK:

**Plugin-Managed Files** (created by sdk-bridge):
- `.claude/sdk-bridge.local.md`: Project configuration with YAML frontmatter
  ```yaml
  ---
  enabled: true
  model: claude-sonnet-4-5-20250929
  max_sessions: 20
  reserve_sessions: 2
  progress_stall_threshold: 3
  auto_handoff_after_plan: false
  ---
  ```
- `.claude/handoff-context.json`: Tracks handoff state, session count, progress
- `.claude/sdk-bridge.pid`: Running process ID (for status/cancel commands)
- `.claude/sdk-bridge.log`: SDK stdout/stderr (tail for recent activity)
- `.claude/sdk_complete.json`: Completion signal from SDK or monitor

**Harness-Managed Files** (from bundled autonomous_agent.py):
- `feature_list.json`: Source of truth for work (only `passes` field updated by SDK)
- `claude-progress.txt`: Session-to-session memory log (SDK appends after each session)
- `CLAUDE.md`: Session protocol and project rules (project-specific, different from this file!)
- `init.sh`: Environment bootstrap script (executed before each SDK session)

**State File Lifecycle**:

**Simplified Workflow (v2.0.0+):**
1. User runs `/sdk-bridge:start` → Auto-detects setup status, installs harness if needed (silent), shows interactive config UI, launches agent
2. User runs `/sdk-bridge:plan` (optional, before start) → creates `feature-graph.json`, `execution-plan.json` for parallel execution
3. SDK runs (parallel or sequential) → updates `feature_list.json`, appends to `claude-progress.txt`, uses semantic memory
4. User runs `/sdk-bridge:approve` (if high-risk operations detected) → reviews and approves pending operations
5. SDK completes → creates `sdk_complete.json` (parallel mode also creates `worker-sessions.json`)
6. User runs `/sdk-bridge:resume` → reads all state files, validates deliverable files exist, generates report, archives completion signal

**Legacy Workflow (v2.0.0 and earlier):**
0. User runs `/sdk-bridge:lra-setup` (first time only) → installs 7 harness scripts to `~/.claude/skills/`
1. User runs `/sdk-bridge:init` → creates `sdk-bridge.local.md` with advanced feature flags and parallel config
2. User runs `/sdk-bridge:plan` (optional) → creates `feature-graph.json`, `execution-plan.json` for parallel execution
3. User runs `/sdk-bridge:enable-parallel` (optional) → sets `enable_parallel_execution: true` in config
4. User runs `/sdk-bridge:handoff` → auto-detects parallel vs sequential mode, creates `handoff-context.json`, `sdk-bridge.pid`, `sdk-bridge.log`
5. SDK runs (parallel or sequential) → updates `feature_list.json`, appends to `claude-progress.txt`, uses semantic memory
6. User runs `/sdk-bridge:approve` (if high-risk operations detected) → reviews and approves pending operations
7. SDK completes → creates `sdk_complete.json` (parallel mode also creates `worker-sessions.json`)
8. User runs `/sdk-bridge:resume` → reads all state files, validates deliverable files exist, generates report, archives completion signal

### Monitoring Progress

SDK Bridge offers **dual monitoring approaches** to fit different workflows:

**Note on Passive Monitoring**: The v2.1.0 UserPromptSubmit hook feature was removed in v2.0.1 due to security protocol conflicts. Use active monitoring methods below instead.

**1. Active Monitoring - For progress tracking**
- **`/sdk-bridge:watch`**: Live updates every 30 seconds
  - **When to use**: When you want dedicated monitoring session
  - **What you see**: Real-time progress with TodoWrite updates, visual progress bars
  - **Behavior**: Blocking - occupies the session until cancelled
  - **Use case**: Final stages, debugging, impatient users 😊

- **`/sdk-bridge:status`**: One-time status check
  - **When to use**: Quick check without blocking
  - **What you see**: Current state, PID, session count, features completed
  - **Behavior**: Non-blocking - returns immediately

- **`/sdk-bridge:observe`**: Tail log file
  - **When to use**: Debugging, want to see SDK's actual work
  - **What you see**: Last 50 lines of `.claude/sdk-bridge.log`
  - **Behavior**: Non-blocking - snapshot of recent activity

**2. Automatic Notifications**
- **SessionStart hook**: Notifies when SDK completes while you're away
  - Rich visual notification with completion stats
  - Prompts to run `/sdk-bridge:resume` for detailed report

**Recommended Workflow**:
1. Start SDK: `/sdk-bridge:start`
2. Work on other tasks
3. Check progress: `/sdk-bridge:status` for quick check
4. If debugging: `/sdk-bridge:observe` to see logs
5. For live updates: `/sdk-bridge:watch` for dedicated monitoring
6. On completion: `/sdk-bridge:resume` for full report

### Integration Points

**Self-Contained Harness**:
- Plugin bundles 7 harness scripts in `scripts/` (v1.4.0 + v2.0 complete set)
- `/sdk-bridge:lra-setup` installs harness scripts manually (required first-time setup)
  - Creates venv + installs `claude-agent-sdk`
  - Installs all 7 scripts to `~/.claude/skills/long-running-agent/harness/`
- Auto-install feature planned for future release
- No external dependencies - plugin is fully self-contained
- `/sdk-bridge:start` **auto-detects execution mode** (v1.9.0+):
  - **Sequential mode** (default): Uses `hybrid_loop_agent.py`
  - **Parallel mode** (if enabled): Uses `parallel_coordinator.py`
  - Detection: Checks `enable_parallel_execution` flag + `execution-plan.json` existence
  - Graceful fallback to sequential if no plan found
- Different CLI args per mode:
  - Sequential: `--max-iterations`, `--max-inner-loops`
  - Parallel: `--max-workers`, `--execution-plan`
  ```bash
  # Sequential mode
  nohup python3 "$HARNESS" \
    --project-dir "$PROJECT_DIR" \
    --model "$MODEL" \
    --max-iterations "$MAX_ITERATIONS" \
    --max-inner-loops "$MAX_INNER" \
    --log-level "$LOG_LEVEL" \
    > "$LOG_FILE" 2>&1 &

  # Parallel mode
  nohup python3 "$HARNESS" \
    --project-dir "$PROJECT_DIR" \
    --model "$MODEL" \
    --max-workers "$MAX_WORKERS" \
    --max-sessions "$MAX_SESSIONS" \
    --execution-plan .claude/execution-plan.json \
    --log-level "$LOG_LEVEL" \
    > "$LOG_FILE" 2>&1 &
  ```

**Agent SDK**:
- Python package: `claude-agent-sdk`
- Harness uses SDK for programmatic Claude control
- Authentication via CLAUDE_CODE_OAUTH_TOKEN (preferred) or ANTHROPIC_API_KEY
- SDK runs in subprocess, continues even if CLI closes

**Claude Code Plugin System**:
- Plugins must be installed via `/plugin install` to register
- Components auto-discovered from standard directories
- Hooks execute automatically on events
- `${CLAUDE_PLUGIN_ROOT}` expands to plugin installation path

## Editing Guidelines

### Manifest Files

When editing `.claude-plugin/marketplace.json`:
- Update `version` for releases (semantic versioning)
- Keep `source` paths relative (`./plugins/sdk-bridge`)
- Maintain arrays for `commands`, `agents`, `skills`
- Use kebab-case for plugin names
- Example:
  ```json
  {
    "plugins": [{
      "name": "sdk-bridge",
      "source": "./plugins/sdk-bridge",
      "version": "1.0.0",
      "commands": ["./commands/init.md", "./commands/handoff.md"],
      "agents": ["./agents/handoff-validator.md"]
    }]
  }
  ```

When editing `plugins/sdk-bridge/.claude-plugin/plugin.json`:
- Keep minimal (only name required, rest optional)
- Version should match marketplace.json
- Don't duplicate component paths here (auto-discovered)

### Commands

Command files follow this pattern:
```markdown
---
description: "Short description"
argument-hint: "[optional]"
allowed-tools: ["Bash", "Read", "Task", "TodoWrite"]
---

# Command Title

Instructions for Claude Code to execute this command.

Use Task tool to invoke agents if needed.
Use Bash tool with ${CLAUDE_PLUGIN_ROOT}/scripts/... for scripts.

Format output with proper success/error messages.
```

**CRITICAL**: The `allowed-tools` field is **required** for commands to be registered. Without it, commands will not appear in Claude Code CLI even if all other configuration is correct.

**Best Practices**:
- Use Task tool for agent invocation
- Use Bash tool for script execution
- Provide clear user feedback
- Handle errors gracefully

### Scripts

All scripts use:
- `set -euo pipefail` for safety (exit on error, undefined vars, pipe failures)
- `${CLAUDE_PLUGIN_ROOT}` in hooks/JSON (expanded by Claude Code)
- Absolute paths like `$HOME/.claude/...` in bash scripts
- Create `.claude/` directory if needed: `mkdir -p .claude`
- Make executable: `chmod +x scripts/*.sh`

**Example Script Structure**:
```bash
#!/bin/bash
set -euo pipefail

# Configuration
CONFIG_FILE=".claude/sdk-bridge.local.md"
LOG_FILE=".claude/sdk-bridge.log"

# Create directories
mkdir -p .claude

# Parse configuration (YAML frontmatter)
if [ -f "$CONFIG_FILE" ]; then
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$CONFIG_FILE")
  MODEL=$(echo "$FRONTMATTER" | grep '^model:' | sed 's/model: *//')
fi

# Execute with proper error handling
if ! command -v python3 &> /dev/null; then
  echo "Error: python3 not found"
  exit 1
fi
```

### Documentation

Skills use progressive disclosure:
- SKILL.md: Complete reference (loaded when skill activates)
- references/: Deep-dive documentation (linked from SKILL.md)
- examples/: Real-world scenarios (linked from SKILL.md)

**Documentation Structure**:
```
skills/skill-name/
├── SKILL.md              # Main entry point (comprehensive guide)
├── references/
│   ├── file-format.md    # Technical specifications
│   └── api-reference.md  # Detailed API docs
└── examples/
    ├── basic-usage.md    # Simple examples
    └── advanced.md       # Complex scenarios
```

## Common Development Patterns

### Adding a New Command

1. Create `commands/new-command.md` with YAML frontmatter
2. Add `./commands/new-command.md` to `marketplace.json` plugins[0].commands array
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

### Adding a New Agent

1. Create `agents/new-agent.md` with agent-specific frontmatter
2. Add `./agents/new-agent.md` to marketplace.json plugins[0].agents array
3. Define agent capabilities, tools, color, model
4. Test: Commands can invoke with Task tool

### Updating Configuration Schema

1. Edit `skills/sdk-bridge-patterns/references/configuration.md`
2. Update `scripts/launch-harness.sh` to parse new fields:
   ```bash
   NEW_FIELD=$(echo "$FRONTMATTER" | grep '^new_field:' | sed 's/new_field: *//' || echo "default")
   ```
3. Document in SKILL.md main guide
4. Add example to configuration.md
5. Update `.claude/sdk-bridge.local.md` template in init command

### Integrating New Execution Mode (Example: Phase 3 Parallel Execution)

This is how Phase 3 parallel execution was integrated in v1.9.0:

1. **Add Config Flags** (init.md):
   ```yaml
   enable_parallel_execution: false
   max_parallel_workers: 3
   ```

2. **Create Enable Command** (enable-parallel.md):
   - Validates execution-plan.json exists
   - Updates config flag to true
   - Shows estimated speedup

3. **Update Handoff Command** (handoff.md):
   - Detect parallel mode: Check flag + plan file existence
   - Choose harness: `parallel_coordinator.py` vs `hybrid_loop_agent.py`
   - Different CLI args per mode
   - Graceful fallback if no plan

4. **Update Manifests**:
   - Add command to marketplace.json
   - Bump version

5. **Test Integration**:
   - Config parsing
   - Mode detection
   - Fallback behavior

### Debugging Plugin Issues

**Commands not appearing**:
```bash
# Check installation
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | keys'

# Verify plugin structure
ls -la ~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/1.0.0/

# Check manifest
cat ~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/1.0.0/.claude-plugin/plugin.json
```

**Hooks not firing**:
```bash
# Verify hooks.json exists
cat plugins/sdk-bridge/hooks/hooks.json | jq .

# Check script permissions
ls -la plugins/sdk-bridge/hooks/scripts/

# Test script manually
bash plugins/sdk-bridge/hooks/scripts/check-sdk-completion.sh
```

**Scripts failing**:
```bash
# Check execute permissions
ls -la plugins/sdk-bridge/scripts/

# Test script directly
bash -x plugins/sdk-bridge/scripts/launch-harness.sh .

# Check CLAUDE_PLUGIN_ROOT expansion
# In command context: ${CLAUDE_PLUGIN_ROOT} expands correctly
# In bash: Use absolute paths instead
```

## Plugin Distribution

**Local Development**:
- Marketplace at `~/.claude/plugins/marketplaces/sdk-bridge-marketplace`
- Install with local path for testing

**GitHub Distribution**:
- Repository: https://github.com/flight505/sdk-bridge-marketplace
- Users install: `/plugin marketplace add flight505/sdk-bridge-marketplace`
- Public, others can discover and install

**Version Management**:

**CRITICAL: Version Synchronization Rule**
- `marketplace.json` → `.metadata.version` MUST match `plugin.json` → `.version`
- `marketplace.json` → `.plugins[].version` (for sdk-bridge) MUST match `plugin.json` → `.version`
- All three version fields must stay in sync at all times

**Automated Check**:
- GitHub Actions workflow `.github/workflows/version-sync-check.yml` runs on every push
- Fails CI if versions don't match
- Comments on PRs with instructions to fix

**Version Bump Process**:
```bash
# 1. Bump plugin version (source of truth)
jq '.version = "X.Y.Z"' plugins/sdk-bridge/.claude-plugin/plugin.json > tmp && mv tmp plugins/sdk-bridge/.claude-plugin/plugin.json

# 2. Sync marketplace.json (both fields)
jq '.metadata.version = "X.Y.Z"' .claude-plugin/marketplace.json > tmp && mv tmp .claude-plugin/marketplace.json
jq '.plugins[] |= if .name == "sdk-bridge" then .version = "X.Y.Z" else . end' .claude-plugin/marketplace.json > tmp && mv tmp .claude-plugin/marketplace.json

# 3. Update documentation versions
# - CLAUDE.md line 3: **Current Version: vX.Y.Z**
# - README.md line 5: **Version X.Y.Z**
# - CONTEXT_sdk-bridge.md line 3: **Version**: X.Y.Z

# 4. Add release notes to version history sections
# - CLAUDE.md ## Recent Releases
# - README.md ## Recent Releases
# - CONTEXT_sdk-bridge.md ## Version History

# 5. Commit changes
git add .
git commit -m "chore: bump version to X.Y.Z

[Brief description of changes]

BREAKING CHANGE: [if any]
"

# 6. Create git tag (triggers notify-marketplace workflow)
git tag vX.Y.Z
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# 7. Push with tags
git push origin main --tags

# 8. Verify CI passes (version-sync-check workflow)

# 9. Users update with
/plugin update sdk-bridge@sdk-bridge-marketplace
```

**Version Numbering (Semantic Versioning)**:
- **MAJOR** (X.0.0): Breaking changes, incompatible API changes
- **MINOR** (X.Y.0): New features, backwards-compatible
- **PATCH** (X.Y.Z): Bug fixes, backwards-compatible

**Why Version Sync Matters**:
- Users installing from marketplace expect consistent versions
- Auto-update systems rely on version matching
- Version mismatches cause support issues and confusion
- Marketplace webhooks trigger on version changes

## Testing Workflow

### Local Testing Before Push

```bash
# 1. Make changes to plugin
vim plugins/sdk-bridge/commands/handoff.md

# 2. Commit changes
git add .
git commit -m "Update handoff command"

# 3. Reinstall locally
/plugin uninstall sdk-bridge@sdk-bridge-marketplace
/plugin install sdk-bridge@sdk-bridge-marketplace

# 4. Restart Claude Code

# 5. Test command
/sdk-bridge:handoff
```

### Testing After GitHub Push

```bash
# 1. Push to GitHub
git push origin main

# 2. In fresh Claude Code instance
/plugin marketplace add flight505/sdk-bridge-marketplace
/plugin install sdk-bridge@sdk-bridge-marketplace

# 3. Verify all commands work
/sdk-bridge:init
/sdk-bridge:handoff
# etc.
```

## Marketplace Pattern Reference

Based on analysis of existing marketplaces (claude-code-workflows):

**Marketplace JSON Structure**:
```json
{
  "name": "marketplace-name",
  "owner": {
    "name": "username",
    "url": "https://github.com/username"
  },
  "metadata": {
    "description": "Marketplace description",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": "./plugins/plugin-name",
      "description": "Plugin description",
      "version": "1.0.0",
      "author": { "name": "...", "url": "..." },
      "repository": "https://github.com/...",
      "license": "MIT",
      "keywords": ["tag1", "tag2"],
      "category": "workflows",
      "strict": false,
      "commands": ["./commands/cmd1.md"],
      "agents": ["./agents/agent1.md"],
      "skills": ["./skills/skill-name"]
    }
  ]
}
```

**Directory Standards**:
- Use kebab-case for all directories and files
- Commands: `command-name.md`
- Agents: `agent-name.md`
- Skills: `skill-name/SKILL.md`
- Scripts: `script-name.sh`

**Path Standards**:
- Relative paths in manifests: `./commands/file.md`
- ${CLAUDE_PLUGIN_ROOT} in hooks and commands
- Absolute paths in bash scripts: `$HOME/.claude/...`

## Recent Releases

### v2.0.1 - Critical Bugfix: Remove Broken Hook (2026-01-16)
- **TYPE**: Critical bugfix release
- **CRITICAL FIX**: Removed UserPromptSubmit hook that blocked all operations
  - Hook triggered Claude Code security protocols requiring explicit user confirmation
  - Every user prompt was blocked until approval granted
  - Root cause: Prompt-based hook interpreted as autonomous action
- **REMOVED**:
  - UserPromptSubmit hook from hooks.json
  - Reference to non-existent monitor-progress.sh from plugin.json
  - Passive monitoring feature (incomplete implementation)
- **IMPACT**: Plugin now works without blocking operations on every prompt
- **WORKAROUND**: Use `/sdk-bridge:watch` or `/sdk-bridge:status` for progress monitoring
- **FILES**: 2 changed (hooks.json, plugin.json)
- **COMMITS**: 8ebe8f2, 327e2d3

### v2.0.0 - SOTA Generative UI Transformation (2026-01-11)
- **MILESTONE**: Major UX overhaul - intelligent, proactive experience
- **NEW Commands**:
  - `/sdk-bridge:start` - Interactive onboarding with AskUserQuestion (model, parallel, features) + TodoWrite progress tracking (replaces /init + /handoff workflow)
  - `/sdk-bridge:watch` - Live progress polling with TodoWrite updates (30 sec, progress bars, simulated "live" experience)
- **ENHANCED Commands**:
  - `/sdk-bridge:resume` - Comprehensive report (+180 lines): executive summary, feature breakdown, ✅/❌ file validation, git commits analysis, speedup calculations, next steps guidance
- **NEW Hooks**:
  - SessionStart (prompt-based) - Rich completion detection with LLM analysis, visual formatting (emojis, progress bars, separators)
- **Architecture**: Commands: 10 → 12 (added start, watch), prompt-based hooks for proactive notifications
- **UX Impact**: 67% reduction in commands to start, live visibility, proactive guidance, no phantom completions
- **Files**: 6 changed, 762 insertions(+), 206 deletions(-)
- **Commits**: f467511

### v1.9.0 - Phase 3 Complete: Parallel Execution (2026-01-11)
- **MILESTONE**: All v2.0 phases (1-3) now fully implemented and functional
- **New Command**: `/sdk-bridge:enable-parallel` - Validates plan and enables parallel mode
- **Enhanced**: `/sdk-bridge:handoff` - Auto-detects parallel vs sequential mode
- **Enhanced**: `/sdk-bridge:init` - Added `enable_parallel_execution` and `max_parallel_workers` flags
- **Feature**: Parallel execution with 2-4x speedup for independent features
- **Feature**: Multi-worker orchestration with git-isolated branches
- **Feature**: Automatic dependency detection and level-based execution
- **Integration**: Seamless fallback to sequential if no execution plan
- **Commands**: 10 total (was 9)
- **Commits**: 1f9c173
- **Files**: 5 changed, 337 insertions(+), 44 deletions(-)

### v1.8.1 - File Validation Fix (2026-01-11)
- **Fix**: Added deliverable file validation to `/sdk-bridge:resume` command
- **Impact**: No more phantom completions - verifies files actually exist in working directory
- **Features**: Shows ✅/❌ status for each file, troubleshooting guidance for missing files
- **Supports**: 15+ file extensions (py, js, ts, md, json, yaml, sh, sql, html, css, etc.)
- **Commit**: 771b804

### v1.8.0 - Command Consolidation (2026-01-11)
- **Change**: Upgraded all commands to v2.0 standard (removed confusing -v2 suffixes)
- **Commands**: handoff-v2.md → handoff.md, plan-v2.md → plan.md
- **Deleted**: Deprecated handoff-v2.md (functionality merged into handoff.md)
- **Impact**: Simplified from 10 to 9 commands for cleaner UX
- **Result**: v2.0 features now THE standard (not alternatives)
- **Commit**: 626fbb0

### v1.7.1 - Installation Fix (2026-01-10)
- **Fix**: Critical bug - now installs all 7 v2.0 scripts (was only installing 1 of 7)
- **Scripts**: autonomous_agent.py, hybrid_loop_agent.py, semantic_memory.py, model_selector.py, approval_system.py, dependency_graph.py, parallel_coordinator.py
- **Added**: Module import validation to verify scripts load correctly
- **Impact**: All advanced features now functional for users
- **Commit**: f7d18af

### v1.7.0 - v2.0 Features (Phases 1-3)
- **Phase 1**: Hybrid loops with same-session self-healing (Ralph Wiggum pattern)
- **Phase 1**: Semantic memory with cross-project learning (SQLite-based)
- **Phase 2**: Adaptive model selection (Sonnet/Opus routing)
- **Phase 2**: Approval workflow for high-risk operations
- **Phase 3**: Parallel execution with dependency graphs
- **Phase 3**: Multi-worker orchestration with git isolation
- **Result**: Complete SOTA autonomous development platform

## Version History Summary

| Version | Date | Type | Key Changes |
|---------|------|------|-------------|
| v2.0.1 | 2026-01-16 | Bugfix | **Critical fix - Removed blocking UserPromptSubmit hook** |
| v2.0.0 | 2026-01-11 | Major | **SOTA Generative UI - Interactive setup, live progress, intelligent UX** |
| v1.9.0 | 2026-01-11 | Major | **Phase 3 complete - Parallel execution fully integrated** |
| v1.8.1 | 2026-01-11 | Bugfix | File validation in resume command |
| v1.8.0 | 2026-01-11 | Major | Command consolidation (remove -v2 suffixes) |
| v1.7.1 | 2026-01-10 | Bugfix | Fix installation (all 7 scripts) |
| v1.7.0 | 2026-01-08 | Major | v2.0 features (Phases 1-2, Phase 3 foundation) |
| v1.6.0 | 2025-12-20 | Feature | Enhanced state management |
| v1.5.0 | 2025-12-15 | Feature | Validation agents |
| v1.4.0 | 2025-12-10 | Major | Core harness implementation |
