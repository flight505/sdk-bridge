#!/usr/bin/env bash
# SubagentStart hook for SDK-Bridge plugin
# Injects codebase patterns from progress.txt into implementer context
# so the agent starts with accumulated knowledge from previous iterations.
#
# Output: JSON on stdout with hookSpecificOutput.additionalContext
# Exit 0 always

context=""

# Inject codebase patterns section from progress.txt
if [ -f "progress.txt" ]; then
  PATTERNS=$(sed -n '/^## Codebase Patterns/,/^---/p' progress.txt 2>/dev/null | head -40)
  if [ -n "$PATTERNS" ]; then
    context="**Codebase Patterns (from previous iterations):**
${PATTERNS}"
  fi
fi

# Inject recent learnings (last 3 iteration blocks)
if [ -f "progress.txt" ]; then
  RECENT=$(grep -A 5 "Learnings for future iterations" progress.txt 2>/dev/null | tail -20)
  if [ -n "$RECENT" ]; then
    context="${context}

**Recent Learnings:**
${RECENT}"
  fi
fi

if [ -z "$context" ]; then
  exit 0
fi

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "SubagentStart",
    additionalContext: $ctx
  }
}'

exit 0
