#!/bin/bash
# Dependency checker for SDK Bridge
# Returns 0 if all dependencies present, 1 if missing
# Outputs list of missing dependencies to stdout

set -e

MISSING=()

# Check for amp CLI
if ! command -v amp &> /dev/null; then
  MISSING+=("amp")
fi

# Check for jq (JSON parser)
if ! command -v jq &> /dev/null; then
  MISSING+=("jq")
fi

# Output results
if [ ${#MISSING[@]} -eq 0 ]; then
  # All dependencies present
  exit 0
else
  # Output missing dependencies (space-separated)
  echo "${MISSING[@]}"
  exit 1
fi
