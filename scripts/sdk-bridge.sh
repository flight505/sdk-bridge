#!/bin/bash
# SDK Bridge - Long-running AI agent loop
# Usage: ./sdk-bridge.sh [max_iterations]

set -e

# Check authentication (OAuth preferred, API key as fallback)
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
  # OAuth authentication (primary - Max subscribers)
  unset ANTHROPIC_API_KEY ANTHROPIC_ADMIN_KEY
  echo "✓ Using Claude Code OAuth authentication"

elif [ -n "$ANTHROPIC_API_KEY" ]; then
  # API key fallback
  echo "✓ Using Anthropic API Key authentication"
  echo "💡 Tip: Max subscribers can use 'claude setup-token' for better rate limits"

else
  # No authentication found
  echo "Error: No authentication configured"
  echo ""
  echo "SDK Bridge requires authentication:"
  echo ""
  echo "Recommended: OAuth Token (Claude Max subscribers)"
  echo "  1. Run: claude setup-token"
  echo "  2. Copy the token and add to ~/.zshrc or ~/.zsh_secrets:"
  echo "     export CLAUDE_CODE_OAUTH_TOKEN='your-token'"
  echo "  3. Reload: source ~/.zshrc"
  echo ""
  echo "Alternative: API Key"
  echo "  1. Get from: https://console.anthropic.com/settings/keys"
  echo "  2. Add to ~/.zshrc or ~/.zsh_secrets:"
  echo "     export ANTHROPIC_API_KEY='your-key'"
  echo "  3. Reload: source ~/.zshrc"
  echo ""
  exit 1
fi

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Work in the user's project directory (current working directory)
PROJECT_DIR="$(pwd)"
PRD_FILE="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
ARCHIVE_DIR="$PROJECT_DIR/archive"
LAST_BRANCH_FILE="$PROJECT_DIR/.last-branch"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "sdk-bridge/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^sdk-bridge/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# SDK Bridge Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# SDK Bridge Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting SDK Bridge - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  SDK Bridge Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # Run fresh Claude agent with the sdk-bridge prompt
  # Each iteration has clean context (no -c flag) to prevent context rot
  OUTPUT=$(claude -p "$(cat "$SCRIPT_DIR/prompt.md")" \
    --output-format json \
    --allowedTools "Bash,Read,Edit,Write,Glob,Grep" \
    --no-session-persistence \
    --model sonnet \
    2>&1) || true

  # Extract result from JSON output
  RESULT=$(echo "$OUTPUT" | jq -r '.result // empty' 2>/dev/null || echo "$OUTPUT")

  # Display result
  echo "$RESULT"

  # Append to progress file
  echo "" >> "$PROGRESS_FILE"
  echo "=== Iteration $i $(date) ===" >> "$PROGRESS_FILE"
  echo "$RESULT" >> "$PROGRESS_FILE"

  # Check for completion signal
  if echo "$RESULT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "✓ SDK Bridge completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Check for errors
  if echo "$OUTPUT" | jq -e '.is_error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$OUTPUT" | jq -r '.result // "Unknown error"')
    echo "⚠ Warning: Iteration $i encountered an error: $ERROR_MSG"
    echo "Continuing to next iteration..."
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "SDK Bridge reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
