---
description: "Start SDK Bridge interactive wizard - generates PRD, converts to JSON, and runs autonomous agent loop"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "Edit", "Task", "AskUserQuestion", "TodoWrite"]
---

# SDK Bridge Start

Interactive wizard that guides you through the complete SDK Bridge workflow:
1. Describe your project/feature
2. Generate PRD with clarifying questions
3. Review and approve PRD
4. Convert to execution format
5. Configure execution settings
6. Launch autonomous agent loop

## Execution

**Checkpoint 1: Check Dependencies**

First, verify required dependencies are installed:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

If dependencies are missing, use AskUserQuestion to ask:
"SDK Bridge requires these tools: [list missing]. Install automatically?"
- Options: "Yes - install for me" / "No - I'll install manually"

If user approves automatic install:
- For claude CLI: Explain that the `claude` command comes with Claude Code and should already be available. If not found, the user may need to reinstall Claude Code or add it to their PATH.
- For jq on macOS: `brew install jq`
- For jq on Linux: Show instructions for apt/yum (e.g., `sudo apt-get install jq` or `sudo yum install jq`)
- For coreutils on macOS: `brew install coreutils` (provides gtimeout command for iteration timeouts)
- For coreutils on Linux: Usually pre-installed; if missing: `sudo apt-get install coreutils` or `sudo yum install coreutils`

If user declines or install fails, show manual installation instructions and exit.

**Checkpoint 2: Project Input**

Use AskUserQuestion to ask:
"Describe your feature or project. You can type a description or use @file to reference a spec/outline."

Text field for user input (supports @file references).

**Checkpoint 3: Generate PRD**

Load the `prd-generator` skill using Task tool:
```
Use the prd-generator skill to create a PRD based on the user's input: [user's description]
```

The skill will:
- Ask 3-5 clarifying questions with lettered options
- Generate structured PRD
- Save to `tasks/prd-[feature-name].md`

**Checkpoint 4: Review PRD**

Open the PRD file with the default editor:
- Run `open tasks/prd-[feature-name].md` to open with default app

Use AskUserQuestion:
"Review the PRD in `tasks/prd-[feature-name].md`. Ready to proceed?"
- Options: "Approved - convert to JSON" / "Need more edits - wait" / "Start over"

If "wait", pause and ask again after user confirms edits saved.
If "start over", return to Checkpoint 2.

**Checkpoint 5: Convert to JSON**

Load the `prd-converter` skill using Task tool:
```
Use the prd-converter skill to convert tasks/prd-[feature-name].md to prd.json
```

The skill will:
- Convert markdown PRD to JSON format
- Validate structure (IDs, priorities, acceptance criteria)
- Save to `prd.json` in project root

**Checkpoint 6: Execution Settings**

Create `.claude/sdk-bridge.local.md` configuration if it doesn't exist.

Use AskUserQuestion to collect settings:

Question 1: "Max iterations before stopping?"
- Default value: "10"
- Text field for number

Question 2: "Execution mode?"
- Options: "Foreground (see live output)" / "Background (continue working)"

Create config file:
```yaml
---
max_iterations: [user's answer]
iteration_timeout: 900
editor_command: "open"
branch_prefix: "sdk-bridge"
execution_mode: [foreground|background]
---

# SDK Bridge Configuration

Edit these settings as needed and run `/sdk-bridge:start` again.
```

**Checkpoint 7: Launch**

Show user what will happen:
"Starting SDK Bridge with [max_iterations] iterations in [mode] mode..."

If **foreground mode**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdk-bridge.sh [max_iterations]
```

User sees live output. Loop continues until:
- All stories complete (outputs `<promise>COMPLETE</promise>`)
- Max iterations reached
- User presses Ctrl+C

If **background mode**:
```bash
mkdir -p .claude
nohup bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdk-bridge.sh [max_iterations] > .claude/sdk-bridge.log 2>&1 &
echo $! > .claude/sdk-bridge.pid
```

Then tell user:
"SDK Bridge running in background (PID: [pid])"
"View logs: tail -f .claude/sdk-bridge.log"
"Check status: ps -p [pid]"

## Error Handling

- If prd.json already exists, warn user: "Found existing prd.json. This will be archived when you run SDK Bridge."
- If tasks/ directory doesn't exist, create it
- If claude or jq not found and user declines install, exit gracefully with install instructions
- If skill loading fails, show helpful error message

## Success Output

When complete (foreground mode):
"SDK Bridge completed [X] iterations"
"Completed stories: [count]"
"Check prd.json for status"
"Review progress.txt for learnings"

When launched (background mode):
"SDK Bridge launched in background"
"Monitor with: tail -f .claude/sdk-bridge.log"
"Or check prd.json for completion status"

## Important Notes

- Use TodoWrite to track progress through checkpoints
- Keep user informed at each step
- Validate all file paths before operations
- Use ${CLAUDE_PLUGIN_ROOT} for script paths
- Handle both success and error cases gracefully
