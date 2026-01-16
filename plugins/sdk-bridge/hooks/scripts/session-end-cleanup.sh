#!/bin/bash
# SessionEnd cleanup hook - archives logs and creates state backups
# Runs when Claude Code session ends while SDK Bridge is still running

set -euo pipefail

# Only proceed if this is an SDK Bridge project
if [ ! -f ".claude/sdk-bridge.local.md" ]; then
  exit 0
fi

# Create logs directory
mkdir -p .claude/logs

# Archive current log file with timestamp
if [ -f ".claude/sdk-bridge.log" ]; then
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  cp ".claude/sdk-bridge.log" ".claude/logs/sdk-bridge-${TIMESTAMP}.log"
fi

# Create backups of state files if SDK is still running
if [ -f ".claude/sdk-bridge.pid" ]; then
  PID=$(cat ".claude/sdk-bridge.pid")

  # Check if process is actually running
  if ps -p "$PID" > /dev/null 2>&1; then
    TIMESTAMP=$(date +"%s")

    # Backup state files
    [ -f ".claude/handoff-context.json" ] && cp ".claude/handoff-context.json" ".claude/handoff-context.json.${TIMESTAMP}.bak"
    [ -f "feature_list.json" ] && cp "feature_list.json" "feature_list.json.${TIMESTAMP}.bak"
    [ -f "claude-progress.txt" ] && cp "claude-progress.txt" "claude-progress.txt.${TIMESTAMP}.bak"

    # Update handoff context to note session ended
    if [ -f ".claude/handoff-context.json" ] && command -v jq &> /dev/null; then
      TEMP_FILE=$(mktemp)
      jq '.session_ended = true | .last_session_end = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"' \
        ".claude/handoff-context.json" > "$TEMP_FILE"
      mv "$TEMP_FILE" ".claude/handoff-context.json"
    fi
  fi
fi

exit 0
