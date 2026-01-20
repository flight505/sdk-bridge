# CLAUDE.md

**Version 4.0.0** | Last Updated: 2026-01-19

Developer instructions for working with the SDK Bridge plugin for Claude Code CLI.

---

## Overview

SDK Bridge is an **interactive autonomous development assistant**. It provides a single command (`/sdk-bridge:start`) that guides users through:
1. Describing their feature/project
2. Generating a detailed PRD
3. Converting to execution format
4. Running a fresh Claude agent loop until complete

**Key Philosophy:** Radical simplicity. One command, interactive wizard, fresh Claude instances each iteration.

---

## Authentication

SDK Bridge supports two authentication methods with intelligent fallback:

**1. OAuth Token (Recommended for Max subscribers)**
- Long-lived (1 year validity)
- Higher rate limits
- Better for autonomous workflows

**2. API Key (Fallback)**
- Works for all API users
- Standard rate limits
- May require monthly top-ups

The `sdk-bridge.sh` script automatically:
- Prioritizes `CLAUDE_CODE_OAUTH_TOKEN` if available (and unsets API keys)
- Falls back to `ANTHROPIC_API_KEY` if OAuth not configured
- Provides clear setup instructions if neither exists

**OAuth Setup (Max subscribers):**
```bash
# Generate OAuth token (valid for 1 year)
claude setup-token

# Copy the token and add to ~/.zshrc or ~/.zsh_secrets
export CLAUDE_CODE_OAUTH_TOKEN='your-token'

# Reload shell
source ~/.zshrc
```

**API Key Setup (Alternative):**
```bash
# Get API key from: https://console.anthropic.com/settings/keys
export ANTHROPIC_API_KEY='your-key'
```

---

## Architecture

### High-Level Structure

```
sdk-bridge-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace metadata
└── plugins/
    └── sdk-bridge/               # The actual plugin
        ├── .claude-plugin/
        │   └── plugin.json       # Plugin manifest
        ├── commands/
        │   └── start.md          # Single command - interactive wizard
        ├── skills/
        │   ├── prd-generator/    # PRD creation with clarifying questions
        │   │   └── SKILL.md
        │   └── prd-converter/    # Markdown → JSON converter
        │       └── SKILL.md
        └── scripts/
            ├── sdk-bridge.sh     # Main bash loop
            ├── prompt.md         # Instructions for each Amp iteration
            ├── check-deps.sh     # Dependency checker
            └── prd.json.example  # Reference format
```

### Component Roles

**Commands (`commands/start.md`):**
- Single entry point for all functionality
- Orchestrates 7-checkpoint interactive workflow
- Uses AskUserQuestion for user input
- Invokes skills via Task tool
- Launches bash scripts via Bash tool

**Skills (`skills/*/SKILL.md`):**
- `prd-generator`: Creates detailed PRDs with clarifying questions
- `prd-converter`: Transforms markdown PRD to prd.json format

**Scripts (`scripts/*.sh`, `scripts/*.md`):**
- `sdk-bridge.sh`: Main loop - runs fresh Claude instances repeatedly until complete
- `prompt.md`: Instructions given to each Claude agent instance
- `check-deps.sh`: Validates claude CLI and jq are installed
- `prd.json.example`: Reference format for users

### State Files (in user's project)

```
project/
├── .claude/
│   ├── sdk-bridge.local.md       # Config (YAML frontmatter)
│   ├── sdk-bridge.pid            # PID if running in background
│   └── sdk-bridge.log            # Output log if background
├── tasks/
│   └── prd-feature-name.md       # Human-readable PRD
├── prd.json                       # Execution format (source of truth)
├── progress.txt                   # Learnings log (append-only)
└── archive/                       # Previous runs
    └── YYYY-MM-DD-feature-name/
```

---

## How It Works

### The 7-Checkpoint Flow

**Checkpoint 1: Dependency Check**
- Run `check-deps.sh` to verify claude CLI and jq installed
- If missing, ask user permission to auto-install
- Exit gracefully if user declines

**Checkpoint 2: Project Input**
- AskUserQuestion with text field
- Supports `@file` references for specs/outlines
- Stores user input for PRD generation

**Checkpoint 3: Generate PRD**
- Load `prd-generator` skill via Task tool
- Skill asks 3-5 clarifying questions (lettered options)
- Generates structured markdown PRD
- Saves to `tasks/prd-[feature-name].md`

**Checkpoint 4: Review PRD**
- Detect and open user's editor (`code` or `cursor`)
- AskUserQuestion: "Approved / Need edits / Start over"
- Wait for user confirmation after edits

**Checkpoint 5: Convert to JSON**
- Load `prd-converter` skill via Task tool
- Converts markdown PRD → `prd.json`
- Validates structure (IDs, priorities, criteria)

**Checkpoint 6: Execution Settings**
- AskUserQuestion for max_iterations and execution mode
- Create `.claude/sdk-bridge.local.md` with settings

**Checkpoint 7: Launch**
- Launch `sdk-bridge.sh` (foreground or background)
- Monitor progress and display status

### The Execution Loop (sdk-bridge.sh)

Bash script that spawns fresh Claude agent instances:

```bash
for i in 1 to MAX_ITERATIONS:
  1. Run: claude -p "$(cat prompt.md)" --output-format json --allowedTools "Bash,Read,Edit,Write,Glob,Grep"
  2. Claude reads prd.json, picks next "passes": false story
  3. Claude implements that story, runs checks, commits if green
  4. Claude updates prd.json, appends to progress.txt
  5. Check for completion: <promise>COMPLETE</promise>
  6. If complete, exit; otherwise loop
```

**Key Features:**
- Each iteration uses fresh Claude context (no session continuation) to prevent context rot
- Archives previous runs when branch changes
- Tracks current branch in `.last-branch`
- Initializes progress.txt if missing
- Foreground: user sees live output
- Background: uses nohup, logs to `.claude/sdk-bridge.log`

### What Each Claude Instance Does (prompt.md)

Each Claude agent iteration:
1. Checks out correct branch (from prd.json `branchName`)
2. Reads `progress.txt` (especially "Codebase Patterns" section)
3. Picks highest priority story where `passes: false`
4. Implements that **single** story
5. Runs quality checks (typecheck, lint, test)
6. Updates AGENTS.md files if patterns discovered
7. Commits with message: `feat: [Story ID] - [Story Title]`
8. Updates prd.json: sets `passes: true`
9. Appends to progress.txt with learnings
10. Outputs `<promise>COMPLETE</promise>` if all done

---

## Development Guidelines

### Adding New Features

**Don't.** The point of v4.0 is radical simplicity. If you feel the urge to add features, ask:
1. Is this feature essential? (If no, probably don't need it)
2. Can users work around it? (If yes, document workaround instead)
3. Does it add >10% value for >50% of users? (If no, skip it)

### Modifying Existing Components

**Commands (`start.md`):**
- Follow 7-checkpoint structure
- Use AskUserQuestion at decision points
- Keep error messages helpful and actionable
- Test both foreground and background modes

**Skills (`SKILL.md`):**
- Keep skills focused on single responsibility
- Use lettered options for questions (A, B, C, D)
- Generate human-readable output
- Document expected format clearly

**Scripts (`*.sh`):**
- Use `set -e` for fail-fast behavior
- Keep portable (avoid bash 4+ features)
- Use `${CLAUDE_PLUGIN_ROOT}` in commands, absolute paths in scripts
- Make executable: `chmod +x scripts/*.sh`

### Testing Changes

```bash
# 1. Make changes in this directory

# 2. Reinstall plugin
/plugin uninstall sdk-bridge@sdk-bridge-marketplace
/plugin install sdk-bridge@sdk-bridge-marketplace

# 3. Restart Claude Code

# 4. Test command
/sdk-bridge:start

# 5. Verify files created correctly
ls -la .claude/ tasks/ prd.json progress.txt
```

---

## File Conventions

### Naming

- Commands: `kebab-case.md`
- Skills: `kebab-case/` directories with `SKILL.md`
- Scripts: `kebab-case.sh` or `kebab-case.md`
- Config: `.claude/sdk-bridge.local.md`

### Path References

- In commands (markdown): `${CLAUDE_PLUGIN_ROOT}/scripts/file.sh`
- In skills (markdown): relative paths `./examples/file.md`
- In bash scripts: absolute paths `$HOME/.claude/...`
- Never hardcode absolute paths in committed files

### Script Permissions

All `.sh` files must be executable:
```bash
chmod +x scripts/*.sh
git add --chmod=+x scripts/*.sh
```

---

## Configuration Schema

`.claude/sdk-bridge.local.md` format:

```yaml
---
max_iterations: 10           # Stop after N iterations
editor_command: "code"       # Command to open files
branch_prefix: "sdk-bridge"  # Git branch prefix
execution_mode: "foreground" # "foreground" or "background"
---

# SDK Bridge Configuration

This file was auto-generated by `/sdk-bridge:start`.

## Settings

- **max_iterations**: Number of Amp iterations before stopping
- **editor_command**: Command to open files (e.g., "code", "cursor")
- **branch_prefix**: Git branch prefix for features
- **execution_mode**: "foreground" (live output) or "background" (continue working)

Edit these and run `/sdk-bridge:start` again to use new values.
```

---

## Debugging

### Command Not Appearing

```bash
# Check installation
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | keys'

# Verify plugin structure
ls -la ~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/*/

# Check manifest
cat ~/.claude/plugins/cache/sdk-bridge-marketplace/sdk-bridge/*/.claude-plugin/plugin.json
```

### Dependency Check Failing

```bash
# Test check-deps.sh directly
bash plugins/sdk-bridge/scripts/check-deps.sh
echo $?  # Should be 0 if all deps present

# Check claude CLI
which claude
claude --version

# Check jq
which jq
jq --version
```

### Loop Not Starting

```bash
# Check script permissions
ls -la plugins/sdk-bridge/scripts/*.sh

# Test script directly
bash plugins/sdk-bridge/scripts/sdk-bridge.sh 1

# Check Claude CLI works
claude -p "What is 2+2?" --output-format json --no-session-persistence
```

### Skills Not Loading

```bash
# Verify skill directory structure
ls -la plugins/sdk-bridge/skills/*/SKILL.md

# Check skill frontmatter
head -5 plugins/sdk-bridge/skills/*/SKILL.md
```

---

## Version History

### v4.0.0 (2026-01-19) - Complete Rewrite

**BREAKING CHANGE:** Complete architectural rewrite with focus on simplicity.

**Removed:**
- All 10 commands (replaced with single `/sdk-bridge:start`)
- 2 validation agents (no longer needed)
- Python harness (replaced with bash loop)
- Claude Agent SDK dependency (now uses Amp CLI)
- Hooks (not needed with foreground execution)
- Complex state management (simplified to files)

**Added:**
- Interactive wizard with 6 checkpoints
- PRD generator skill with clarifying questions
- PRD converter skill (markdown → JSON)
- Dependency checker with auto-install
- Foreground and background execution modes
- Automatic archiving of previous runs

**Why the rewrite?**
The v3.x architecture was over-engineered. This simpler approach is better:
- Fresh Claude context each iteration prevents pollution (no session continuation)
- Bash loop easier to understand and debug
- Interactive onboarding more accessible
- Claude Code CLI's auto-handoff handles large features naturally
- No Python dependency, just bash + claude CLI + jq

### v3.0.0 (2026-01-18) - End-to-End Transformation
Task decomposition, intelligent dependency validation (superseded)

### v2.0.0 (2026-01-11) - SOTA Generative UI
Interactive setup, live progress tracking (superseded)

### v1.x - Original Python Harness
Claude Agent SDK with programmatic control (superseded)

---

## References

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference.md)
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless.md)
- [Claude Code Plugin Guide](https://github.com/anthropics/claude-code/blob/main/docs/plugins.md)
- [Marketplace Format](https://github.com/anthropics/claude-code/blob/main/docs/plugin-marketplace.md)

---

**Maintained by:** Jesper Vang (@flight505)
**Repository:** https://github.com/flight505/sdk-bridge-marketplace
**License:** MIT
