# SDK Bridge Ralph Transformation Design

**Date:** 2026-01-19
**Status:** Validated
**Goal:** Transform sdk-bridge from over-engineered complexity to Ralph's proven simplicity with interactive onboarding

---

## Overview

Rebuild sdk-bridge as a single-command interactive wizard that generates PRDs, converts them to JSON, and runs an autonomous agent loop using Amp CLI. Based on the working ralph-main pattern.

**Core Philosophy:**
- One command does everything (`/sdk-bridge:start`)
- Interactive onboarding with AskUserQuestion
- Self-contained dependency management
- Foreground or background execution (user's choice)
- Clean slate: delete old complexity, copy working Ralph pattern

---

## Architecture

### File Structure

```
sdk-bridge/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace metadata
└── plugins/
    └── sdk-bridge/
        ├── .claude-plugin/
        │   └── plugin.json       # Plugin manifest
        ├── commands/
        │   └── start.md          # Single command - interactive wizard
        ├── skills/
        │   ├── prd-generator/    # Renamed from prd skill
        │   │   └── SKILL.md
        │   └── prd-converter/    # Renamed from ralph skill
        │       └── SKILL.md
        └── scripts/
            ├── sdk-bridge.sh     # Main loop (forked from ralph.sh)
            ├── prompt.md         # Instructions for each amp iteration
            ├── check-deps.sh     # Dependency checker/installer
            └── prd.json.example  # Reference format
```

### State Files (in user's project)

```
project/
├── .claude/
│   ├── sdk-bridge.local.md       # Config (YAML frontmatter + markdown)
│   ├── sdk-bridge.pid            # PID if running in background
│   └── sdk-bridge.log            # Output log if background
├── tasks/
│   └── prd-feature-name.md       # Human-readable PRD
├── prd.json                       # Execution format (amp reads this)
├── progress.txt                   # Learnings log (appended each iteration)
└── archive/                       # Previous runs
    └── YYYY-MM-DD-feature-name/
```

---

## Interactive Workflow (6 Checkpoints)

The `/sdk-bridge:start` command guides users through these checkpoints:

### Checkpoint 1: Project Input
- **Question:** "Describe your feature/project" (text field)
- **Supports:** `@file` references for outlines/specs
- **Example:** "Add user authentication" or "@specs/auth-requirements.md"

### Checkpoint 2: Generate PRD
- **Action:** Loads `prd-generator` skill internally
- **Process:** Skill asks 3-5 clarifying questions (lettered options)
- **Output:** `tasks/prd-[feature-name].md`
- **Note:** Auto-creates `tasks/` directory if needed

### Checkpoint 3: Review PRD
- **Action:** Opens file in user's editor
- **Detection:** Try `code`, `cursor`, or fallback to "please open X"
- **Question:** "Review `tasks/prd-feature.md` in your editor. Ready to proceed?"
- **Options:**
  - "Approved - convert to JSON"
  - "Need to edit more - wait"
  - "Start over"
- **Behavior:** Waits for user confirmation after edits

### Checkpoint 4: Convert to JSON
- **Action:** Loads `prd-converter` skill internally
- **Process:** Converts markdown PRD → `prd.json` with user stories
- **Validation:** Checks structure (IDs, priorities, acceptance criteria)

### Checkpoint 5: Execution Settings
- **Questions:**
  - Max iterations? (default: 10)
  - Run in foreground or background? (default: foreground)
- **Action:** Creates `.claude/sdk-bridge.local.md` with settings
- **Format:**
  ```yaml
  ---
  max_iterations: 10
  editor_command: "code"
  branch_prefix: "sdk-bridge"
  execution_mode: "foreground"
  ---
  # SDK Bridge Configuration
  Edit these settings as needed.
  ```

### Checkpoint 6: Launch
- **Foreground:** Runs `scripts/sdk-bridge.sh`, shows live output
- **Background:** Runs with `nohup`, shows PID and log location
- **Loop:** Continues until all stories pass or max iterations reached

---

## Execution Loop (sdk-bridge.sh)

Main bash script that spawns fresh `amp` instances until work is complete.

### Loop Algorithm

```bash
#!/bin/bash
# Reads prd.json, runs amp repeatedly, updates state

MAX_ITERATIONS=${1:-10}

for i in $(seq 1 $MAX_ITERATIONS); do
  echo "Iteration $i of $MAX_ITERATIONS"

  # Run amp with prompt
  OUTPUT=$(cat prompt.md | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo "SDK Bridge completed all tasks!"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo "Reached max iterations without completing all tasks."
exit 1
```

### Key Features

- **Branch prefix:** `sdk-bridge/feature-name` (not `ralph/`)
- **Config source:** Reads `.claude/sdk-bridge.local.md` for settings
- **Archiving:** Previous runs archived to `archive/YYYY-MM-DD-feature-name/`
- **Completion signal:** Loop exits when amp outputs `<promise>COMPLETE</promise>`

### What Amp Does Each Iteration (prompt.md)

1. Check out correct branch (or create from main)
2. Read `prd.json` + `progress.txt` (especially "Codebase Patterns" section)
3. Pick highest priority story where `passes: false`
4. Implement that single story
5. Run quality checks (typecheck, tests, lint - project-specific)
6. Update AGENTS.md files if reusable patterns discovered
7. Commit if checks pass: `feat: [Story ID] - [Story Title]`
8. Update prd.json: set `passes: true` for completed story
9. Append to progress.txt with learnings and thread URL
10. Output `<promise>COMPLETE</promise>` if all stories done

---

## Dependency Management

### Dependencies Required

- **amp CLI:** `npm install -g @anthropic-ai/amp-cli`
- **jq:** JSON parser (macOS: `brew install jq`)

### Checker Script (check-deps.sh)

```bash
#!/bin/bash
# Returns 0 if all deps present, 1 if missing
# Outputs list of missing dependencies to stdout

MISSING=()

if ! command -v amp &> /dev/null; then
  MISSING+=("amp")
fi

if ! command -v jq &> /dev/null; then
  MISSING+=("jq")
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  exit 0
else
  echo "${MISSING[@]}"
  exit 1
fi
```

### Installation Flow in start.md

1. Run `check-deps.sh` first thing
2. If missing deps detected:
   - Use AskUserQuestion: "Need to install: `npm install -g @anthropic-ai/amp-cli` and `brew install jq`. OK to proceed?"
   - Options: "Yes - install automatically" / "No - I'll install manually"
3. If approved:
   - Run install commands: `npm install -g @anthropic-ai/amp-cli`
   - Run install commands: `brew install jq` (macOS) or show Linux instructions
   - Verify success by re-running checker
4. If declined:
   - Show manual installation instructions
   - Exit with helpful message

---

## Migration Plan

### Phase 1: Delete Old SDK-Bridge

**Remove completely:**
```
✗ commands/          (10 commands → replaced by 1)
✗ agents/            (2 agents → none needed)
✗ skills/            (2 complex skills → replaced)
✗ scripts/           (12 Python/bash scripts → 3 simple bash scripts)
✗ hooks/             (SessionStart/Stop hooks → none needed initially)
✗ docs/              (old architecture docs)
✗ All Python files   (no Python dependency)
✗ README.md content  (rewrite from scratch)
✗ CLAUDE.md content  (rewrite for new architecture)
```

**Keep only:**
```
✓ .claude-plugin/marketplace.json  (update metadata)
✓ plugins/sdk-bridge/              (directory structure)
✓ .gitignore
```

### Phase 2: Copy from Ralph-Main

**Copy and rename:**
```
ralph-main/ralph.sh              → scripts/sdk-bridge.sh
ralph-main/prompt.md             → scripts/prompt.md
ralph-main/prd.json.example      → scripts/prd.json.example
ralph-main/skills/prd/SKILL.md   → skills/prd-generator/SKILL.md
ralph-main/skills/ralph/SKILL.md → skills/prd-converter/SKILL.md
```

**Content to adapt:**
```
ralph-main/README.md             → Adapt for SDK Bridge context
ralph-main/AGENTS.md             → Reference for CLAUDE.md
```

### Phase 3: Create New Files

**New components:**
```
commands/start.md                 # Interactive wizard command
scripts/check-deps.sh             # Dependency checker
.claude-plugin/plugin.json        # Plugin manifest
README.md                         # User-facing documentation
CLAUDE.md                         # Developer instructions
```

### Phase 4: Global Renaming

**Find and replace in all copied files:**
- `ralph` → `sdk-bridge`
- `Ralph` → `SDK Bridge`
- `ralph/` (branch prefix) → `sdk-bridge/`
- `amp.experimental.autoHandoff` → keep as-is (amp config)
- Config references → `.claude/sdk-bridge.local.md`

---

## Configuration Format

**File:** `.claude/sdk-bridge.local.md`

```yaml
---
max_iterations: 10
editor_command: "code"
branch_prefix: "sdk-bridge"
execution_mode: "foreground"
---

# SDK Bridge Configuration

This file was generated by `/sdk-bridge:start`.

## Settings

- **max_iterations:** Number of amp iterations before stopping (default: 10)
- **editor_command:** Command to open files (e.g., "code", "cursor")
- **branch_prefix:** Git branch prefix for features (default: "sdk-bridge")
- **execution_mode:** "foreground" or "background"

Edit these settings and run `/sdk-bridge:start` again to use new values.
```

---

## Success Criteria

The transformation is successful when:

1. ✅ Old sdk-bridge code deleted (except marketplace structure)
2. ✅ Ralph files copied and renamed to sdk-bridge conventions
3. ✅ `/sdk-bridge:start` command works end-to-end
4. ✅ Dependency checking prompts user appropriately
5. ✅ PRD generation with clarifying questions works
6. ✅ PRD opens in user's editor correctly
7. ✅ Markdown PRD converts to valid prd.json
8. ✅ Loop executes in foreground or background per user choice
9. ✅ Amp iterations run, update prd.json, append to progress.txt
10. ✅ Loop exits with `<promise>COMPLETE</promise>` when done
11. ✅ Documentation (README, CLAUDE.md) reflects new architecture
12. ✅ Plugin installs and works via Claude Code marketplace

---

## Open Questions

None - all design decisions validated.

---

## Next Steps

1. Create implementation plan (use superpowers:writing-plans)
2. Set up git worktree for isolated development (use superpowers:using-git-worktrees)
3. Execute transformation incrementally with checkpoints
4. Test end-to-end workflow
5. Update marketplace.json and bump version
6. Commit and release
