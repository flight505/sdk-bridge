#!/usr/bin/env bash
# PreCompact hook for SDK-Bridge plugin
# Re-injects current story context before context compaction
# so the agent doesn't "forget" what it's working on.
#
# Output: JSON on stdout with hookSpecificOutput.additionalContext
# Exit 0 always

context=""

# Inject current story from prd.json
if [ -f "prd.json" ]; then
  CURRENT_STORY=$(jq -r '
    [.userStories[] | select(.passes == false)] | first //empty |
    "Story \(.id): \(.title)\nDescription: \(.description)\nAcceptance Criteria:\n\(.acceptanceCriteria | map("- " + .) | join("\n"))"
  ' prd.json 2>/dev/null)

  if [ -n "$CURRENT_STORY" ]; then
    context="**Current Story (re-injected before compaction):**
${CURRENT_STORY}"
  fi
fi

# Inject codebase patterns from progress.txt
if [ -f "progress.txt" ]; then
  PATTERNS=$(sed -n '/^## Codebase Patterns/,/^---/p' progress.txt 2>/dev/null | head -30)
  if [ -n "$PATTERNS" ]; then
    context="${context}

**Codebase Patterns (from progress.txt):**
${PATTERNS}"
  fi
fi

# Inject config commands for validation reference
CONFIG_FILE=".claude/sdk-bridge.config.json"
if [ -f "$CONFIG_FILE" ]; then
  TEST_CMD=$(jq -r '.test_command // empty' "$CONFIG_FILE" 2>/dev/null)
  BUILD_CMD=$(jq -r '.build_command // empty' "$CONFIG_FILE" 2>/dev/null)
  TYPECHECK_CMD=$(jq -r '.typecheck_command // empty' "$CONFIG_FILE" 2>/dev/null)
  if [ -n "$TEST_CMD" ] || [ -n "$BUILD_CMD" ] || [ -n "$TYPECHECK_CMD" ]; then
    context="${context}

**Quality Commands:**"
    if [ -n "$TEST_CMD" ]; then context="${context}
- Test: ${TEST_CMD}"; fi
    if [ -n "$BUILD_CMD" ]; then context="${context}
- Build: ${BUILD_CMD}"; fi
    if [ -n "$TYPECHECK_CMD" ]; then context="${context}
- Typecheck: ${TYPECHECK_CMD}"; fi
  fi
fi

if [ -z "$context" ]; then
  exit 0
fi

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "PreCompact",
    additionalContext: $ctx
  }
}'

exit 0
