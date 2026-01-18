---
description: "Interactive task decomposition - transform description into feature_list.json"
argument-hint: ""
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion", "Skill", "TodoWrite"]
---

# SDK Bridge Decompose - Task to Features

Transform a high-level task description into a structured, dependency-aware `feature_list.json` ready for autonomous execution.

## Overview

This command guides you through an interactive process:
1. **Input Collection** - Describe what to build (text, file, or file+focus)
2. **Decomposition** - LLM breaks down task into structured features
3. **Review & Edit** - Interactively refine the proposed features
4. **Validation** - Computational checks for schema, dependencies, cycles
5. **Generation** - Create feature_list.json in topological order

## Phase 1: Setup Progress Tracking

Use TodoWrite to show user what's happening:

```
Use TodoWrite to create:
- ⏳ Collecting task description
- ⏳ Decomposing into features
- ⏳ Preparing for review
- ⏳ Validating dependencies
- ⏳ Generating feature_list.json
```

## Phase 2: Input Collection

Ask user how they want to describe the task:

**Question 1: Input Method**

```
Use AskUserQuestion:

question: "How would you like to describe what to build?"
header: "Task Input"
multiSelect: false
options:
  - label: "Type description now"
    description: "Enter a natural language description of what you want to build. Best for simple projects or quick experiments."
  - label: "Point to a .md file"
    description: "Provide a path to a markdown file containing requirements, specs, or a project plan."
  - label: "Point to .md with specific focus"
    description: "Provide a .md file path plus specific instructions about which parts to implement."
```

Update TodoWrite: ✅ Collected task description

### Handle Input Modes

**If "Type description now":**

```
Use AskUserQuestion with text input:

question: "Describe what you want to build (be specific about functionality, tech stack, and key features):"
header: "Description"
```

Store response in variable `TASK_DESCRIPTION`.

**If "Point to a .md file":**

```
Use AskUserQuestion:

question: "Enter the path to your specification file:"
header: "File Path"
```

Then read the file:
```bash
SPEC_FILE="<user_provided_path>"

if [ ! -f "$SPEC_FILE" ]; then
  echo "❌ File not found: $SPEC_FILE"
  echo "Please provide a valid file path and run /sdk-bridge:decompose again."
  exit 1
fi

# Read file content
TASK_DESCRIPTION=$(cat "$SPEC_FILE")
```

**If "Point to .md with specific focus":**

```
First, ask for file path (same as above).
Then ask for focus:

Use AskUserQuestion:

question: "What specific parts should be implemented? (e.g., 'Only implement the authentication module from sections 2-4')"
header: "Focus Area"
```

Combine file content + focus:
```bash
FOCUS="<user_provided_focus>"
TASK_DESCRIPTION="Source: $SPEC_FILE

Focus: $FOCUS

Full content:
$(cat "$SPEC_FILE")"
```

## Phase 3: Task Decomposition

Update TodoWrite: ⏳ Decomposing into features (in_progress)

Invoke the decompose-task skill to analyze and break down the task:

```
Use Skill tool:
  skill: "decompose-task"

The skill will guide you through:
- Parsing requirements and identifying tech stack
- Identifying software layers (infrastructure, data, logic, interface, integration)
- Generating features with dependencies, priorities, test criteria
- Following DRY/YAGNI/TDD principles
- Proper granularity (5-25 features typically)
```

The skill will produce a JSON array of features. Store this in memory as `PROPOSED_FEATURES`.

Example output from skill:
```json
[
  {
    "id": "feat-001",
    "description": "Set up Express.js server with cors and json middleware",
    "test": "GET /health returns 200 OK with {status: 'healthy'}",
    "dependencies": [],
    "tags": ["infrastructure", "backend"],
    "priority": 100,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Configure PostgreSQL connection pool with pg-pool",
    "test": "Can execute SELECT 1 query without error",
    "dependencies": ["feat-001"],
    "tags": ["database", "infrastructure"],
    "priority": 90,
    "passes": false
  }
]
```

Update TodoWrite: ✅ Decomposed into features

## Phase 4: Interactive Review

Update TodoWrite: ⏳ Preparing for review (in_progress)

Present features to user for review and selection:

```
Use AskUserQuestion with multi-select:

question: "Review the proposed features. Uncheck any you want to exclude."
header: "Feature Review"
multiSelect: true
options:
  # Generate one option per feature
  - label: "[feat-001] Set up Express.js server"
    description: "Priority: 100 | Dependencies: none | Test: GET /health returns 200"
  - label: "[feat-002] Add PostgreSQL connection pool"
    description: "Priority: 90 | Dependencies: feat-001 | Test: Can connect to database"
  # ... more features
```

**Format each option as:**
```
label: "[{id}] {first 50 chars of description}"
description: "Priority: {priority} | Dependencies: {deps or 'none'} | Test: {first 60 chars of test}"
```

Store selected feature IDs in `SELECTED_FEATURES`.

Update TodoWrite: ✅ Features reviewed and selected

### Offer Customization

Ask if user wants to make changes:

```
Use AskUserQuestion:

question: "Would you like to make any changes?"
header: "Customize"
multiSelect: false
options:
  - label: "Looks good - proceed to validation"
    description: "Accept the selected features and continue"
  - label: "Add more features"
    description: "Describe additional features to add to the list"
  - label: "Edit a feature"
    description: "Modify the description, test, or dependencies of a feature"
  - label: "Regenerate completely"
    description: "Start over with a refined description"
```

**Handle responses:**

**If "Looks good":** Continue to Phase 5

**If "Add more features":**
```
Ask user: "Describe the additional features you want to add:"

Invoke decompose-task skill again with:
- Original task description
- Existing features (for context/dependencies)
- New feature requests

Merge new features into PROPOSED_FEATURES
Re-present for review (loop back to Phase 4 start)
```

**If "Edit a feature":**
```
Ask: "Which feature ID do you want to edit? (e.g., feat-003)"
Show current values for that feature
Ask: "What would you like to change? (description, test, dependencies, priority)"
Update the feature
Re-present for review (loop back to Phase 4 start)
```

**If "Regenerate completely":**
```
Ask: "Provide a refined or more detailed description:"
Store as new TASK_DESCRIPTION
Loop back to Phase 3 (decomposition)
```

## Phase 5: Validation

Update TodoWrite: ⏳ Validating dependencies (in_progress)

Filter `PROPOSED_FEATURES` to only include `SELECTED_FEATURES`, then validate:

```bash
#!/bin/bash
set -euo pipefail

# Write selected features to temp file
TEMP_FEATURES=$(mktemp)
echo "$SELECTED_FEATURES_JSON" > "$TEMP_FEATURES"

# Validate using dependency_graph.py
VALIDATION_OUTPUT=$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/dependency_graph.py" validate "$TEMP_FEATURES" 2>&1)
VALIDATION_EXIT=$?

# Show results
echo "$VALIDATION_OUTPUT"

if [ $VALIDATION_EXIT -ne 0 ]; then
  echo ""
  echo "❌ Validation failed. Please review errors above."
  echo ""
  echo "Options:"
  echo "1. Run /sdk-bridge:decompose again to regenerate"
  echo "2. Manually edit the proposed features"
  echo "3. Proceed anyway (risky - may cause runtime failures)"
  echo ""
  exit 1
fi

# Clean up
rm -f "$TEMP_FEATURES"
```

**Example validation output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   SCHEMA VALIDATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Valid (12 features, all required fields present)

⚠️  Warnings:
  • Feature feat-007: Description very short (18 chars)
  • Feature feat-011: Missing test criteria

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   DEPENDENCY VALIDATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Valid (no cycles, all refs exist)

⚠️  Warnings:
  • Deep dependency chain detected: 6 levels (consider flattening)
```

If there are warnings but no errors, ask user:
```
Use AskUserQuestion:

question: "Validation passed with warnings. Proceed anyway?"
header: "Warnings"
multiSelect: false
options:
  - label: "Yes - continue"
    description: "Warnings are non-blocking. Generate feature_list.json."
  - label: "No - let me refine"
    description: "Go back to review and fix warnings"
```

Update TodoWrite: ✅ Validation complete

## Phase 6: Topological Sort & Generate

Update TodoWrite: ⏳ Generating feature_list.json (in_progress)

Reorder features in topological order (dependencies first):

```bash
#!/bin/bash
set -euo pipefail

# Write selected features to temp file
TEMP_INPUT=$(mktemp)
echo "$SELECTED_FEATURES_JSON" > "$TEMP_INPUT"

# Reorder topologically
TEMP_OUTPUT=$(mktemp)
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/dependency_graph.py" reorder "$TEMP_INPUT" --output "$TEMP_OUTPUT"

# Read reordered features
REORDERED_FEATURES=$(cat "$TEMP_OUTPUT")

# Write to project root
echo "$REORDERED_FEATURES" > feature_list.json

# Clean up
rm -f "$TEMP_INPUT" "$TEMP_OUTPUT"

echo "✅ Created feature_list.json with $(echo "$REORDERED_FEATURES" | jq 'length') features"
```

### Also Create Decomposition Log

Save metadata about this decomposition for debugging:

```bash
mkdir -p .claude

cat > .claude/decomposition-log.json << EOF
{
  "version": "3.0.0",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "input_mode": "$INPUT_MODE",
  "input_source": "$INPUT_SOURCE",
  "input_focus": "$INPUT_FOCUS",
  "task_description_length": ${#TASK_DESCRIPTION},
  "features_generated": $TOTAL_GENERATED,
  "features_accepted": $TOTAL_ACCEPTED,
  "features_excluded": $TOTAL_EXCLUDED,
  "validation_warnings": $WARNING_COUNT,
  "topological_levels": $LEVEL_COUNT
}
EOF

echo "✅ Saved metadata to .claude/decomposition-log.json"
```

## Phase 7: Success Summary

Update TodoWrite: ✅ Generated feature_list.json

Show final summary:

```
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   DECOMPOSITION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Created feature_list.json with $FEATURE_COUNT features"
echo ""
echo "📊 Statistics:"
echo "   Input Mode: $INPUT_MODE"
echo "   Features Generated: $TOTAL_GENERATED"
echo "   Features Selected: $TOTAL_ACCEPTED"
echo "   Execution Levels: $LEVEL_COUNT"
echo ""
echo "📁 Files Created:"
echo "   • feature_list.json (topologically sorted)"
echo "   • .claude/decomposition-log.json (metadata)"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "   1. Review feature_list.json to verify features"
echo "   2. Run /sdk-bridge:start to configure and launch agent"
echo "   3. (Optional) Run /sdk-bridge:plan for parallel execution analysis"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
```

## Error Handling

**If user cancels at any point:**
- Save partial progress to `.claude/decomposition-draft.json`
- Tell user they can resume with `/sdk-bridge:decompose`

**If validation fails:**
- Show specific errors
- Offer to go back to review/edit
- Do not create feature_list.json with errors

**If file read fails:**
- Clear error message
- Suggest checking file path
- Offer to switch to text input mode

## Example Usage

**Simple project:**
```
User: /sdk-bridge:decompose
  → "Type description now"
  → "Build a REST API for user authentication with JWT"
  → Reviews 8 features
  → Accepts all
  → feature_list.json created
```

**Complex project:**
```
User: /sdk-bridge:decompose
  → "Point to .md with specific focus"
  → File: docs/full-spec.md
  → Focus: "Only authentication module from section 2"
  → Reviews 12 features
  → Excludes 3 optional features
  → Adds 1 custom feature
  → feature_list.json created
```

## Notes

- This command is idempotent - can run multiple times
- Each run overwrites feature_list.json (old one not backed up)
- Decomposition log is cumulative (appends each run)
- Works standalone or as part of `/sdk-bridge:start` flow
