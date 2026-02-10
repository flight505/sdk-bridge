# CLAUDE.md

**Version 4.8.0** | Last Updated: 2026-02-08

Developer instructions for working with the SDK Bridge plugin for Claude Code CLI.

---

## Overview

SDK Bridge is an **interactive autonomous development assistant** providing a single command (`/sdk-bridge:start`) that:
1. Generates detailed PRDs with clarifying questions
2. Converts to executable JSON format
3. Runs fresh Claude agent loops until all work complete

**Philosophy:** Radical simplicity. One command, interactive wizard, fresh Claude instances each iteration.

---

## Architecture

### Component Structure

```
sdk-bridge/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/
│   └── start.md             # Single interactive wizard command
├── skills/
│   ├── prd-generator/       # PRD creation with clarifying questions
│   │   └── SKILL.md
│   └── prd-converter/       # Markdown → JSON converter
│       └── SKILL.md
├── scripts/
│   ├── sdk-bridge.sh        # Main bash loop
│   ├── prompt.md            # Instructions for each Claude iteration
│   ├── check-deps.sh        # Dependency checker
│   └── prd.json.example     # Reference format
└── examples/                # Example PRDs
```

### Component Roles

**Commands (`start.md`):**
- Single entry point orchestrating 7-checkpoint workflow
- Uses AskUserQuestion for user input
- Invokes skills via Task tool
- Launches bash scripts via Bash tool

**Skills:**
- `prd-generator`: Creates detailed PRDs with verifiable acceptance criteria and dependency tracking
- `prd-converter`: Transforms markdown PRD to prd.json with inferred dependencies

**Scripts:**
- `sdk-bridge.sh`: Main loop - runs fresh Claude instances until complete
- `prompt.md`: Instructions given to each Claude agent (includes "check before implementing" guidance)
- `check-deps.sh`: Validates claude CLI and jq installation

### State Files (User's Project)

```
.claude/
├── sdk-bridge.local.md      # Config (YAML frontmatter)
├── sdk-bridge-{branch}.pid  # Per-branch PID file
└── sdk-bridge.log           # Background mode log

tasks/
└── prd-{feature}.md         # Human-readable PRD

prd.json                     # Execution format (source of truth)
progress.txt                 # Learnings log (append-only)
```

---

## Key Features (v4.0.0)

### 1. Resilience & Process Management

**Iteration Timeouts:**
- Default: 900 seconds (15 minutes)
- Configurable via `iteration_timeout` in config
- Foreground: Interactive prompt (skip/retry/abort)
- Background: Auto-skip with logging

**Process Management:**
- Trap-based cleanup (graceful SIGTERM, force SIGKILL fallback)
- Per-branch PID files (allows parallel execution)
- Duplicate run prevention
- Automatic stale file cleanup
- Structured logging to stderr (`[INIT]`, `[ITER-N]`, `[CLEANUP]`, `[TIMEOUT]`)

### 2. Already-Implemented Detection

**Prompt-based** (`scripts/prompt.md` lines 5-49):
- Agents search for existing implementation before coding
- Verify each acceptance criterion
- If all met: mark complete and skip
- If partial: implement only missing pieces
- Never refactor working code

**Prevents:** 30+ minute hangs on already-completed work

### 3. Enhanced PRD Generation

**Story Decomposition** (5-criteria threshold):
- ≤5 criteria: One full-stack story (UI + backend combined)
- >5 criteria: Split by layer with explicit dependencies

**Verifiable Acceptance Criteria:**
- Every criterion includes `Must verify: [command]`
- Specific verification method (test, command, condition)
- Prevents ambiguous "done" states

**Dependency Tracking:**
- `depends_on`: Hard dependencies (must complete first)
- `related_to`: Soft dependencies (check for related work)
- `implementation_hint`: Free-form guidance
- `check_before_implementing`: Grep commands to detect existing code

---

## Development Guidelines

### When in doubt or asked, use the claude-docs-skill

**Claude API Documentation with 4-Tier Routing**

- `Triggers`: "claude docs skill", "use claude docs", "claude api", "anthropic api", "agent sdk", "claude models", "tool use", "extended thinking", "mcp"

**4-Tier System:**
- Tier 1: Quick reference primer
- Tier 2: Pattern library (8 cookbooks)
- Tier 3: Recent changes log
- Tier 4: Complete reference (LLM-optimized)

**Coverage:** Claude API (Messages, Batches, Models, Admin) • Agent SDK (Python, TypeScript) • Tool use, Extended thinking, Streaming, Batching • Vision, PDF, MCP • Prompt engineering, Testing, Security

**Use Cases:** Quick syntax lookups • Real-world patterns • Track API updates • Deep endpoint reference



### Modifying Components

**Commands (`start.md`):**
- Follow 7-checkpoint structure
- Use AskUserQuestion at decision points
- Test both foreground and background modes

**Skills (`SKILL.md`):**
- Single responsibility
- Lettered options for questions (A, B, C, D)
- Document expected format

**Scripts (`*.sh`):**
- Use `set -e` for fail-fast
- Keep portable (avoid bash 4+ features)
- Use `${CLAUDE_PLUGIN_ROOT}` in commands
- Use absolute paths in scripts
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

# 5. Verify files created
ls -la .claude/ tasks/ prd.json progress.txt
```

---

## File Conventions

**Naming:**
- Commands: `kebab-case.md`
- Skills: `kebab-case/` directories with `SKILL.md`
- Scripts: `kebab-case.sh` or `kebab-case.md`
- Config: `.claude/sdk-bridge.local.md`

**Path References:**
- In commands (markdown): `${CLAUDE_PLUGIN_ROOT}/scripts/file.sh`
- In skills (markdown): relative paths `./examples/file.md`
- In bash scripts: absolute paths `$HOME/.claude/...`
- Never hardcode absolute paths in committed files

**Script Permissions:**
```bash
chmod +x scripts/*.sh
git add --chmod=+x scripts/*.sh
```

---

## Configuration Schema

`.claude/sdk-bridge.local.md` format:

```yaml
---
max_iterations: 25           # Stop after N iterations (1 story ≈ 1-3 iterations)
iteration_timeout: 3600      # Timeout per iteration (seconds) - 60 min default
execution_mode: "foreground" # "foreground" or "background"
execution_model: "opus"      # "sonnet" or "opus" for story implementation
effort_level: "high"         # "low", "medium", or "high" (Opus 4.6 only, default: high)
editor_command: "code"       # Command to open files
branch_prefix: "sdk-bridge"  # Git branch prefix
---
```

**Iteration Guidelines:**
- Each story typically consumes 1-3 iterations
- Simple stories: 1 iteration (already-implemented check passes)
- Standard stories: 1-2 iterations (implement + verify)
- Complex stories: 2-3 iterations (may need retries/fixes)
- Formula: `stories × 2.5 = recommended iterations`

**Timeout Guidelines (based on avg acceptance criteria per story):**
| Avg Criteria | Complexity | Base Timeout | Recommended |
|--------------|------------|--------------|-------------|
| 1-2 | Simple | 30 min | 45 min |
| 3-4 | Standard | 45 min | 60 min |
| 5-6 | Complex | 60 min | 75 min |
| 7+ | Very Complex | 90 min | 105 min |

**Model Selection:**
- `execution_model`: Which Claude model implements the stories (sonnet or opus)
- `effort_level`: Controls reasoning depth for Opus 4.6 (low/medium/high). Ignored for Sonnet.
  - `high` (default): Deep reasoning, best quality, highest cost
  - `medium`: Matches Sonnet-level SWE-bench at 76% fewer tokens — best cost/quality balance
  - `low`: Fastest, minimal reasoning, cheapest
- Planning (PRD generation) uses `CLAUDE_CODE_SUBAGENT_MODEL` env var (recommend: opus)
- Implementation uses `execution_model` config (default: opus)

---

## Authentication

SDK Bridge supports two methods with intelligent fallback:

**OAuth Token (Recommended for Max subscribers):**
```bash
claude setup-token
export CLAUDE_CODE_OAUTH_TOKEN='your-token'
```

**API Key (Fallback):**
```bash
export ANTHROPIC_API_KEY='your-key'
```

Script prioritizes OAuth if available, falls back to API key otherwise.

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

### Loop Issues

```bash
# Test script directly
bash scripts/sdk-bridge.sh 1

# Check Claude CLI
claude -p "What is 2+2?" --output-format json --no-session-persistence

# Verify dependencies
bash scripts/check-deps.sh
```

### Skills Not Loading

```bash
# Verify skill structure
ls -la skills/*/SKILL.md

# Check frontmatter
head -5 skills/*/SKILL.md
```

---

## Version History

### v4.0.0 (2026-01-22)

**Complete rewrite with resilience features:**

**Added:**
- Interactive wizard with 7 checkpoints
- PRD generator skill with smart decomposition (5-criteria threshold)
- PRD converter skill with dependency inference
- Configurable iteration timeouts (default: 15 min)
- Mode-based timeout recovery (interactive/auto-skip)
- Already-implemented detection (prompt-based)
- Robust process management (trap-based cleanup, per-branch PIDs)
- Verifiable acceptance criteria requirements
- Dependency tracking metadata
- Automatic archiving of previous runs

**Removed:**
- All 10 commands (replaced with single `/start`)
- 2 validation agents (no longer needed)
- Python harness (replaced with bash loop)
- Complex state management

**Why:** v3.x was over-engineered. This simpler approach prevents hangs, eliminates orphaned processes, and reduces duplicate work.

---

## References

- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference.md)
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless.md)
- [Plugin Development Guide](https://github.com/anthropics/claude-code/blob/main/docs/plugins.md)
- [Marketplace Format](https://github.com/anthropics/claude-code/blob/main/docs/plugin-marketplace.md)
- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)

---

**Maintained by:** Jesper Vang (@flight505)
**Repository:** https://github.com/flight505/sdk-bridge
**License:** MIT
