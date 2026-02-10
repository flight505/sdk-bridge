# SDK Bridge

![SDK Bridge Hero](./assets/sdk-bridge-hero.jpg)

[![Version](https://img.shields.io/badge/version-4.8.0-blue.svg)](https://github.com/flight505/sdk-bridge)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://github.com/anthropics/claude-code)

> **Why "SDK Bridge"?** It bridges the gap between your high-level requirements and autonomous AI execution—transforming human intent into working code through the Claude Code CLI.

Interactive autonomous development assistant that generates PRDs, converts them to execution format, and runs fresh Claude agent loops until all work is complete.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Architecture

![SDK Bridge Architecture](./assets/sdk-bridge-architecture.png?v=4.6.0)

SDK Bridge uses a **bash orchestration loop** that spawns fresh Claude CLI instances for each iteration. State persists via:
- **prd.json** - Source of truth for story completion status
- **progress.txt** - Append-only log of learnings and patterns
- **Git commits** - Code changes from previous iterations

Each iteration is a fresh Claude instance with clean context—no context pollution. The bash coordinator reads state files, spawns a new Claude CLI process, and continues until all stories pass or max iterations reached.

---

## Interactive Workflow

![SDK Bridge Wizard](./assets/sdk-bridge-wizard.png?v=4.6.0)

SDK Bridge guides you through a **7-checkpoint interactive workflow**:

### Checkpoint 1: Dependency Check
Verifies `claude` CLI, `jq`, and `coreutils` are installed. Offers automatic installation if missing.

### Checkpoint 2: Project Input
Describe your project or provide a file path. If input is insufficient (<20 words), conducts a smart interview asking for:
- Project type (REQUIRED)
- Core functionality (REQUIRED)
- Tech stack, scale (optional)

Auto-proceeds when both required items answered.

### Checkpoint 3: Generate PRD
Invokes `prd-generator` skill to create a structured PRD with:
- 3-5 clarifying questions
- User stories with verifiable acceptance criteria
- Dependency tracking

### Checkpoint 4: Review PRD
Opens PRD in your editor. Four options:
- **Approve** - Proceed to JSON conversion
- **Suggest improvements** - Claude analyzes and proposes enhancements (iterative loop)
- **Need edits** - Manually edit and re-review
- **Start over** - Regenerate from scratch

### Checkpoint 5: Convert to JSON
Invokes `prd-converter` skill to transform markdown PRD into executable `prd.json` format with validation.

### Checkpoint 6: Execution Settings
Configure via interactive questions:
- Max iterations (5/10/15/20)
- Timeout per iteration (10/20/30/60 minutes)
- Mode (Foreground/Background)
- Model and effort level (Sonnet 4.5 / Opus 4.6 with effort control)

### Checkpoint 7: Launch
Starts the autonomous orchestration loop based on your settings.

**Memory between iterations:**
- Git history (commits from previous iterations)
- `progress.txt` (learnings and discovered patterns)
- `prd.json` (which stories are complete)

---

## Prerequisites

- [Claude Code CLI](https://code.claude.com) (comes with Claude Code installation)
- `jq` JSON parser (`brew install jq` on macOS)
- Git repository for your project
- Authentication (OAuth token or API key)

SDK Bridge will check for these dependencies and offer to install them automatically.

**Authentication (choose one):**

**Option 1: OAuth Token (Recommended for Max subscribers)**
```bash
# Generate OAuth token (valid for 1 year)
claude setup-token

# Add to ~/.zshrc or ~/.zsh_secrets
export CLAUDE_CODE_OAUTH_TOKEN='your-token'

# Reload shell
source ~/.zshrc
```
*Benefits: Higher rate limits, long-lived, better for autonomous workflows*

**Option 2: API Key (Alternative)**
```bash
# Get from: https://console.anthropic.com/settings/keys
export ANTHROPIC_API_KEY='your-key'
```
*Works for all API users, standard rate limits*

The plugin automatically uses OAuth if available, falls back to API key otherwise.

---

## Installation

```bash
# Add marketplace
/plugin marketplace add flight505/sdk-bridge-marketplace

# Install plugin
/plugin install sdk-bridge@sdk-bridge-marketplace
```

---

## Quick Start

```bash
# Run the interactive wizard
/sdk-bridge:start
```

That's it! SDK Bridge will:
- Ask about your feature/project
- Generate a detailed PRD with clarifying questions
- Open it in your editor for review
- Convert to execution format
- Configure settings (max iterations, foreground/background)
- Launch the autonomous agent loop

---

## How It Works

### The Loop

SDK Bridge runs fresh Claude agents repeatedly until all work is done:

```
for iteration in 1..max_iterations:
  1. Read prd.json to find next story where "passes": false
  2. Spawn fresh Claude instance with clean context
  3. Claude implements ONE story:
     - Check out feature branch
     - Read progress.txt for patterns/learnings
     - Implement the single user story
     - Run quality checks (typecheck, tests, lint)
     - Commit if checks pass
     - Update prd.json to mark story "passes": true
     - Append learnings to progress.txt
  4. Check for completion signal: <promise>COMPLETE</promise>
  5. If all done, exit; otherwise continue
```

### Key Files

| File | Purpose |
|------|---------|
| `prd.json` | Task list with execution status (the source of truth) |
| `tasks/prd-[feature].md` | Human-readable PRD (generated from your input) |
| `progress.txt` | Append-only learnings log (helps future iterations) |
| `.claude/sdk-bridge.local.md` | Configuration (max iterations, editor, mode) |
| `archive/` | Previous runs (auto-archived when branch changes) |

### Story Size

Each PRD story must be small enough to complete in **one Claude context window**.

**Right-sized stories:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

**Too big (split these):**
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

**Rule of thumb:** If you can't describe the change in 2-3 sentences, it's too big.

---

## Configuration

After first run, edit `.claude/sdk-bridge.local.md`:

```yaml
---
max_iterations: 10           # Stop after N iterations
iteration_timeout: 900       # Timeout per iteration (seconds, default: 900/15min)
execution_mode: "foreground" # "foreground" or "background"
execution_model: "opus"      # "sonnet" or "opus"
effort_level: "high"         # "low", "medium", or "high" (Opus 4.6 only)
editor_command: "code"       # Command to open files
branch_prefix: "sdk-bridge"  # Git branch prefix
---
```

**Configuration options:**
- `max_iterations`: Maximum number of Claude iterations before stopping
- `iteration_timeout`: Timeout in seconds for each iteration (default: 900 = 15 minutes)
- `execution_mode`: `foreground` (interactive) or `background` (autonomous)
- `execution_model`: `sonnet` (Sonnet 4.5, fast) or `opus` (Opus 4.6, best quality)
- `effort_level`: Controls Opus 4.6 reasoning depth — `high` (default, deepest), `medium` (balanced), `low` (fastest). Ignored for Sonnet.
- `editor_command`: Your preferred editor (`code`, `cursor`, `vim`, etc.)
- `branch_prefix`: Git branch prefix for SDK Bridge branches

**Model Selection:**
- **Planning phase** (PRD generation): Set `export CLAUDE_CODE_SUBAGENT_MODEL=opus` for best results
- **Implementation phase** (story execution): Choose model and effort level via wizard or config
- **Sonnet 4.5**: Fast and efficient, good for most tasks
- **Opus 4.6 (high effort)**: Best code quality — #1 on SWE-bench (80.8%), adaptive reasoning, 128K output tokens
- **Opus 4.6 (medium effort)**: Matches Sonnet's SWE-bench performance while using 76% fewer output tokens — best cost/quality balance
- **Opus 4.6 (low effort)**: Fastest Opus mode, minimal reasoning, cheapest

---

## Foreground vs Background

**Foreground (default):**
- See live output as Claude works
- Terminal stays occupied
- Easy to stop with Ctrl+C
- Recommended for learning how it works

**Background:**
- Runs in background, you continue working
- Check progress: `tail -f .claude/sdk-bridge.log`
- View completion: check `prd.json` for all `passes: true`
- Stop manually: `kill $(cat .claude/sdk-bridge.pid)`

---

## Resilience Features

SDK Bridge v4 includes robust process management and timeout handling:

### Iteration Timeouts

Each iteration has a configurable timeout (default: 15 minutes) to prevent indefinite hangs.

**Foreground mode:**
- Interactive prompt when timeout occurs
- Options to skip, retry with extended timeout, or abort
- Full control over execution

**Background mode:**
- Auto-skip timed-out stories
- Logs timeout to `progress.txt`
- Continues with next story automatically

### Process Management

- **Clean Ctrl+C:** Gracefully terminates Claude processes, no orphans
- **Duplicate prevention:** Blocks multiple runs on the same branch
- **Per-branch PID files:** Allows parallel work on different features
- **Automatic cleanup:** Removes stale PID files and temp files

### Already-Implemented Detection

Claude agents automatically check if work is already done before implementing:
- Searches codebase for existing implementation
- Verifies each acceptance criterion
- Skips stories where all criteria already met
- Documents findings in `prd.json` notes

**Example:** If US-005 already implemented cabin_class filtering, US-007 will detect this and mark itself complete in <2 minutes instead of hanging.

---

## Enhanced PRD Generation

SDK Bridge creates high-quality PRDs with:

### Smart Decomposition

- **Simple features** (≤5 criteria): One full-stack story
- **Complex features** (>5 criteria): Split into layers with dependencies

### Verifiable Criteria

Every acceptance criterion includes:
- **Must verify:** Specific command or test to run
- **Expected:** What success looks like
- **Example:** `Must verify: grep cabin_class api.py` → `Expected: Line shows parameter acceptance`

### Dependency Tracking

- **depends_on:** Hard dependencies (must complete first)
- **related_to:** Soft dependencies (check for related work)
- **implementation_hint:** Guidance to prevent duplicate work
- **check_before_implementing:** Commands to detect existing code

**Benefit:** Prevents wasted iterations and reduces hang scenarios by 30+ minutes per occurrence.

---

## Tips for Success

### 1. Small Tasks

Break features into small, focused stories. Each should be completable in one context window.

### 2. Quality Checks

Ensure your project has automated checks:
- Typechecking (`tsc --noEmit`, `mypy`, etc.)
- Tests (`npm test`, `pytest`, etc.)
- Linting (`eslint`, `ruff`, etc.)

SDK Bridge only commits when checks pass. Broken code compounds across iterations.

### 3. AGENTS.md Updates

SDK Bridge updates `AGENTS.md` files with discovered patterns. These are automatically read by Claude, so future iterations benefit from:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("don't forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### 4. Progress.txt Patterns

The `## Codebase Patterns` section at the top of `progress.txt` consolidates the most important learnings. Future iterations read this first before starting work.

### 5. Verification Commands

For all changes, PRDs should include specific verification commands in acceptance criteria:
- Backend: `curl` commands, API tests, `pytest`
- Frontend: Build checks (`npm run build`), linters (`npm run lint`), automated UI tests
- Manual browser testing should be done after SDK Bridge completes (browser automation not available in headless mode)

---

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# View learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10

# Monitor live (background mode)
tail -f .claude/sdk-bridge.log
```

---

## Example Workflow

```
You: /sdk-bridge:start

SDK Bridge: Describe your feature or project...
You: Add task priority system with high/medium/low levels

SDK Bridge: [Asks 3-5 clarifying questions]
You: [Answers questions]

SDK Bridge: Generated PRD at tasks/prd-task-priority.md
            Opening in VSCode...
            Review and edit, then approve when ready.

You: [Reviews, makes edits, saves]
You: Approved

SDK Bridge: Converted to prd.json with 4 user stories
            Max iterations? [10]
You: 15

SDK Bridge: Execution mode? [Foreground/Background]
You: Foreground

SDK Bridge: Starting SDK Bridge - Max iterations: 15

═══════════════════════════════════════════════════════
  SDK Bridge Iteration 1 of 15
═══════════════════════════════════════════════════════

[Claude implements US-001: Add priority field to database]
[Runs typecheck, commits]
[Updates prd.json, appends to progress.txt]

Iteration 1 complete. Continuing...

═══════════════════════════════════════════════════════
  SDK Bridge Iteration 2 of 15
═══════════════════════════════════════════════════════

[Claude implements US-002: Display priority indicator]
[Verifies in browser, commits]

... continues until all 4 stories complete ...

SDK Bridge completed all tasks!
Completed at iteration 4 of 15
```

---

## Architecture

```
sdk-bridge/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace metadata
└── plugins/
    └── sdk-bridge/
        ├── .claude-plugin/
        │   └── plugin.json       # Plugin manifest
        ├── commands/
        │   └── start.md          # Single interactive wizard command
        ├── skills/
        │   ├── prd-generator/    # Generates PRDs with clarifying questions
        │   │   └── SKILL.md
        │   └── prd-converter/    # Converts markdown PRD to prd.json
        │       └── SKILL.md
        └── scripts/
            ├── sdk-bridge.sh     # Main loop (bash)
            ├── prompt.md         # Instructions for each Claude iteration
            ├── check-deps.sh     # Dependency checker
            └── prd.json.example  # Reference format
```

---

## What Changed in v4.0.0?

SDK Bridge v4 is a **complete rewrite** with a focus on simplicity and resilience:

**Key Features:**
- Single command interactive wizard (`/sdk-bridge:start`)
- Simple bash loop with fresh Claude instances per iteration
- Foreground or background execution modes
- Interactive PRD generation with clarifying questions
- Robust process management (clean Ctrl+C, no orphans)
- Configurable iteration timeouts (default: 15 minutes)
- Already-implemented detection (prevents wasted cycles)
- Enhanced PRD generation with verifiable criteria and dependency tracking

**Why the rewrite?**
The previous architecture was over-engineered. This simpler approach:
- Fresh context each iteration prevents context pollution
- Bash loop is easier to understand and debug
- Interactive onboarding makes it accessible
- Timeout protection prevents indefinite hangs
- Dependency tracking prevents duplicate work
- Claude Code CLI's auto-handoff handles large features naturally

---

## References

- [Claude Code CLI Documentation](https://code.claude.com/docs/en/cli-reference.md)
- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code Plugins](https://github.com/anthropics/claude-code)

---

## License

MIT © Jesper Vang
