---
description: "Start SDK Bridge — generates PRD, converts to JSON, orchestrates Agent Teams for parallel implementation"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion", "Agent", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate"]
---

# SDK Bridge Start

Interactive wizard that guides you through the complete SDK Bridge workflow:
1. Check dependencies
2. Describe your project/feature
3. Generate PRD with clarifying questions
4. Review and approve PRD
5. Convert to JSON and analyze dependency graph
6. Configure quality settings
7. Orchestrate Agent Teams for parallel implementation

## Execution

**Checkpoint 1: Check Dependencies**

Run:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

If `claude` or `jq` is missing, use AskUserQuestion:

Question: "SDK Bridge requires: [list missing]. Install automatically?"
- Options: "Yes - install for me" | "No - I'll install manually"

If missing `jq` on macOS: `brew install jq`
If missing `jq` on Linux: `sudo apt-get install jq`
The `claude` command comes with Claude Code — if missing, reinstall Claude Code.

If check-deps.sh outputs a WARNING about `agent-teams`, display:

```
Agent Teams is not enabled. To enable:

  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

Add to your ~/.zshrc or ~/.bashrc and restart your terminal, then run /sdk-bridge:start again.
```

Exit if agent-teams is not enabled — SDK Bridge v7 requires it.

**Checkpoint 2: Project Input**

Ask: "What would you like to build? Describe your project or provide a file path to an existing spec (e.g., ~/docs/spec.md or ./tasks/plan.md)."

Wait for user response, then:
- If response looks like a file path (starts with `~/`, `./`, `/` or ends with `.md`, `.txt`): Read it
- If response is less than 20 words: Conduct smart interview (project type + core functionality)
- Otherwise: Use response directly as `project_input`

**Checkpoint 3: Generate PRD**

Invoke the `prd-generator` skill:
```
Use the prd-generator skill to create a PRD based on: [project_input]
```

The skill asks 3-5 clarifying questions, generates a structured PRD, and saves to `tasks/prd-[feature-name].md`.

**Checkpoint 4: Review PRD**

Use AskUserQuestion:

Question: "Review the PRD in `tasks/prd-[feature-name].md`. Ready to proceed?"
- Header: "PRD Review"
- Options:
  - "Approved - convert to JSON" → proceed to Checkpoint 5
  - "Suggest improvements" → Claude reviews and suggests, then return to Checkpoint 4
  - "Need edits - I'll edit" → wait for user, then return to Checkpoint 4
  - "Start over" → return to Checkpoint 2

**Checkpoint 5: Convert to JSON**

Invoke the `prd-converter` skill:
```
Use the prd-converter skill to convert tasks/prd-[feature-name].md to prd.json
```

The skill converts the PRD, validates structure, and saves to `prd.json`.

After conversion, the skill outputs a **dependency graph analysis**. Display it to the user:
```
Parallel groups (can run simultaneously):
- Group 1: US-001 (no deps)
- Group 2: US-002, US-003 (depend on US-001, independent of each other)
- Group 3: US-004 (depends on US-002, US-003)

Suggested teammate count: 2
```

Read prd.json and display summary: "[story_count] stories, [total_criteria] total criteria"

**Checkpoint 6: Configuration**

Create `.claude/sdk-bridge.config.json` if it doesn't exist.

**AskUserQuestion — Quality settings (2 questions):**

Question 1: "Does your project have test, build, or typecheck commands?"
- Header: "Quality Commands"
- Options:
  - "Auto-detect" → search package.json, Makefile, pyproject.toml for test/build/typecheck scripts
  - "I'll specify" → ask conversationally for test_command, build_command, typecheck_command
  - "Skip" → no quality commands

Question 2: "Enable code review after all stories complete? (Catches bugs and architecture issues)"
- Header: "Code Review"
- Options:
  - "Yes (Recommended)"
  - "No"

**Write config:**
```json
{
  "max_teammates": 5,
  "branch_prefix": "sdk-bridge",
  "test_command": "<from user or omit>",
  "build_command": "<from user or omit>",
  "typecheck_command": "<from user or omit>",
  "code_review": true
}
```

Omit empty command fields.

## Orchestration Phase

After all checkpoints pass, you become the **team lead**. Execute:

### Step 1: Create Feature Branch

```bash
git checkout -b [branchName from prd.json]
```

### Step 2: Analyze Dependency Graph

Read `prd.json`. Identify:
- Stories with no `depends_on` → can start immediately (Group 1)
- Stories whose `depends_on` are all in Group 1 → Group 2
- Continue grouping until all stories placed
- `max_parallelism` = size of largest group

### Step 3: Create Tasks

For each story in prd.json, use `TaskCreate` to create a task:
- Title: `[US-XXX]: [story title]`
- Description: Story description + acceptance criteria (formatted as a list)
- Set `blockedBy` for stories with `depends_on`

### Step 4: Calculate Teammate Count

```
teammate_count = min(max_teammates from config, max_parallelism)
```

### Step 5: Spawn Implementer Teammates

Use Agent tool to create an agent team:

```
Create an agent team with [teammate_count] implementer teammates.
Each teammate should:
1. Use TaskList to find unclaimed tasks (status: not_started, no blocked dependencies)
2. Use TaskUpdate to claim a task (set to in_progress)
3. Implement the story with TDD discipline
4. Commit changes
5. Append to progress.jsonl
6. Use TaskUpdate to mark task completed
7. Repeat from step 1 until no unclaimed tasks remain
```

Teammates share the filesystem and task list. They coordinate via TaskCreate/TaskUpdate.

### Step 6: Monitor Progress

Periodically check `TaskList` to see completed vs pending tasks. Wait until all tasks reach `completed` status.

If a teammate appears stuck (in_progress for too long with no progress), check progress.jsonl for recent activity and send a message to that teammate.

### Step 7: Post-Completion Review

When ALL tasks are completed:

1. **Spawn reviewer subagent** on full diff:
   ```
   Use the reviewer agent to review the full feature branch: [branchName]
   Review all [N] stories in prd.json against the complete git diff.
   ```

2. **If `code_review: true` in config and reviewer approves:**
   ```
   Use the code-reviewer agent to review the full feature branch: [branchName]
   ```

3. **Report results** to user

### Step 8: Update prd.json

Mark all completed stories as `passes: true`:
```bash
jq '.userStories = [.userStories[] | .passes = true]' prd.json > prd.json.tmp && mv prd.json.tmp prd.json
```

### Step 9: Append to progress.jsonl

```json
{"timestamp":"<ISO>","event":"run_complete","stories_total":<N>,"stories_completed":<N>,"branch":"<branch>"}
```

### Step 10: Summary

Report to user:
- Stories completed: N/N
- Reviewer verdict: approve/request_changes/reject
- Code review verdict: approve/request_changes (if enabled)
- Branch: [branchName] — ready to merge or push

## Error Handling

- If prd.json already exists with a different branchName: warn user and ask to archive or overwrite
- If tasks/ directory doesn't exist: create it
- If a teammate gets stuck in a loop: message it with specific guidance from progress.jsonl patterns
- If reviewer rejects: report issues clearly and ask user how to proceed
- If validation fails in TaskCompleted hook: the hook returns exit 2 with feedback — the teammate will fix and retry automatically

## Important Notes

- The orchestration loop (Steps 1-10) runs inline — you are the team lead, not a script
- Teammates run in parallel via Agent Teams — they share the filesystem
- Do NOT use the bash loop from v6 (`sdk-bridge.sh`) — it no longer exists
- Agent Teams requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
