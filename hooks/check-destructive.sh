#!/bin/bash
# SDK-Bridge — Block destructive git commands during active implementation runs
# Used as a PreToolUse hook for Bash commands
# Reads hook JSON from stdin, extracts the command, checks for destructive ops
#
# IMPORTANT: Guards only activate when an sdk-bridge run is in progress
# (detected by .claude/sdk-bridge-*.pid file). When no run is active,
# all commands pass through — the plugin must not interfere with normal workflows.
#
# Exit codes:
#   0 = allow (with optional JSON deny on stdout for blocked commands)
#   PreToolUse uses JSON permissionDecision, not exit 2
#
# NOTE: set -e intentionally omitted — hook requires explicit exit code control

# Read hook input from stdin and extract the bash command
HOOK_INPUT=$(cat)
INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# If no command or jq failed, allow through
if [ -z "$INPUT" ]; then
  exit 0
fi

# Only activate guards when an sdk-bridge run is in progress
# The bash loop creates .claude/sdk-bridge-{branch}.pid during execution
SDK_BRIDGE_ACTIVE=false
for pidfile in .claude/sdk-bridge-*.pid; do
  if [ -f "$pidfile" ]; then
    PID=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      SDK_BRIDGE_ACTIVE=true
      break
    fi
  fi
done

# No active run — allow everything
if [ "$SDK_BRIDGE_ACTIVE" = "false" ]; then
  exit 0
fi

deny() {
  local git_context
  git_context=$(git status --short 2>/dev/null | head -20) || git_context=""
  local full_reason="$1
Blocked command: $INPUT"
  if [ -n "$git_context" ]; then
    full_reason="${full_reason}
Current git status:
${git_context}"
  fi

  jq -n --arg reason "$full_reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Check for destructive git operations
# Allows --force-with-lease (safer alternative to --force)
if echo "$INPUT" | grep -qE 'git\s+reset\s+--hard'; then
  deny "Destructive git command detected. SDK-Bridge prevents hard-reset during implementation."
elif echo "$INPUT" | grep -qE 'git\s+clean\s+-[a-z]*f'; then
  deny "Destructive git command detected. SDK-Bridge prevents git clean -f during implementation."
elif echo "$INPUT" | grep -qE 'git\s+push\s+' && ! echo "$INPUT" | grep -qE '\-\-force-with-lease'; then
  if echo "$INPUT" | grep -qE 'git\s+push\s+.*(--force\b|-f\b)'; then
    deny "Destructive git command detected. SDK-Bridge prevents force-push during implementation. Use --force-with-lease instead."
  fi
fi

# Check for pushing to main/master directly during an active run
if echo "$INPUT" | grep -qE 'git\s+push\s+(origin\s+)?(main|master)(\s|$)'; then
  deny "Direct push to main/master not allowed during active SDK-Bridge run. The merger agent handles branch merges."
fi

exit 0
