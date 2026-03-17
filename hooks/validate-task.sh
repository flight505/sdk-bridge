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
