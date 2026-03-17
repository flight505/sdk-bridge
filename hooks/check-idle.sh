#!/bin/bash
# TeammateIdle hook — prevents teammates from stopping while work remains
# Exit 0: allow idle (all work done)
# Exit 2: block idle, stderr sent as feedback
set -e

# Check for prd.json
if [ ! -f "prd.json" ]; then
  exit 0  # No PRD = nothing to check
fi

# Count incomplete stories
REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' prd.json 2>/dev/null || echo "0")

if [ "$REMAINING" -gt 0 ]; then
  # Get next available story
  NEXT=$(jq -r '[.userStories[] | select(.passes == false)][0] | "\(.id): \(.title)"' prd.json 2>/dev/null || echo "unknown")
  echo "There are still ${REMAINING} incomplete stories. Next: ${NEXT}. Check the task list for unclaimed work." >&2
  exit 2
fi

exit 0
