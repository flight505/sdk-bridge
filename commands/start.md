---
description: "Start SDK Bridge interactive wizard - generates PRD, converts to JSON, and runs autonomous agent loop"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "Edit", "Task", "AskUserQuestion", "TodoWrite"]
---

# SDK Bridge Start

Interactive wizard that guides you through the complete SDK Bridge workflow:
1. Check dependencies
2. Describe your project/feature
3. Generate PRD with clarifying questions
4. Review and approve PRD
5. Convert to execution format
6. Configure execution settings
7. Launch autonomous agent loop

## Execution

**Checkpoint 1: Check Dependencies**

First, verify required dependencies are installed:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

If dependencies are missing, use AskUserQuestion:

Question: "SDK Bridge requires these tools: [list missing]. Install automatically?"
- Header: "Install"
- multiSelect: false
- Options:
  - Label: "Yes - install for me" | Description: "Automatically install missing dependencies"
  - Label: "No - I'll install manually" | Description: "Show installation instructions and exit"

If user approves automatic install:
- For claude CLI: Explain that the `claude` command comes with Claude Code and should already be available. If not found, the user may need to reinstall Claude Code or add it to their PATH.
- For jq on macOS: `brew install jq`
- For jq on Linux: Show instructions for apt/yum (e.g., `sudo apt-get install jq` or `sudo yum install jq`)
- For coreutils on macOS: `brew install coreutils` (provides gtimeout command for iteration timeouts)
- For coreutils on Linux: Usually pre-installed; if missing: `sudo apt-get install coreutils` or `sudo yum install coreutils`

If user declines or install fails, show manual installation instructions and exit.

**Optional: Optimize Planning Quality**

For best results, configure Opus for PRD generation (Steps 3 & 5 use subagents):

```bash
# Add to ~/.zshrc or ~/.bashrc
export CLAUDE_CODE_SUBAGENT_MODEL=opus
```

This makes the PRD generator and converter use Opus for superior reasoning. The planning phase only runs once, so the cost is minimal. Restart your terminal after adding this.

**Checkpoint 2: Project Input**

Ask the user directly for their project description:

"What would you like to build? Describe your project or provide a file path to an existing spec (e.g., ~/docs/spec.md or ./tasks/plan.md)."

Then wait for the user's response in the chat.

**After receiving response:**
- Store the user's message content in variable `user_input`
- Check if `user_input` looks like a file path:
  - Starts with `~/`, `./`, `/`, or `../`
  - OR ends with common extensions: `.md`, `.txt`, `.pdf`
- If it looks like a file path:
  - Expand `~` to user's home directory if needed
  - Use Read tool to read the file
  - If file exists: Store content as `project_input` and proceed to Checkpoint 3
  - If file doesn't exist: Show error and ask user to provide the description directly
- If it's not a file path:
  - Use `user_input` directly as `project_input`

**If input insufficient (less than 20 words and no file read):**

Conduct a smart interview to gather REQUIRED information:

1. **Project Type (REQUIRED)**: Ask "What type of project is this?"
   - Examples: web app, API, CLI tool, mobile app, library, script, etc.

2. **Main Functionality (REQUIRED)**: Ask "What's the core functionality or purpose?"
   - What problem does it solve?
   - What should users be able to do?

3. **Technical Preferences (optional)**: Ask if relevant:
   - "Any specific language, framework, or stack preferences?"
   - "Any existing systems this needs to integrate with?"

4. **Scale/Complexity (optional)**: Ask if needed for context:
   - "Is this a small feature, medium project, or large system?"

**When to proceed:**
- Once you have clear answers to both REQUIRED items (project type + main functionality), proceed automatically to Checkpoint 3
- No need to ask "do you have enough?" - use your judgment
- If user provides very detailed initial input (>50 words), skip interview entirely

**Example interview flow:**
```
User: "Build an auth system"  [insufficient]
You: "What type of project is this? (web app, API, mobile app, etc.)"
User: "It's a REST API"
You: "What's the core functionality? What should users be able to do with authentication?"
User: "User registration, login with email/password, JWT tokens"
[You now have: type=API, functionality=auth with registration/login/JWT]
→ Proceed to Checkpoint 3 automatically
```

- Proceed to Checkpoint 3

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

Question: "Review the PRD in `tasks/prd-[feature-name].md`. Ready to proceed?"
- Header: "PRD Review"
- multiSelect: false
- Options:
  - Label: "Approved - convert to JSON" | Description: "PRD looks good, proceed to execution format"
  - Label: "Suggest improvements" | Description: "Have Claude review and suggest enhancements"
  - Label: "Need edits - I'll edit" | Description: "Let me edit the file manually, then ask again"
  - Label: "Start over" | Description: "Regenerate PRD from scratch"

**After collecting answer:**

- **If "Approved - convert to JSON"**: Proceed to Checkpoint 5

- **If "Suggest improvements"**:
  1. Read the PRD file with Read tool
  2. Analyze the PRD for potential improvements:
     - Missing edge cases or error scenarios
     - Additional features that complement the core functionality
     - Acceptance criteria that could be more specific or testable
     - Dependencies between stories that weren't captured
     - Security, performance, or accessibility considerations
  3. Present findings to user conversationally:
     - "I've reviewed the PRD. Here are some suggestions:"
     - List 3-5 specific improvements with brief rationale
     - Ask conversationally: "Would you like me to update the PRD with these improvements?"
  4. Wait for user response in chat
  5. If user approves suggestions:
     - Update the PRD file with improvements using Edit tool
     - Display: "PRD updated with improvements"
  6. **Return to the beginning of Checkpoint 4**: Use AskUserQuestion again with the same 4 options (this creates a loop - user can approve improved PRD, request more improvements, manually edit, or start over)

- **If "Need edits - I'll edit"**:
  1. Pause and display "Make your edits to tasks/prd-[feature-name].md and let me know when ready."
  2. Wait for user confirmation in chat
  3. **Return to the beginning of Checkpoint 4**: Use AskUserQuestion again with the same 4 options

- **If "Start over"**: Return to Checkpoint 2

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

Use AskUserQuestion to collect settings (all 3 questions in one call for tabbed UI):

Question 1: "How many iterations before stopping?"
- Header: "Iterations"
- multiSelect: false
- Options:
  - Label: "5 iterations" | Description: "Quick experiments or small features"
  - Label: "10 iterations" | Description: "Standard projects (recommended)"
  - Label: "15 iterations" | Description: "Complex projects with many stories"
  - Label: "20 iterations" | Description: "Large refactors or extensive work"

Question 2: "How long should each story iteration be allowed to run?"
- Header: "Timeout"
- multiSelect: false
- Options:
  - Label: "10 minutes" | Description: "Quick fixes or simple additions"
  - Label: "20 minutes" | Description: "Standard complexity stories"
  - Label: "30 minutes" | Description: "Complex integrations, full-stack work (recommended)"
  - Label: "60 minutes" | Description: "Extremely complex - major refactors, extensive exploration"

Question 3: "How do you want to run SDK Bridge?"
- Header: "Mode"
- multiSelect: false
- Options:
  - Label: "Foreground" | Description: "See live output as Claude works (blocks terminal)"
  - Label: "Background" | Description: "Continue working while it runs (check .claude/sdk-bridge.log)"

Question 4: "Which model should implement the stories?"
- Header: "Model"
- multiSelect: false
- Options:
  - Label: "Sonnet" | Description: "Fast and efficient - good for most tasks (recommended)"
  - Label: "Opus" | Description: "Best quality - fewer bugs, better at complex code (slower, costs more for API users)"

**After collecting answers, parse values:**

For iterations (Question 1):
- "5 iterations" → 5
- "10 iterations" → 10
- "15 iterations" → 15
- "20 iterations" → 20
- Custom input (via "Other") → parse number from string

For timeout (Question 2):
- "10 minutes" → 600
- "20 minutes" → 1200
- "30 minutes" → 1800
- "60 minutes" → 3600
- Custom input (via "Other") → multiply number by 60

For mode (Question 3):
- "Foreground" → foreground
- "Background" → background

For model (Question 4):
- "Sonnet" → sonnet
- "Opus" → opus

Create config file with parsed values:
```yaml
---
max_iterations: [parsed number from Q1]
iteration_timeout: [parsed seconds from Q2]
execution_mode: [parsed mode from Q3]
execution_model: [parsed model from Q4]
editor_command: "open"
branch_prefix: "sdk-bridge"
---

# SDK Bridge Configuration

Edit these settings as needed and run `/sdk-bridge:start` again.
```

Example:
```yaml
---
max_iterations: 10
iteration_timeout: 900
execution_mode: foreground
execution_model: sonnet
editor_command: "open"
branch_prefix: "sdk-bridge"
---
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
