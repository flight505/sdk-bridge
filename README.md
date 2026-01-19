# SDK Bridge

**Version 4.0.0** - Complete Rewrite

Interactive autonomous development assistant that generates PRDs, converts them to execution format, and runs [Amp](https://ampcode.com) agent loops until all work is complete.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## What It Does

SDK Bridge guides you through an interactive workflow:

1. **Describe your feature** - Type a description or reference a file with `@file`
2. **Generate PRD** - Answers clarifying questions, creates detailed requirements document
3. **Review & edit** - Opens PRD in your editor for refinement
4. **Convert to JSON** - Transforms PRD into executable task list
5. **Configure & run** - Sets max iterations and execution mode
6. **Autonomous execution** - Amp runs in a loop, implementing one story at a time until complete

Each iteration is a **fresh Amp instance** with clean context. Memory persists via:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and discovered patterns)
- `prd.json` (which stories are done)

---

## Prerequisites

- [Amp CLI](https://ampcode.com) (`npm install -g @anthropic-ai/amp-cli`)
- `jq` JSON parser (`brew install jq` on macOS)
- Git repository for your project

SDK Bridge will check for these and offer to install them automatically.

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

SDK Bridge runs Amp repeatedly until all work is done:

```
for iteration in 1..max_iterations:
  1. Read prd.json to find next story where "passes": false
  2. Run fresh Amp instance with clean context
  3. Amp implements ONE story:
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

Each PRD story must be small enough to complete in **one Amp context window**.

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
max_iterations: 10          # Stop after N iterations
editor_command: "code"      # Command to open files
branch_prefix: "sdk-bridge" # Git branch prefix
execution_mode: "foreground" # or "background"
---
```

---

## Foreground vs Background

**Foreground (default):**
- See live output as Amp works
- Terminal stays occupied
- Easy to stop with Ctrl+C
- Recommended for learning how it works

**Background:**
- Runs in background, you continue working
- Check progress: `tail -f .claude/sdk-bridge.log`
- View completion: check `prd.json` for all `passes: true`
- Stop manually: `kill $(cat .claude/sdk-bridge.pid)`

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

SDK Bridge updates `AGENTS.md` files with discovered patterns. These are automatically read by Amp, so future iterations benefit from:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("don't forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### 4. Progress.txt Patterns

The `## Codebase Patterns` section at the top of `progress.txt` consolidates the most important learnings. Future iterations read this first before starting work.

### 5. Browser Verification

For UI changes, PRDs should include "Verify in browser using dev-browser skill" in acceptance criteria. SDK Bridge will use Amp's browser automation to confirm visual changes work.

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

[Amp implements US-001: Add priority field to database]
[Runs typecheck, commits]
[Updates prd.json, appends to progress.txt]

Iteration 1 complete. Continuing...

═══════════════════════════════════════════════════════
  SDK Bridge Iteration 2 of 15
═══════════════════════════════════════════════════════

[Amp implements US-002: Display priority indicator]
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
            ├── prompt.md         # Instructions for each Amp iteration
            ├── check-deps.sh     # Dependency checker
            └── prd.json.example  # Reference format
```

---

## What Changed in v4.0.0?

SDK Bridge v4 is a **complete rewrite** based on the proven Ralph pattern:

**Before (v3.x):**
- 10 commands, 2 agents, complex Python harness
- Claude Agent SDK with programmatic control
- Background-only execution
- Manual feature_list.json creation

**After (v4.0):**
- 1 command, 0 agents, simple bash loop
- Amp CLI for each iteration
- Foreground or background execution
- Interactive PRD generation

**Why the change?**
The previous architecture was over-engineered. Ralph's simplicity works better:
- Fresh context each iteration prevents context pollution
- Bash loop is easier to understand and debug
- Interactive onboarding makes it accessible
- Amp's auto-handoff handles large features naturally

---

## References

- [Amp Documentation](https://ampcode.com/manual)
- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code Plugins](https://github.com/anthropics/claude-code)

---

## License

MIT © Jesper Vang
