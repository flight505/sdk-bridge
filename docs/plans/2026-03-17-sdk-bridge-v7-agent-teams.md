# SDK Bridge v7.0 — Agent Teams Rewrite

> **For Claude:** Execute task-by-task using TDD. For parallel execution: `/batch` with this plan file.

**Goal:** Replace the bash loop orchestrator with native Claude Code Agent Teams, enabling parallel story execution via teammates with shared task coordination.
**Architecture:** Single `/sdk-bridge:start` command acts as team lead. Lead reads PRD, creates shared task list via TaskCreate, spawns implementer teammates that self-claim stories. TaskCompleted hook validates. Reviewer + code-reviewer run as subagents after all stories complete.
**Tech Stack:** Bash 3.2 (hooks/scripts), Markdown (agents/skills/commands), jq (JSON parsing)

---

### Task 1: Remove obsolete files

**Files:** Delete: `agents/architect.md`, `agents/merger.md`, `skills/failure-analyzer/SKILL.md`, `scripts/sdk-bridge.sh`, `scripts/prompt.md`, `scripts/check-git.sh`, `hooks/check-destructive.sh`, `hooks/inject-learnings.sh`, `hooks/validate-result.sh`, `hooks/inject-prd-context.sh`, `hooks/auto-lint.sh`, `hooks/session-context.sh`

**Step 1: Verify files exist**
```bash
ls -la agents/architect.md agents/merger.md skills/failure-analyzer/SKILL.md scripts/sdk-bridge.sh scripts/prompt.md scripts/check-git.sh hooks/check-destructive.sh hooks/inject-learnings.sh hooks/validate-result.sh hooks/inject-prd-context.sh hooks/auto-lint.sh hooks/session-context.sh
```

**Step 2: Move to trash**
```bash
trash agents/architect.md agents/merger.md scripts/sdk-bridge.sh scripts/prompt.md scripts/check-git.sh hooks/check-destructive.sh hooks/inject-learnings.sh hooks/validate-result.sh hooks/inject-prd-context.sh hooks/auto-lint.sh hooks/session-context.sh
trash skills/failure-analyzer/SKILL.md && rmdir skills/failure-analyzer 2>/dev/null || true
```

**Step 3: Verify removal**
```bash
ls agents/ hooks/ scripts/ skills/
```
Expected: agents/ has `implementer.md`, `reviewer.md`, `code-reviewer.md`. hooks/ has only `hooks.json`. scripts/ has `check-deps.sh`, `prd.json.example`. skills/ has `prd-generator/`, `prd-converter/`.

**Step 4: Commit**
```bash
git add -A && git commit -m "chore: remove v6 obsolete files (bash loop, 5 agents → 3, 6 hooks → 0)"
```

---

### Task 2: Create hooks.json with 4 Agent Teams hooks

**Files:** Modify: `hooks/hooks.json`

**Step 1: Write failing validation**
```bash
echo '{}' > /tmp/hooks-test.json
jq '.hooks.TaskCompleted' /tmp/hooks-test.json
```
Expected: FAIL (null — no TaskCompleted key)

**Step 2: Write new hooks.json**

Replace `hooks/hooks.json` with the new 4-hook configuration:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/inject-context.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/validate-task.sh",
            "timeout": 120000,
            "statusMessage": "Validating story completion..."
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/check-idle.sh",
            "timeout": 5000,
            "statusMessage": "Checking teammate status..."
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/preserve-context.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

**Step 3: Validate JSON**
```bash
jq . hooks/hooks.json > /dev/null && echo "Valid JSON"
jq '.hooks | keys' hooks/hooks.json
```
Expected: `["PreCompact", "SessionStart", "TaskCompleted", "TeammateIdle"]`

**Step 4: Commit**
```bash
git add hooks/hooks.json && git commit -m "feat: rewrite hooks.json for Agent Teams (4 hooks: TaskCompleted, TeammateIdle, SessionStart, PreCompact)"
```

---

### Task 3: Create validate-task.sh (TaskCompleted hook)

**Files:** Create: `hooks/validate-task.sh`

**Step 1: Write the hook script**

This hook fires when a teammate marks a task as completed via TaskUpdate. It reads quality commands from config and runs them. Exit 2 blocks completion with feedback.

```bash
#!/bin/bash
# TaskCompleted hook — validates story by running test/build/typecheck
# Exit 0: allow completion
# Exit 2: block completion, stderr sent as feedback to teammate
set -e

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // empty')

# Find config
CONFIG_FILE=".claude/sdk-bridge.config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0  # No config = no validation
fi

TEST_CMD=$(jq -r '.test_command // empty' "$CONFIG_FILE")
BUILD_CMD=$(jq -r '.build_command // empty' "$CONFIG_FILE")
TYPECHECK_CMD=$(jq -r '.typecheck_command // empty' "$CONFIG_FILE")

FAILURES=""

# Run typecheck
if [ -n "$TYPECHECK_CMD" ]; then
  if ! OUTPUT=$(eval "$TYPECHECK_CMD" 2>&1); then
    FAILURES="${FAILURES}Typecheck failed for ${TASK_SUBJECT}:\n${OUTPUT}\n\n"
  fi
fi

# Run build
if [ -n "$BUILD_CMD" ]; then
  if ! OUTPUT=$(eval "$BUILD_CMD" 2>&1); then
    FAILURES="${FAILURES}Build failed for ${TASK_SUBJECT}:\n${OUTPUT}\n\n"
  fi
fi

# Run tests
if [ -n "$TEST_CMD" ]; then
  if ! OUTPUT=$(eval "$TEST_CMD" 2>&1); then
    FAILURES="${FAILURES}Tests failed for ${TASK_SUBJECT}:\n${OUTPUT}\n\n"
  fi
fi

if [ -n "$FAILURES" ]; then
  # Truncate to 4000 chars to avoid context bloat
  TRUNCATED=$(echo -e "$FAILURES" | head -c 4000)
  echo -e "Validation failed — fix these before completing:\n\n${TRUNCATED}" >&2
  exit 2
fi

exit 0
```

**Step 2: Make executable and validate syntax**
```bash
chmod +x hooks/validate-task.sh
bash -n hooks/validate-task.sh && echo "Syntax OK"
```
Expected: "Syntax OK"

**Step 3: Test with mock input**
```bash
echo '{"task_subject":"US-001: Add priority field","task_id":"task-1"}' | bash hooks/validate-task.sh
echo "Exit code: $?"
```
Expected: Exit code 0 (no config file = no validation = pass)

**Step 4: Commit**
```bash
git add hooks/validate-task.sh && git commit -m "feat: add TaskCompleted hook — validates stories with test/build/typecheck"
```

---

### Task 4: Create check-idle.sh (TeammateIdle hook)

**Files:** Create: `hooks/check-idle.sh`

**Step 1: Write the hook script**

This hook fires when a teammate is about to go idle. Check if prd.json has remaining stories. Exit 2 to keep the teammate working.

```bash
#!/bin/bash
# TeammateIdle hook — prevents teammates from stopping while work remains
# Exit 0: allow idle (all work done)
# Exit 2: block idle, stderr sent as feedback
set -e

# Check for prd.json
if [ ! -f "prd.json" ]; then
  exit 0  # No PRD = nothing to check
fi

# Count incomplete stories
REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' prd.json 2>/dev/null || echo "0")

if [ "$REMAINING" -gt 0 ]; then
  # Get next available story
  NEXT=$(jq -r '[.userStories[] | select(.passes == false)][0] | "\(.id): \(.title)"' prd.json 2>/dev/null || echo "unknown")
  echo "There are still ${REMAINING} incomplete stories. Next: ${NEXT}. Check the task list for unclaimed work." >&2
  exit 2
fi

exit 0
```

**Step 2: Make executable and validate**
```bash
chmod +x hooks/check-idle.sh
bash -n hooks/check-idle.sh && echo "Syntax OK"
```

**Step 3: Commit**
```bash
git add hooks/check-idle.sh && git commit -m "feat: add TeammateIdle hook — prevents premature teammate shutdown"
```

---

### Task 5: Create inject-context.sh (SessionStart hook)

**Files:** Create: `hooks/inject-context.sh`

**Step 1: Write the hook script**

Detects active prd.json and injects status summary into session context.

```bash
#!/bin/bash
# SessionStart hook — injects PRD status into session context
set -e

if [ ! -f "prd.json" ]; then
  exit 0
fi

# Validate JSON
if ! jq empty prd.json 2>/dev/null; then
  exit 0
fi

PROJECT=$(jq -r '.project // "Unknown"' prd.json)
BRANCH=$(jq -r '.branchName // "unknown"' prd.json)
TOTAL=$(jq '.userStories | length' prd.json)
DONE=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json)
PENDING=$((TOTAL - DONE))

CONTEXT="## Active SDK Bridge Run
**Project:** ${PROJECT}
**Branch:** ${BRANCH}
**Progress:** ${DONE}/${TOTAL} stories complete (${PENDING} pending)
**Mode:** Agent Teams orchestration"

if [ "$DONE" -eq "$TOTAL" ]; then
  CONTEXT="${CONTEXT}
**Status:** ALL STORIES COMPLETE"
fi

# Output as JSON for hook system
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' \
  "$(echo "$CONTEXT" | sed 's/"/\\"/g' | tr '\n' ' ')"
```

**Step 2: Make executable and validate**
```bash
chmod +x hooks/inject-context.sh
bash -n hooks/inject-context.sh && echo "Syntax OK"
```

**Step 3: Commit**
```bash
git add hooks/inject-context.sh && git commit -m "feat: add SessionStart hook — injects PRD status context"
```

---

### Task 6: Create preserve-context.sh (PreCompact hook)

**Files:** Create: `hooks/preserve-context.sh`

**Step 1: Write the hook script**

Re-injects current story and patterns before context compaction.

```bash
#!/bin/bash
# PreCompact hook — preserves current story context during compaction
set -e

if [ ! -f "prd.json" ]; then
  exit 0
fi

if ! jq empty prd.json 2>/dev/null; then
  exit 0
fi

# Get first incomplete story
STORY=$(jq -r '[.userStories[] | select(.passes == false)][0] // empty' prd.json 2>/dev/null)

if [ -z "$STORY" ] || [ "$STORY" = "null" ]; then
  exit 0
fi

STORY_ID=$(echo "$STORY" | jq -r '.id')
STORY_TITLE=$(echo "$STORY" | jq -r '.title')
CRITERIA=$(echo "$STORY" | jq -r '.acceptanceCriteria | join("; ")')

CONTEXT="## Current Story (preserve across compaction)
**${STORY_ID}: ${STORY_TITLE}**
Criteria: ${CRITERIA}"

# Inject patterns from progress.jsonl if it exists
if [ -f "progress.jsonl" ]; then
  PATTERNS=$(tail -20 progress.jsonl | jq -r '.patterns[]? // empty' 2>/dev/null | sort -u | head -10)
  if [ -n "$PATTERNS" ]; then
    CONTEXT="${CONTEXT}

## Codebase Patterns
${PATTERNS}"
  fi
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":"%s"}}' \
  "$(echo "$CONTEXT" | sed 's/"/\\"/g' | tr '\n' ' ')"
```

**Step 2: Make executable and validate**
```bash
chmod +x hooks/preserve-context.sh
bash -n hooks/preserve-context.sh && echo "Syntax OK"
```

**Step 3: Commit**
```bash
git add hooks/preserve-context.sh && git commit -m "feat: add PreCompact hook — preserves story context during compaction"
```

---

### Task 7: Rewrite implementer.md for Agent Teams

**Files:** Modify: `agents/implementer.md`

**Step 1: Rewrite the agent**

The implementer is now a **teammate** in an Agent Teams setup, not a subagent with worktree isolation. Key changes:
- Remove `isolation: worktree` (teammates share filesystem)
- Remove `skills: [failure-analyzer]` (skill deleted)
- Remove inline PostToolUse hook (auto-lint moves to instructions)
- Add task-claiming workflow
- Add peer messaging for pattern sharing
- Keep TDD discipline, verification requirements

Write the new `agents/implementer.md` with these frontmatter changes:
```yaml
---
name: implementer
description: "Implements user stories from a shared task list. Claims tasks, codes with TDD discipline, runs quality checks, commits, and shares patterns with teammates. Designed for Agent Teams parallel execution."
tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - TaskCreate
  - TaskGet
  - TaskList
  - TaskUpdate
disallowedTools:
  - Agent
model: inherit
permissionMode: bypassPermissions
maxTurns: 150
memory: project
---
```

Body instructions covering:
1. **Task Claiming** — use TaskList to find unclaimed tasks, TaskUpdate to claim
2. **Check Before Implementing** — read prd.json, search for existing code
3. **TDD** — RED-GREEN-REFACTOR (same discipline, carried forward)
4. **Pattern Sharing** — broadcast learnings to teammates when discovering patterns
5. **Verification** — run quality checks, capture evidence
6. **Commit** — `feat(US-XXX): Story Title`
7. **Mark Complete** — TaskUpdate to mark task completed
8. **Progress Logging** — append to progress.jsonl

**Step 2: Validate frontmatter**
```bash
head -20 agents/implementer.md
```
Expected: Valid YAML frontmatter with task tools listed.

**Step 3: Commit**
```bash
git add agents/implementer.md && git commit -m "feat: rewrite implementer for Agent Teams — task claiming, peer messaging, no worktree"
```

---

### Task 8: Update reviewer.md for post-completion review

**Files:** Modify: `agents/reviewer.md`

**Step 1: Update the agent**

Minor updates:
- Description updated: "Runs after all stories complete to verify spec compliance across the full diff"
- Change workflow: Instead of per-story review, review the FULL feature branch diff
- Add: Read progress.jsonl for context
- Keep: Two-phase structure (spec compliance + validation)
- Keep: Same output format

**Step 2: Validate**
```bash
head -5 agents/reviewer.md | grep "name: reviewer"
```

**Step 3: Commit**
```bash
git add agents/reviewer.md && git commit -m "feat: update reviewer for post-completion full-diff review"
```

---

### Task 9: Update code-reviewer.md

**Files:** Modify: `agents/code-reviewer.md`

**Step 1: Update the agent**

Minor updates:
- Description updated: "Reviews full feature branch diff for code quality after reviewer approves"
- Workflow: Review complete diff, not per-story changes
- Keep: Same severity taxonomy, verdict rules, output format

**Step 2: Commit**
```bash
git add agents/code-reviewer.md && git commit -m "feat: update code-reviewer for full-branch review"
```

---

### Task 10: Update prd-generator skill

**Files:** Modify: `skills/prd-generator/SKILL.md`

**Step 1: Update terminology and references**

Changes:
- Replace "iteration" with "teammate session" where referring to execution
- Replace "fresh Claude instance" with "teammate" where appropriate
- Remove reference to "SDK Bridge spawns a fresh Claude instance per iteration"
- Add note: "Stories may execute in parallel — ensure acceptance criteria are independently verifiable"
- Update story size guidance: "Each story should be self-contained for one teammate"
- Keep: All clarifying question patterns, story decomposition, example PRD

**Step 2: Commit**
```bash
git add skills/prd-generator/SKILL.md && git commit -m "feat: update prd-generator terminology for Agent Teams"
```

---

### Task 11: Update prd-converter skill

**Files:** Modify: `skills/prd-converter/SKILL.md`

**Step 1: Update for Agent Teams**

Changes:
- Update opening: "Converts PRDs to prd.json for Agent Teams execution"
- Replace "fresh Claude instance per iteration" → "teammate claims and implements"
- Update story size note: "Each story should be independently implementable by one teammate"
- Add dependency graph output section: After conversion, output the dependency analysis
  - Which stories can run in parallel (no deps)
  - Which stories are blocked
  - Suggested teammate count based on parallelism
- Replace "progress.txt" references with "progress.jsonl"
- Update archiving note: Remove reference to sdk-bridge.sh
- Keep: All dependency inference rules, schema, examples

**Step 2: Commit**
```bash
git add skills/prd-converter/SKILL.md && git commit -m "feat: update prd-converter with dependency graph analysis for parallel execution"
```

---

### Task 12: Create watchdog.sh

**Files:** Create: `scripts/watchdog.sh`

**Step 1: Write the watchdog**

~30-line safety net that checks if prd.json has incomplete work and guides the user to resume.

```bash
#!/bin/bash
# SDK Bridge Watchdog — checks for incomplete runs and guides resume
# Usage: bash scripts/watchdog.sh
set -e

if [ ! -f "prd.json" ]; then
  echo "No active SDK Bridge run found (no prd.json)."
  exit 0
fi

if ! jq empty prd.json 2>/dev/null; then
  echo "Error: prd.json is invalid JSON."
  exit 1
fi

PROJECT=$(jq -r '.project // "Unknown"' prd.json)
BRANCH=$(jq -r '.branchName // "unknown"' prd.json)
TOTAL=$(jq '.userStories | length' prd.json)
DONE=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json)
PENDING=$((TOTAL - DONE))

echo "SDK Bridge Status: ${PROJECT}"
echo "Branch: ${BRANCH}"
echo "Progress: ${DONE}/${TOTAL} stories complete"

if [ "$PENDING" -eq 0 ]; then
  echo "All stories complete! Run reviewer/code-reviewer if not already done."
else
  echo ""
  echo "Incomplete stories:"
  jq -r '.userStories[] | select(.passes == false) | "  - \(.id): \(.title)"' prd.json
  echo ""
  echo "To resume: run /sdk-bridge:start — it will detect the existing prd.json and continue."
fi
```

**Step 2: Make executable and validate**
```bash
chmod +x scripts/watchdog.sh
bash -n scripts/watchdog.sh && echo "Syntax OK"
```

**Step 3: Commit**
```bash
git add scripts/watchdog.sh && git commit -m "feat: add watchdog script for crash recovery guidance"
```

---

### Task 13: Update check-deps.sh for Agent Teams

**Files:** Modify: `scripts/check-deps.sh`

**Step 1: Update the script**

Changes:
- Remove coreutils/timeout check (no bash loop = no timeout needed)
- Add Agent Teams environment check
- Keep: claude CLI check, jq check

```bash
#!/bin/bash
# Dependency checker for SDK Bridge v7 (Agent Teams)
set -e

MISSING=()
WARNINGS=()

# Check for claude CLI
if ! command -v claude &> /dev/null; then
  MISSING+=("claude")
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  MISSING+=("jq")
fi

# Check Agent Teams enablement
if [ -z "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ] || [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  WARNINGS+=("agent-teams")
fi

# Output results
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "WARNINGS: ${WARNINGS[*]}" >&2
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  exit 0
else
  echo "${MISSING[*]}"
  exit 1
fi
```

**Step 2: Validate syntax**
```bash
bash -n scripts/check-deps.sh && echo "Syntax OK"
```

**Step 3: Commit**
```bash
git add scripts/check-deps.sh && git commit -m "feat: update check-deps for Agent Teams (add teams check, remove coreutils)"
```

---

### Task 14: Update prd.json.example

**Files:** Modify: `scripts/prd.json.example`

**Step 1: Update the example**

Same schema but add a note about parallel execution. Ensure the example shows stories with and without dependencies to illustrate parallelism.

**Step 2: Commit**
```bash
git add scripts/prd.json.example && git commit -m "docs: update prd.json.example with dependency graph for parallel execution"
```

---

### Task 15: Rewrite commands/start.md (the orchestrator)

**Files:** Modify: `commands/start.md`

This is the biggest task — the start command becomes the team lead orchestrator. No more bash loop launch.

**Step 1: Rewrite start.md**

The new command has 5 checkpoints (down from 7) plus the orchestration loop:

**Frontmatter:**
```yaml
---
description: "Start SDK Bridge — generates PRD, converts to JSON, orchestrates Agent Teams for parallel implementation"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion", "Agent", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate"]
---
```

**Checkpoint 1: Dependencies**
- Run check-deps.sh
- If Agent Teams not enabled: prompt user to enable with exact instructions
- Verify all deps present

**Checkpoint 2: PRD Generation**
- Same flow: get user input, invoke prd-generator skill
- Keep the file path detection, interview flow

**Checkpoint 3: PRD Review**
- Same AskUserQuestion flow: approve, suggest improvements, edit, start over

**Checkpoint 4: Convert to JSON**
- Invoke prd-converter skill
- NEW: Display dependency graph analysis:
  - Which stories can run in parallel
  - Which are blocked
  - Suggested teammate count

**Checkpoint 5: Configuration**
- Simplified: only 2 questions:
  1. Quality commands (auto-detect or specify) — same as before
  2. Code review (yes/no) — same as before
- Write `.claude/sdk-bridge.config.json` with simplified schema:
  ```json
  {
    "max_teammates": 5,
    "branch_prefix": "sdk-bridge",
    "test_command": "",
    "build_command": "",
    "typecheck_command": "",
    "code_review": true
  }
  ```

**Orchestration Phase (after checkpoints):**

The command itself becomes the team lead. Instructions for Claude to:

1. **Create feature branch**: `git checkout -b [branchName]`
2. **Analyze dependency graph**: Read prd.json, identify parallelizable stories
3. **Create tasks**: Use TaskCreate for each story, set blockedBy from depends_on
4. **Calculate teammate count**: min(max_teammates, number of independent story groups)
5. **Spawn teammates**: "Create an agent team with N implementer teammates. Each teammate should claim tasks from the task list, implement with TDD, commit, and mark tasks complete."
6. **Monitor**: Wait for all tasks to complete
7. **Handle failures**: If a teammate gets stuck, message it with guidance
8. **Post-completion**: When all tasks done:
   - Spawn reviewer subagent on full diff
   - If code_review enabled: spawn code-reviewer subagent
   - Report results
9. **Update prd.json**: Mark all stories as `passes: true`
10. **Append to progress.jsonl**: Final summary entry
11. **Clean up team**

**Step 2: Validate**
```bash
head -5 commands/start.md | grep "description"
```

**Step 3: Commit**
```bash
git add commands/start.md && git commit -m "feat: rewrite start command as Agent Teams orchestrator (replaces bash loop)"
```

---

### Task 16: Update plugin.json to v7.0.0

**Files:** Modify: `.claude-plugin/plugin.json`

**Step 1: Update manifest**

```json
{
  "name": "sdk-bridge",
  "version": "7.0.0",
  "description": "PRD-driven parallel development — generates PRDs, orchestrates Agent Teams for parallel story implementation with shared task coordination, two-stage review, and TDD enforcement.",
  "author": {
    "name": "Jesper Vang",
    "email": "jesper_vang@me.com",
    "url": "https://github.com/flight505"
  },
  "license": "MIT",
  "repository": "https://github.com/flight505/sdk-bridge",
  "homepage": "https://github.com/flight505/sdk-bridge",
  "keywords": [
    "claude-cli",
    "agent-teams",
    "prd",
    "parallel",
    "autonomous",
    "tdd",
    "code-review"
  ],
  "commands": [
    "./commands/start.md"
  ],
  "skills": [
    "./skills/prd-generator",
    "./skills/prd-converter"
  ],
  "agents": [
    "./agents/implementer.md",
    "./agents/reviewer.md",
    "./agents/code-reviewer.md"
  ]
}
```

**Step 2: Validate**
```bash
jq . .claude-plugin/plugin.json > /dev/null && echo "Valid JSON"
jq '.version, .agents | length' .claude-plugin/plugin.json
```
Expected: `"7.0.0"` and `3`

**Step 3: Commit**
```bash
git add .claude-plugin/plugin.json && git commit -m "feat: bump to v7.0.0 — Agent Teams architecture"
```

---

### Task 17: Rewrite CLAUDE.md

**Files:** Modify: `CLAUDE.md`

**Step 1: Complete rewrite**

Update for v7.0 architecture:
- Overview: Agent Teams orchestration, not bash loop
- Architecture diagram: 3 agents (not 5), 4 hooks (not 5+1), 2 skills (not 3)
- Subagents table: implementer (teammate), reviewer (subagent), code-reviewer (subagent)
- Hooks table: SessionStart, TaskCompleted, TeammateIdle, PreCompact
- State files: prd.json, progress.jsonl (not progress.txt), config.json
- Configuration: simplified schema (no iterations, timeout, execution_mode)
- Execution flow: Agent Teams, not bash loop
- Gotchas: Agent Teams experimental, no session resume, token cost
- Remove: all references to bash loop, PID files, prompt.md, architect, merger, failure-analyzer

**Step 2: Commit**
```bash
git add CLAUDE.md && git commit -m "docs: rewrite CLAUDE.md for v7.0 Agent Teams architecture"
```

---

### Task 18: Rewrite README.md

**Files:** Modify: `README.md`

**Step 1: Complete rewrite**

Focus on:
- Hero: "PRD-driven parallel development with Agent Teams"
- Prerequisites: Claude Code v2.1.32+, Agent Teams enabled
- Quick start: `/sdk-bridge:start`
- How it works: PRD → JSON → Agent Teams → parallel implementation
- Architecture: simplified diagram
- Configuration: new schema
- Keep: examples, assets references

**Step 2: Commit**
```bash
git add README.md && git commit -m "docs: rewrite README.md for v7.0 Agent Teams architecture"
```

---

## Execution Order & Dependencies

```
Task 1 (cleanup) ──────────────────────┐
                                        │
Tasks 2-6 (hooks) ─── all parallel ─────┤
Tasks 7-9 (agents) ── all parallel ─────┤── all independent
Tasks 10-11 (skills) ─ all parallel ────┤
Tasks 12-14 (scripts) ─ all parallel ───┤
                                        │
Task 15 (start.md) ────────────────────── depends on 1-14
Task 16 (plugin.json) ─────────────────── depends on 15
Tasks 17-18 (docs) ── parallel ─────────── depends on 15
```

**13 tasks can run in parallel** (2-14). Task 1 should run first. Task 15 depends on all others. Tasks 16-18 depend on 15.
