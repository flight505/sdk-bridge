#!/usr/bin/env bash
# SessionStart hook for SDK-Bridge plugin
# Injects active prd.json status at session start
#
# Output: JSON on stdout with hookSpecificOutput.additionalContext
# Exit 0 always

# Check for active prd.json
prd_status=""
if [ -f "prd.json" ]; then
  # Validate JSON first
  if ! jq empty prd.json 2>/dev/null; then
    prd_status="**Warning:** prd.json exists but contains invalid JSON. Run \`/sdk-bridge:start\` to regenerate."
  else
    project=$(jq -r '.project // "unknown"' prd.json 2>/dev/null) || project="unknown"
    total=$(jq '.userStories | length' prd.json 2>/dev/null) || total="0"
    done_count=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json 2>/dev/null) || done_count="0"
    pending=$(jq '[.userStories[] | select(.passes == false and (.status == "skipped" | not))] | length' prd.json 2>/dev/null) || pending="0"
    skipped=$(jq '[.userStories[] | select(.status == "skipped")] | length' prd.json 2>/dev/null) || skipped="0"

    if [ "$pending" -gt 0 ] 2>/dev/null; then
      prd_status="**Active SDK-Bridge Run Detected:**
Project: ${project}
Stories: ${done_count}/${total} complete, ${pending} pending, ${skipped} skipped

Run \`/sdk-bridge:start\` to resume execution."
    fi
  fi
fi

# Build context
session_context="You have SDK-Bridge — a PRD-driven autonomous development assistant.

Run \`/sdk-bridge:start\` to generate PRDs, convert to execution format, and run fresh Claude instances until all work is complete."

if [ -n "$prd_status" ]; then
  session_context="${session_context}

---
${prd_status}"
fi

# Output JSON using jq
jq -n --arg ctx "$session_context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'

exit 0
