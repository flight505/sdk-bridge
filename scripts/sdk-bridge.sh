#!/bin/bash
# SDK Bridge - Long-running AI agent loop with process management
# Usage: ./sdk-bridge.sh [max_iterations]

set -e

# ============================================================================
# Process Management & Cleanup
# ============================================================================

# Global variable to track current Claude process
CURRENT_CLAUDE_PID=""

# Cleanup function - called on any exit (normal, interrupt, error)
cleanup() {
  local exit_code=$?

  echo "[CLEANUP] Cleanup triggered (exit code: $exit_code)" >&2

  # Only clean up OUR child process, not others
  if [ -n "$CURRENT_CLAUDE_PID" ]; then
    echo "[CLEANUP] Checking if Claude process $CURRENT_CLAUDE_PID is running..." >&2
    if ps -p "$CURRENT_CLAUDE_PID" > /dev/null 2>&1; then
      echo "[CLEANUP] Terminating Claude process $CURRENT_CLAUDE_PID..." >&2
      echo ""
      echo "⚠️  Shutting down this SDK Bridge instance..."

      # Try graceful termination first
      kill -TERM "$CURRENT_CLAUDE_PID" 2>/dev/null || true
      sleep 2

      # Force kill if still running
      if ps -p "$CURRENT_CLAUDE_PID" > /dev/null 2>&1; then
        echo "[CLEANUP] Process still running, force killing..." >&2
        kill -9 "$CURRENT_CLAUDE_PID" 2>/dev/null || true
      else
        echo "[CLEANUP] Process terminated gracefully" >&2
      fi
    else
      echo "[CLEANUP] Claude process already terminated" >&2
    fi
  else
    echo "[CLEANUP] No active Claude process to clean up" >&2
  fi

  # Clean up THIS instance's PID file only (per-branch)
  if [ -f "$PRD_FILE" ]; then
    BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$PRD_FILE" 2>/dev/null || echo "unknown")
    PID_FILE="$PROJECT_DIR/.claude/sdk-bridge-${BRANCH_NAME}.pid"
    echo "[CLEANUP] Checking for PID file: $PID_FILE" >&2
    if [ -f "$PID_FILE" ]; then
      echo "[CLEANUP] Removing PID file: $PID_FILE" >&2
      rm -f "$PID_FILE"
    fi
  fi

  echo "[CLEANUP] Cleanup complete" >&2
  exit $exit_code
}

# Register cleanup on ALL exit scenarios
echo "[INIT] Registering signal handlers (EXIT, INT, TERM, HUP)" >&2
trap cleanup EXIT INT TERM HUP

# ============================================================================
# Authentication Check
# ============================================================================

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
  echo "  2. export CLAUDE_CODE_OAUTH_TOKEN='your-token'"
  echo ""
  echo "Alternative: API Key"
  echo "  1. Get from: https://console.anthropic.com/settings/keys"
  echo "  2. export ANTHROPIC_API_KEY='your-key'"
  echo ""
  exit 1
fi

# ============================================================================
# Timeout Command Detection
# ============================================================================

# Detect which timeout command is available (GNU coreutils)
# macOS with Homebrew coreutils: gtimeout
# Linux: timeout
if command -v gtimeout &> /dev/null; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout &> /dev/null; then
  TIMEOUT_CMD="timeout"
else
  echo "Error: timeout command not found (GNU coreutils required)"
  echo ""
  echo "Install coreutils:"
  echo "  macOS: brew install coreutils"
  echo "  Linux: sudo apt-get install coreutils"
  echo ""
  exit 1
fi

# ============================================================================
# Configuration
# ============================================================================

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Work in the user's project directory (current working directory)
PROJECT_DIR="$(pwd)"
PRD_FILE="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
ARCHIVE_DIR="$PROJECT_DIR/archive"
LAST_BRANCH_FILE="$PROJECT_DIR/.last-branch"
CONFIG_FILE="$PROJECT_DIR/.claude/sdk-bridge.config.json"
# Legacy YAML config (for backwards compatibility)
LEGACY_CONFIG_FILE="$PROJECT_DIR/.claude/sdk-bridge.local.md"

# Read configuration from JSON config (or legacy YAML fallback)
ITERATION_TIMEOUT=900
EXECUTION_MODE="foreground"
EXECUTION_MODEL="sonnet"
EFFORT_LEVEL=""
CODE_REVIEW="true"
FALLBACK_MODEL=""

if [ -f "$CONFIG_FILE" ]; then
  echo "[INIT] Reading configuration from $CONFIG_FILE" >&2
  ITERATION_TIMEOUT=$(jq -r '.iteration_timeout // 900' "$CONFIG_FILE" 2>/dev/null) || ITERATION_TIMEOUT=900
  EXECUTION_MODE=$(jq -r '.execution_mode // "foreground"' "$CONFIG_FILE" 2>/dev/null) || EXECUTION_MODE="foreground"
  EXECUTION_MODEL=$(jq -r '.execution_model // "sonnet"' "$CONFIG_FILE" 2>/dev/null) || EXECUTION_MODEL="sonnet"
  EFFORT_LEVEL=$(jq -r '.effort_level // ""' "$CONFIG_FILE" 2>/dev/null) || EFFORT_LEVEL=""
  CODE_REVIEW=$(jq -r '.code_review // true' "$CONFIG_FILE" 2>/dev/null) || CODE_REVIEW="true"
  FALLBACK_MODEL=$(jq -r '.fallback_model // ""' "$CONFIG_FILE" 2>/dev/null) || FALLBACK_MODEL=""
  echo "[INIT] Config loaded: timeout=${ITERATION_TIMEOUT}s, mode=$EXECUTION_MODE, model=$EXECUTION_MODEL" >&2
elif [ -f "$LEGACY_CONFIG_FILE" ]; then
  echo "[INIT] Reading legacy YAML config from $LEGACY_CONFIG_FILE" >&2
  TIMEOUT_FROM_CONFIG=$(grep -A 10 "^---$" "$LEGACY_CONFIG_FILE" | grep "iteration_timeout:" | sed 's/.*: *//' || echo "")
  if [ -n "$TIMEOUT_FROM_CONFIG" ]; then ITERATION_TIMEOUT=$TIMEOUT_FROM_CONFIG; fi
  MODE_FROM_CONFIG=$(grep -A 10 "^---$" "$LEGACY_CONFIG_FILE" | grep "execution_mode:" | sed 's/.*: *//' || echo "")
  if [ -n "$MODE_FROM_CONFIG" ]; then EXECUTION_MODE=$MODE_FROM_CONFIG; fi
  MODEL_FROM_CONFIG=$(grep -A 10 "^---$" "$LEGACY_CONFIG_FILE" | grep "execution_model:" | sed 's/.*: *//' | tr -d '"' || echo "")
  if [ -n "$MODEL_FROM_CONFIG" ]; then EXECUTION_MODEL=$MODEL_FROM_CONFIG; fi
  EFFORT_FROM_CONFIG=$(grep -A 10 "^---$" "$LEGACY_CONFIG_FILE" | grep "effort_level:" | sed 's/.*: *//' | tr -d '"' || echo "")
  if [ -n "$EFFORT_FROM_CONFIG" ]; then EFFORT_LEVEL=$EFFORT_FROM_CONFIG; fi
fi

echo "[INIT] Iteration timeout: ${ITERATION_TIMEOUT}s ($(($ITERATION_TIMEOUT / 60)) minutes)" >&2

# Export effort level as env var for Claude CLI (Opus 4.6 adaptive reasoning)
if [ -n "$EFFORT_LEVEL" ] && [ "$EXECUTION_MODEL" = "opus" ]; then
  export CLAUDE_CODE_EFFORT_LEVEL="$EFFORT_LEVEL"
  echo "[INIT] CLAUDE_CODE_EFFORT_LEVEL=$EFFORT_LEVEL (Opus 4.6 adaptive reasoning)" >&2
fi

if [ -n "$FALLBACK_MODEL" ]; then
  echo "[INIT] Fallback model: $FALLBACK_MODEL" >&2
fi

# JSON schema for structured output from each iteration
RESULT_SCHEMA='{"type":"object","required":["story_id","status"],"properties":{"story_id":{"type":"string"},"status":{"type":"string","enum":["completed","failed","skipped"]},"error_category":{"type":["string","null"]},"error_details":{"type":["string","null"]},"files_modified":{"type":"array","items":{"type":"string"}},"files_created":{"type":"array","items":{"type":"string"}},"commits":{"type":"array","items":{"type":"string"}},"learnings":{"type":"array","items":{"type":"string"}},"retry_hint":{"type":["string","null"]}}}'

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

# ============================================================================
# Per-Branch Instance Check
# ============================================================================

# Extract branch name from PRD for per-branch PID file
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$PRD_FILE" 2>/dev/null || echo "unknown")
INSTANCE_PID_FILE="$PROJECT_DIR/.claude/sdk-bridge-${BRANCH_NAME}.pid"

echo "[INIT] Branch: $BRANCH_NAME" >&2
echo "[INIT] Instance PID file: $INSTANCE_PID_FILE" >&2

# Check if SDK Bridge is already running on THIS branch
if [ -f "$INSTANCE_PID_FILE" ]; then
  EXISTING_PID=$(cat "$INSTANCE_PID_FILE")
  echo "[INIT] Found existing PID file with PID: $EXISTING_PID" >&2
  if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
    echo "❌ Error: SDK Bridge already running on branch '$BRANCH_NAME' (PID: $EXISTING_PID)"
    echo "This prevents duplicate work on the same feature."
    echo ""
    echo "Options:"
    echo "  - Wait for it to finish"
    echo "  - Stop it: kill $EXISTING_PID"
    echo "  - View logs: tail -f .claude/sdk-bridge.log"
    exit 1
  else
    # Stale PID file, remove it
    echo "[INIT] PID $EXISTING_PID not running, removing stale PID file" >&2
    rm -f "$INSTANCE_PID_FILE"
  fi
fi

# Save our PID for this branch
echo "[INIT] Saving our PID ($$) to $INSTANCE_PID_FILE" >&2
mkdir -p "$(dirname "$INSTANCE_PID_FILE")"
echo $$ > "$INSTANCE_PID_FILE"

# ============================================================================
# Main Execution Loop
# ============================================================================

echo "Starting SDK Bridge - Max iterations: $MAX_ITERATIONS"
echo "Branch: $BRANCH_NAME"
echo "Model: $EXECUTION_MODEL$([ -n "$EFFORT_LEVEL" ] && echo " (effort: $EFFORT_LEVEL)")$([ -n "$FALLBACK_MODEL" ] && echo " (fallback: $FALLBACK_MODEL)")"
echo "Code review: $CODE_REVIEW"
echo "PID: $$"
echo "Timeout: ${ITERATION_TIMEOUT}s per iteration"

# Resume intelligence — report progress on startup
if [ -f "$PRD_FILE" ]; then
  TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null) || TOTAL_STORIES=0
  DONE_STORIES=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null) || DONE_STORIES=0
  PENDING_STORIES=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null) || PENDING_STORIES=0
  NEXT_STORY=$(jq -r '.userStories[] | select(.passes == false) | .id' "$PRD_FILE" 2>/dev/null | head -1 || echo "none")

  if [ "$DONE_STORIES" -gt 0 ] 2>/dev/null; then
    echo ""
    echo "Resume detected: ${DONE_STORIES}/${TOTAL_STORIES} stories complete, ${PENDING_STORIES} pending"
    echo "Starting from: $NEXT_STORY"

    # Carry forward learnings from completed stories to progress.txt
    if [ -f "$PROGRESS_FILE" ]; then
      LEARNINGS_COUNT=$(grep -c "Learnings for future iterations" "$PROGRESS_FILE" 2>/dev/null || true)
      if [ "$LEARNINGS_COUNT" -gt 0 ]; then
        echo "Carrying forward $LEARNINGS_COUNT sets of learnings from previous stories"
      fi
    fi
  fi
fi

# Function to handle timeout
handle_timeout() {
  local iteration=$1
  local story_id=$2

  echo "" >&2
  echo "[TIMEOUT] Iteration $iteration exceeded ${ITERATION_TIMEOUT}s timeout" >&2

  # Log to progress file
  echo "" >> "$PROGRESS_FILE"
  echo "## Iteration $iteration - TIMEOUT" >> "$PROGRESS_FILE"
  echo "Duration: ${ITERATION_TIMEOUT}s (timeout)" >> "$PROGRESS_FILE"
  echo "Story: $story_id" >> "$PROGRESS_FILE"
  echo "Status: Timed out - exceeded iteration time limit" >> "$PROGRESS_FILE"
  echo "Note: Story may need manual implementation or PRD revision" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"

  # Mark story as timeout in prd.json if we can identify it
  if [ -n "$story_id" ] && [ -f "$PRD_FILE" ]; then
    TEMP_PRD=$(mktemp)
    jq --arg id "$story_id" '
      .userStories |= map(
        if .id == $id then
          .notes = (.notes // "") + " [TIMEOUT: Iteration exceeded time limit]"
        else . end
      )
    ' "$PRD_FILE" > "$TEMP_PRD" && mv "$TEMP_PRD" "$PRD_FILE"
  fi

  if [ "$EXECUTION_MODE" = "foreground" ]; then
    # Interactive mode - ask user
    echo ""
    echo "⚠️  Iteration $iteration timed out after ${ITERATION_TIMEOUT}s"
    echo ""
    echo "Options:"
    echo "  1. Skip story and continue to next iteration"
    echo "  2. Retry with extended timeout (+50%)"
    echo "  3. Abort SDK Bridge execution"
    echo ""
    read -p "Choice (1-3): " choice

    case $choice in
      1)
        echo "Skipping timed out story, continuing to next iteration..."
        return 0
        ;;
      2)
        echo "Retrying with extended timeout..."
        EXTENDED_TIMEOUT=$((ITERATION_TIMEOUT * 3 / 2))
        return 2  # Signal retry
        ;;
      3)
        echo "Aborting SDK Bridge execution"
        exit 1
        ;;
      *)
        echo "Invalid choice, skipping story..."
        return 0
        ;;
    esac
  else
    # Background mode - auto-skip
    echo "⚠️  Iteration $iteration timed out. Skipping story and continuing." >&2
    return 0
  fi
}

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  SDK Bridge Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  # Try to identify current story from prd.json
  CURRENT_STORY=$(jq -r '.userStories[] | select(.passes == false) | .id' "$PRD_FILE" 2>/dev/null | head -1 || echo "unknown")
  echo "[ITER-$i] Working on story: $CURRENT_STORY" >&2

  # Run fresh Claude agent with the sdk-bridge prompt
  # Each iteration has clean context (no -c flag) to prevent context rot

  # Use temp file to capture output while tracking PID
  TEMP_OUTPUT="/tmp/sdk-bridge-$$-$i.txt"
  echo "[ITER-$i] Starting Claude process, output to: $TEMP_OUTPUT" >&2
  echo "[ITER-$i] Timeout: ${ITERATION_TIMEOUT}s" >&2

  # Build claude command with optional flags
  CLAUDE_ARGS=("-p" "$(cat "$SCRIPT_DIR/prompt.md")")
  CLAUDE_ARGS+=("--output-format" "json")
  CLAUDE_ARGS+=("--json-schema" "$RESULT_SCHEMA")
  CLAUDE_ARGS+=("--allowedTools" "Bash,Read,Edit,Write,Glob,Grep,Skill")
  CLAUDE_ARGS+=("--no-session-persistence")
  CLAUDE_ARGS+=("--model" "$EXECUTION_MODEL")
  if [ -n "$FALLBACK_MODEL" ]; then
    CLAUDE_ARGS+=("--fallback-model" "$FALLBACK_MODEL")
  fi

  # Run with timeout
  $TIMEOUT_CMD $ITERATION_TIMEOUT claude "${CLAUDE_ARGS[@]}" \
    > "$TEMP_OUTPUT" 2>&1 &

  # Track PID for cleanup
  CURRENT_CLAUDE_PID=$!
  echo "[ITER-$i] Claude process started with PID: $CURRENT_CLAUDE_PID" >&2

  # Wait for completion
  TIMEOUT_OCCURRED=0
  if wait $CURRENT_CLAUDE_PID; then
    echo "[ITER-$i] Claude process completed successfully" >&2
  else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 124 ]; then
      # Timeout (exit code 124 from timeout command)
      echo "[ITER-$i] Claude process timed out" >&2
      TIMEOUT_OCCURRED=1
    else
      echo "[ITER-$i] Claude process exited with code $EXIT_CODE (continuing...)" >&2
    fi
  fi

  # Read output and cleanup temp file
  OUTPUT=$(cat "$TEMP_OUTPUT" 2>/dev/null || echo '{"error": "Failed to read output"}')
  rm -f "$TEMP_OUTPUT"
  CURRENT_CLAUDE_PID=""
  echo "[ITER-$i] Claude process cleanup complete" >&2

  # Handle timeout
  if [ $TIMEOUT_OCCURRED -eq 1 ]; then
    handle_timeout $i "$CURRENT_STORY"
    RETRY=$?

    if [ $RETRY -eq 2 ]; then
      # Retry with extended timeout
      EXTENDED_TIMEOUT=$((ITERATION_TIMEOUT * 3 / 2))
      echo "Retrying iteration $i with ${EXTENDED_TIMEOUT}s timeout..."

      TEMP_OUTPUT="/tmp/sdk-bridge-$$-$i-retry.txt"
      $TIMEOUT_CMD $EXTENDED_TIMEOUT claude "${CLAUDE_ARGS[@]}" \
        > "$TEMP_OUTPUT" 2>&1 &

      CURRENT_CLAUDE_PID=$!
      if wait $CURRENT_CLAUDE_PID; then
        OUTPUT=$(cat "$TEMP_OUTPUT" 2>/dev/null)
        rm -f "$TEMP_OUTPUT"
        CURRENT_CLAUDE_PID=""
      else
        echo "⚠️  Retry also timed out. Skipping story."
        rm -f "$TEMP_OUTPUT"
        CURRENT_CLAUDE_PID=""
        continue
      fi
    else
      # Skip this story, continue to next iteration
      echo "Iteration $i complete (timed out, skipped). Continuing..."
      sleep 2
      continue
    fi
  fi

  # Extract structured output (from --json-schema) and text result
  STRUCTURED_OUTPUT=$(echo "$OUTPUT" | jq -r '.structured_output // empty' 2>/dev/null)
  RESULT=$(echo "$OUTPUT" | jq -r '.result // empty' 2>/dev/null || echo "$OUTPUT")

  # Parse structured status if available
  STORY_STATUS=""
  STORY_ID=""
  if [ -n "$STRUCTURED_OUTPUT" ]; then
    STORY_STATUS=$(echo "$STRUCTURED_OUTPUT" | jq -r '.status // empty' 2>/dev/null)
    STORY_ID=$(echo "$STRUCTURED_OUTPUT" | jq -r '.story_id // empty' 2>/dev/null)
    echo "Story ${STORY_ID:-unknown}: ${STORY_STATUS:-unknown}"
  fi

  # Display result
  echo "$RESULT"

  # Append to progress file
  echo "" >> "$PROGRESS_FILE"
  echo "=== Iteration $i $(date) ===" >> "$PROGRESS_FILE"
  echo "Story: ${STORY_ID:-unknown} Status: ${STORY_STATUS:-unknown}" >> "$PROGRESS_FILE"
  echo "$RESULT" >> "$PROGRESS_FILE"

  # Check for all stories complete via prd.json (primary method)
  if [ -f "$PRD_FILE" ]; then
    REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null) || REMAINING=1
    if [ "$REMAINING" -eq 0 ]; then
      echo ""
      echo "All stories complete!"
      echo "Completed at iteration $i of $MAX_ITERATIONS"
      exit 0
    fi
  fi

  # Legacy fallback: check for COMPLETE promise string
  if echo "$RESULT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "SDK Bridge completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Check for errors
  if echo "$OUTPUT" | jq -e '.is_error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$OUTPUT" | jq -r '.result // "Unknown error"')
    echo "Warning: Iteration $i encountered an error: $ERROR_MSG"
    echo "Continuing to next iteration..."
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "SDK Bridge reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
