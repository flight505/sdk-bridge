# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **Claude Code plugin marketplace** containing the `sdk-bridge` plugin. The plugin bridges Claude Code CLI with the Claude Agent SDK for long-running autonomous development tasks, implementing Anthropic's two-agent harness pattern.

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
│       ├── commands/             # 5 slash commands (init, handoff, status, resume, cancel)
│       ├── agents/               # 2 validation agents (handoff-validator, completion-reviewer)
│       ├── hooks/                # SessionStart and Stop event handlers
│       ├── scripts/              # Bash utilities (launch-harness.sh, monitor-progress.sh, parse-state.sh)
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

**Scripts** (`scripts/*.sh`):
- `launch-harness.sh`: Launches `~/.claude/skills/long-running-agent/harness/autonomous_agent.py` with nohup
  - Reads `.claude/sdk-bridge.local.md` for configuration
  - Parses YAML frontmatter to extract model, max_sessions
  - Calculates max_iterations = max_sessions - reserve_sessions
  - Redirects output to `.claude/sdk-bridge.log`
  - Saves PID to `.claude/sdk-bridge.pid`
- `monitor-progress.sh`: Updates handoff-context.json, detects completion
- `parse-state.sh`: Parses and validates JSON state files

**Hooks** (`hooks/hooks.json` + `hooks/scripts/*.sh`):
- SessionStart: Auto-detects completion via `check-sdk-completion.sh`
  - Checks for `.claude/sdk_complete.json`
  - Notifies user if SDK finished while they were away
  - Prompts to run `/sdk-bridge:resume`
- Stop: Logs SDK continues running via `cleanup-on-stop.sh`
  - Reminds user SDK process is still running
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

**Harness-Managed Files** (from long-running-agent skill):
- `feature_list.json`: Source of truth for work (only `passes` field updated by SDK)
- `claude-progress.txt`: Session-to-session memory log (SDK appends after each session)
- `CLAUDE.md`: Session protocol and project rules (project-specific, different from this file!)
- `init.sh`: Environment bootstrap script (executed before each SDK session)

**State File Lifecycle**:
1. User runs `/sdk-bridge:init` → creates `sdk-bridge.local.md`
2. User runs `/sdk-bridge:handoff` → creates `handoff-context.json`, `sdk-bridge.pid`, `sdk-bridge.log`
3. SDK runs → updates `feature_list.json`, appends to `claude-progress.txt`
4. SDK completes → creates `sdk_complete.json`
5. User runs `/sdk-bridge:resume` → reads all state files, generates report, archives completion signal

### Integration Points

**Harness Dependency**:
- Requires `~/.claude/skills/long-running-agent/harness/autonomous_agent.py`
- Plugin wraps existing harness, doesn't reimplement
- `launch-harness.sh` translates plugin config to harness CLI args:
  ```bash
  nohup python3 "$HARNESS" \
    --project-dir "$PROJECT_DIR" \
    --model "$MODEL" \
    --max-iterations "$MAX_ITERATIONS" \
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

**Version Updates**:
```bash
# 1. Update version in both manifests
vim .claude-plugin/marketplace.json  # Update metadata.version
vim plugins/sdk-bridge/.claude-plugin/plugin.json  # Update version

# 2. Commit changes
git add .
git commit -m "Release v1.x.x: description of changes"

# 3. Create git tag
git tag v1.x.x
git tag -a v1.x.x -m "Release v1.x.x"

# 4. Push with tags
git push origin main --tags

# 5. Users update with
/plugin update sdk-bridge@sdk-bridge-marketplace
```

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
