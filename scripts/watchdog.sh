#!/bin/bash
# SDK Bridge Watchdog — checks for incomplete runs and guides resume
# Usage: bash scripts/watchdog.sh
set -e

if [ ! -f "prd.json" ]; then
  echo "No active SDK Bridge run found (no prd.json)."
  exit 0
fi

if ! jq empty prd.json 2>/dev/null; then
  echo "Error: prd.json is invalid JSON."
  exit 1
fi

PROJECT=$(jq -r '.project // "Unknown"' prd.json)
BRANCH=$(jq -r '.branchName // "unknown"' prd.json)
TOTAL=$(jq '.userStories | length' prd.json)
DONE=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json)
PENDING=$((TOTAL - DONE))

echo "SDK Bridge Status: ${PROJECT}"
echo "Branch: ${BRANCH}"
echo "Progress: ${DONE}/${TOTAL} stories complete"

if [ "$PENDING" -eq 0 ]; then
  echo "All stories complete! Run reviewer/code-reviewer if not already done."
else
  echo ""
  echo "Incomplete stories:"
  jq -r '.userStories[] | select(.passes == false) | "  - \(.id): \(.title)"' prd.json
  echo ""
  echo "To resume: run /sdk-bridge:start — it will detect the existing prd.json and continue."
fi
