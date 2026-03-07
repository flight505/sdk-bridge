#!/usr/bin/env bash
# PostToolUse hook for implementer agent
# Runs the project's configured typecheck/lint command after file edits.
# Lightweight — only runs typecheck (fastest), not full test suite.
#
# Exit 0 = allow (no issues or no config)
# Exit 2 = block with error details on stderr (agent fixes before continuing)

CONFIG_FILE=".claude/sdk-bridge.config.json"

# Only run if config exists with a typecheck command
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

TYPECHECK_CMD=$(jq -r '.typecheck_command // empty' "$CONFIG_FILE" 2>/dev/null)

# No typecheck configured — pass through
if [ -z "$TYPECHECK_CMD" ]; then
  exit 0
fi

# Run typecheck
OUTPUT=$(bash -c "$TYPECHECK_CMD" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  exit 0
fi

# Truncate to 2000 chars to keep context lean
TRUNCATED=$(echo "$OUTPUT" | head -c 2000)

echo "Typecheck failed after edit — fix before continuing:
${TRUNCATED}" >&2
exit 2
