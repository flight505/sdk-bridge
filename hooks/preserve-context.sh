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
