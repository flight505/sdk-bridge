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
