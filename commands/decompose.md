---
description: "Generate feature_list.json from task description using LLM decomposition"
argument-hint: "[task description or --validate-only]"
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion", "Skill", "TodoWrite"]
---

# SDK Bridge Decompose - Assisted Task Decomposition

I'll help you decompose your task into a structured feature list for SDK Bridge.

## Step 1: Check for Existing feature_list.json

```bash
if [ -f "feature_list.json" ]; then
  FEATURE_COUNT=$(jq '. | length' feature_list.json 2>/dev/null || echo "0")
  echo "EXISTING_FILE"
  echo "FEATURE_COUNT=$FEATURE_COUNT"
else
  echo "NO_FILE"
fi
```

## Step 2: Handle Existing File

If `EXISTING_FILE` was printed, use AskUserQuestion:

```
question: "Found existing feature_list.json with $FEATURE_COUNT features. What would you like to do?"
header: "Existing Plan"
multiSelect: false
options:
  - label: "Validate only"
    description: "Check if the current file is valid without regenerating"
  - label: "Replace with new"
    description: "Archive current file and create fresh decomposition"
  - label: "Cancel"
    description: "Keep existing file and exit"
```

**If "Validate only"** → Skip to Step 6 (validation)
**If "Replace with new"** → Continue to Step 3
**If "Cancel"** → Exit with message "Keeping existing feature_list.json"

## Step 3: Collect Task Description

If no existing file OR user chose "Replace with new", use AskUserQuestion to get task:

```
question: "Describe what you want to build:"
header: "Task Input"
multiSelect: false
options:
  - label: "Simple project (1-2 sentences)"
    description: "e.g., 'Build a REST API for user authentication with JWT'"
  - label: "Complex project (detailed description)"
    description: "e.g., 'Full-stack todo app with React, Node.js, PostgreSQL, JWT auth, CRUD operations'"
  - label: "Provide as text file"
    description: "I'll ask for a file path to read the description from"
```

**If "Provide as text file":**
- Use second AskUserQuestion asking for file path
- Read file contents using Read tool
- Use contents as TASK_DESCRIPTION

**Otherwise:**
- Use second AskUserQuestion with free text input
- Use input as TASK_DESCRIPTION

## Step 4: Invoke Decomposition Skill

Create directories and prepare for decomposition:

```bash
mkdir -p .claude
```

Use Skill tool to invoke decompose-task:

```
I'm invoking the decompose-task skill to analyze your requirements and generate a structured feature list.

Task: {TASK_DESCRIPTION}
```

The skill will:
1. Parse the requirements
2. Identify software layers
3. Generate features with dependencies
4. Save to `.claude/proposed-features.json`

## Step 5: Review Proposed Features

Read the generated features:

```bash
cat .claude/proposed-features.json
```

Parse and present for review using AskUserQuestion with multiSelect:

```bash
# Build options array dynamically
OPTIONS=$(jq '[.[] | {
  label: "[" + .id + "] " + .description,
  description: "Priority: " + (.priority|tostring) + " | Dependencies: " + (if .dependencies | length > 0 then (.dependencies | join(", ")) else "none" end) + " | Test: " + .test,
  value: .id
}]' .claude/proposed-features.json)

# Present to user via AskUserQuestion
```

```
question: "Review the proposed features. All are selected by default - uncheck any you want to exclude."
header: "Feature Review"
multiSelect: true
options: {OPTIONS}  # Dynamically generated from JSON
```

**User selects features to include**

Filter the JSON to keep only selected features:

```bash
# Get selected feature IDs from AskUserQuestion response
SELECTED_IDS='["feat-001", "feat-003", "feat-005"]'  # Example

# Filter proposed features
jq --argjson selected "$SELECTED_IDS" '
  [.[] | select(.id as $id | $selected | index($id) != null)]
' .claude/proposed-features.json > .claude/filtered-features.json
```

## Step 6: Validate Features

Run validation using enhanced dependency_graph.py:

```bash
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

if [ -f "$HARNESS_DIR/dependency_graph.py" ]; then
  "$VENV_PYTHON" "$HARNESS_DIR/dependency_graph.py" validate .claude/filtered-features.json
  VALIDATION_EXIT=$?
else
  echo "⚠️  dependency_graph.py not found - skipping validation"
  VALIDATION_EXIT=0
fi
```

**If validation fails (exit code != 0):**

Show errors and ask:

```
question: "Validation found errors. How would you like to proceed?"
header: "Validation Failed"
multiSelect: false
options:
  - label: "Fix manually and retry"
    description: "Edit .claude/filtered-features.json yourself and run /sdk-bridge:decompose again"
  - label: "Regenerate completely"
    description: "Start over with a new task description"
  - label: "Cancel"
    description: "Exit without creating feature_list.json"
```

**If validation succeeds:**

Continue to Step 7

## Step 7: Topological Sort & Save

Reorder features topologically and save to project root:

```bash
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

# Reorder
"$VENV_PYTHON" "$HARNESS_DIR/dependency_graph.py" reorder .claude/filtered-features.json -o feature_list.json

# Verify saved
if [ -f "feature_list.json" ]; then
  FINAL_COUNT=$(jq '. | length' feature_list.json)
  echo "✅ Created feature_list.json with $FINAL_COUNT features"
else
  echo "❌ Failed to create feature_list.json"
  exit 1
fi
```

## Step 8: Summary & Next Steps

Display summary:

```bash
FEATURE_COUNT=$(jq '. | length' feature_list.json)
LEVELS=$(jq 'group_by(.dependencies | length) | length' feature_list.json)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   DECOMPOSITION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Statistics:"
echo "   Total Features: $FEATURE_COUNT"
echo "   Dependency Levels: $LEVELS"
echo ""
echo "📁 Files Created:"
echo "   feature_list.json - Validated, topologically sorted feature list"
echo "   .claude/proposed-features.json - Original LLM output"
echo "   .claude/filtered-features.json - After user review"
echo ""
echo "🚀 Next Steps:"
echo "   1. Review feature_list.json if needed"
echo "   2. Run: /sdk-bridge:start"
echo "   3. SDK Bridge will implement features autonomously"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## Notes

**Validation-Only Mode:**

If command is run with `--validate-only` argument:
- Skip input collection
- Read existing feature_list.json
- Run validation
- Display results
- Exit

**Error Recovery:**

If any step fails:
- Clear error messages
- Offer fix/retry/cancel options
- Don't leave partial state (clean up .claude/*.json)

**File Archiving:**

When replacing existing feature_list.json:
```bash
mv feature_list.json feature_list.json.backup.$(date +%Y%m%d-%H%M%S)
```
