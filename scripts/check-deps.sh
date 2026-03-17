#!/bin/bash
# Dependency checker for SDK Bridge v7 (Agent Teams)
set -e

MISSING=()
WARNINGS=()

# Check for claude CLI
if ! command -v claude &> /dev/null; then
  MISSING+=("claude")
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  MISSING+=("jq")
fi

# Check Agent Teams enablement
if [ -z "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ] || [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" != "1" ]; then
  WARNINGS+=("agent-teams")
fi

# Output results
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "WARNINGS: ${WARNINGS[*]}" >&2
fi

if [ ${#MISSING[@]} -eq 0 ]; then
  exit 0
else
  echo "${MISSING[*]}"
  exit 1
fi
