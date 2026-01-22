# SDK Bridge Resilience & Process Management Implementation Plan

**Objective:** Enhance SDK Bridge with robust process management, timeout protection, and intelligent "already implemented" detection to prevent hung iterations and orphaned processes.

**Branch:** `feat/sdk-bridge-resilience` (to be created from `main`)

---

## Phase 1: Analysis & Design Decisions (User Input Required)

Before implementation, the following areas require analysis and user decisions. For each item, analyze the problem space and provide recommendations to the user with clear options.

### 1. Iteration Timeout Strategy

**Problem:** Claude iterations can hang indefinitely if the agent gets stuck in analysis loops or encounters ambiguous completion criteria.

**Analysis Needed:**
- What is the appropriate timeout duration per iteration?
- Should timeout be configurable (per-project or per-story)?
- What should happen when a timeout occurs?
- Should different story types have different timeouts (backend vs UI)?

**Provide Recommendations:**
- Option A: Fixed 10-minute timeout for all iterations
- Option B: Configurable timeout in `.claude/sdk-bridge.local.md`
- Option C: Adaptive timeout based on story complexity/priority
- Option D: Different timeouts for different story types

**Ask User:**
- Preferred timeout approach?
- Default timeout value (if fixed)?
- Should timeouts be logged/reported?

---

### 2. "Already Implemented" Detection Method

**Problem:** Agents may not recognize when acceptance criteria are already satisfied by previous stories, leading to confusion and hung iterations.

**Analysis Needed:**
- How should agents verify if work is already done?
- Should this be a manual check or automated validation?
- What constitutes "already implemented" vs "needs enhancement"?
- How should agents document already-completed work?

**Provide Recommendations:**
- Option A: Add prompt instructions for manual verification before coding
- Option B: Automated code scanning for acceptance criteria satisfaction
- Option C: Hybrid: prompt guidance + optional validation scripts
- Option D: Code-aware PRD generation that prevents duplicate stories

**Ask User:**
- Preferred detection method?
- Should agents skip already-done stories or document them?
- Acceptable false positive/negative rate?

---

### 3. Acceptance Criteria Specificity Standards

**Problem:** Vague acceptance criteria (e.g., "Accept cabin_class parameter") make it hard for agents to determine completion.

**Analysis Needed:**
- What level of specificity is required?
- Should criteria include verification commands (e.g., curl tests)?
- Should criteria reference specific files/functions?
- How to balance specificity vs flexibility?

**Provide Recommendations:**
- Option A: Add file/function references to each criterion
- Option B: Include verification commands (curl, pytest, etc.)
- Option C: Use "Given/When/Then" format for clarity
- Option D: Require at least one programmatic verification per story

**Ask User:**
- Minimum specificity level required?
- Should PRD generator automatically enhance vague criteria?
- Template/format preference for criteria?

---

### 4. Task Dependency Metadata Design

**Problem:** Stories may depend on each other but agents don't know to check for already-implemented dependencies.

**Analysis Needed:**
- What dependency metadata should be tracked?
- Should dependencies be explicit or inferred?
- How should agents use dependency information?
- Should dependency violations block execution?

**Provide Recommendations:**
- Option A: Add `depends_on: ["US-XXX"]` field to story schema
- Option B: Add `implementation_hint` field with dependency notes
- Option C: Automatic dependency detection based on file paths
- Option D: Dependency graph validation before execution starts

**Ask User:**
- Preferred dependency tracking method?
- Should agents auto-detect completed dependencies?
- How to handle circular dependencies?

---

### 5. Task Decomposition Strategy

**Problem:** Splitting features by layer (UI/backend) leads to over-implementation, while full-stack stories may be too large.

**Analysis Needed:**
- What is the optimal story granularity?
- Should stories be feature-complete or layer-specific?
- How to handle cross-cutting concerns?
- What's the trade-off between granularity and agent efficiency?

**Provide Recommendations:**
- Option A: Feature-complete stories (UI + backend together)
- Option B: Layer-specific stories with explicit dependencies
- Option C: Hybrid: simple features full-stack, complex features layered
- Option D: Let PRD generator decide based on complexity

**Ask User:**
- Default decomposition approach?
- Maximum story size (lines of code, time estimate)?
- Should decomposition be configurable per project?

---

### 6. Hung Iteration Recovery Strategy

**Problem:** When iterations time out or hang, how should SDK Bridge recover and continue?

**Analysis Needed:**
- Should hung iterations be retried or skipped?
- How to log/track failed iterations?
- Should users be notified of hung iterations?
- Can partial work from hung iterations be salvaged?

**Provide Recommendations:**
- Option A: Skip story, mark as failed, continue to next
- Option B: Retry story once with extended timeout
- Option C: Interactive prompt asking user how to proceed
- Option D: Automatic retry with "simplified" version of story

**Ask User:**
- Preferred recovery behavior?
- Should failed stories block dependent stories?
- How to handle partial commits from hung iterations?

---

## Phase 2: Process Management Implementation

These are concrete implementation tasks based on the test findings. Implement after Phase 1 decisions are made.

### 2.1: Trap-Based Cleanup Handler

**Objective:** Prevent orphaned Claude processes when SDK Bridge is interrupted or encounters errors.

**Implementation:**
```bash
# In scripts/sdk-bridge.sh, add at the top:

# Global variable to track current Claude process
CURRENT_CLAUDE_PID=""

# Cleanup function - called on any exit
cleanup() {
  local exit_code=$?
  echo "[CLEANUP] Cleanup triggered (exit code: $exit_code)" >&2

  if [ -n "$CURRENT_CLAUDE_PID" ]; then
    if ps -p "$CURRENT_CLAUDE_PID" > /dev/null 2>&1; then
      echo "[CLEANUP] Terminating Claude process $CURRENT_CLAUDE_PID..." >&2
      kill -TERM "$CURRENT_CLAUDE_PID" 2>/dev/null || true
      sleep 2
      # Force kill if still running
      if ps -p "$CURRENT_CLAUDE_PID" > /dev/null 2>&1; then
        kill -9 "$CURRENT_CLAUDE_PID" 2>/dev/null || true
      fi
    fi
  fi

  # Clean up PID file
  if [ -f "$PID_FILE" ]; then
    rm -f "$PID_FILE"
  fi

  exit $exit_code
}

# Register cleanup on all exit scenarios
trap cleanup EXIT INT TERM HUP
```

**Acceptance Criteria:**
- Ctrl+C cleanly terminates SDK Bridge and child Claude processes
- No orphaned Claude processes remain after termination
- Cleanup logs appear in stderr with [CLEANUP] prefix
- Graceful (SIGTERM) attempted before force kill (SIGKILL)

---

### 2.2: Claude Process Tracking

**Objective:** Track each Claude iteration PID for cleanup and monitoring.

**Implementation:**
```bash
# In iteration loop, replace:
OUTPUT=$(claude -p "$(cat "$SCRIPT_DIR/prompt.md")" ...)

# With PID tracking:
TEMP_OUTPUT="/tmp/sdk-bridge-$$-$i.txt"
claude -p "$(cat "$SCRIPT_DIR/prompt.md")" \
  --output-format json \
  --allowedTools "Bash,Read,Edit,Write,Glob,Grep" \
  --no-session-persistence \
  --model sonnet \
  > "$TEMP_OUTPUT" 2>&1 &

CURRENT_CLAUDE_PID=$!
echo "[ITER-$i] Claude process started with PID: $CURRENT_CLAUDE_PID" >&2

# Wait for completion
wait $CURRENT_CLAUDE_PID
OUTPUT=$(cat "$TEMP_OUTPUT")
rm -f "$TEMP_OUTPUT"
CURRENT_CLAUDE_PID=""
```

**Acceptance Criteria:**
- Each iteration PID logged to stderr
- PID trackable for external monitoring
- Temp output files cleaned up after reading
- CURRENT_CLAUDE_PID cleared after iteration completes

---

### 2.3: Per-Branch PID Files

**Objective:** Prevent duplicate SDK Bridge runs on the same branch while allowing parallel execution on different branches.

**Implementation:**
```bash
# Extract branch name from prd.json
BRANCH_NAME=$(jq -r '.branchName // "unknown"' "$PRD_FILE" 2>/dev/null)
PID_FILE="$PROJECT_DIR/.claude/sdk-bridge-${BRANCH_NAME}.pid"

# Check for existing instance on this branch
if [ -f "$PID_FILE" ]; then
  EXISTING_PID=$(cat "$PID_FILE")
  if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
    echo "❌ Error: SDK Bridge already running on branch '$BRANCH_NAME' (PID: $EXISTING_PID)"
    echo "Options:"
    echo "  - Wait for it to finish"
    echo "  - Stop it: kill $EXISTING_PID"
    exit 1
  else
    # Stale PID file, remove it
    rm -f "$PID_FILE"
  fi
fi

# Save our PID
mkdir -p "$(dirname "$PID_FILE")"
echo $$ > "$PID_FILE"
```

**Acceptance Criteria:**
- Duplicate runs on same branch blocked with clear error message
- Parallel runs on different branches allowed
- Stale PID files automatically cleaned up
- PID file removed on clean exit

---

### 2.4: Logging to stderr

**Objective:** Separate internal debugging logs from user-facing output for better log management.

**Implementation:**
```bash
# All internal logs go to stderr with prefixes:
echo "[INIT] Registering signal handlers" >&2
echo "[ITER-$i] Starting iteration" >&2
echo "[CLEANUP] Terminating processes" >&2

# User-facing output goes to stdout:
echo "✓ Using Claude Code OAuth authentication"
echo "Starting SDK Bridge - Max iterations: $MAX_ITERATIONS"
```

**Acceptance Criteria:**
- All `[INIT]`, `[ITER-N]`, `[CLEANUP]` logs go to stderr
- User-facing status messages go to stdout
- Logs can be separated: `./sdk-bridge.sh 2>debug.log`
- stderr logs include timestamps and context

---

## Phase 3: Timeout & Recovery Implementation

Based on Phase 1 decisions, implement the chosen timeout and recovery strategies.

### 3.1: Iteration Timeout (Implement based on #1 decision)

**Placeholder for implementation details - depends on user choice from Phase 1**

Example for Option A (Fixed 10-minute timeout):
```bash
timeout 600 claude -p "$(cat "$SCRIPT_DIR/prompt.md")" ... || {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "⚠️  Iteration $i timed out after 10 minutes on story: [US-XXX]"
    echo "## Iteration $i - TIMEOUT" >> "$PROGRESS_FILE"
    echo "Story [US-XXX] timed out. Skipping to next iteration." >> "$PROGRESS_FILE"
  fi
}
```

---

### 3.2: "Already Implemented" Detection (Implement based on #2 decision)

**Placeholder for implementation details - depends on user choice from Phase 1**

Example for Option A (Prompt instructions):
```markdown
# In scripts/prompt.md, add before "## Your Task":

## Before Starting Implementation

**CRITICAL: Check if work is already done**

1. Read the story's acceptance criteria
2. Search the codebase for related files (use Grep/Glob)
3. Verify each criterion against existing code
4. If ALL criteria are already satisfied:
   - Update prd.json: set passes=true
   - Add note: "Already implemented in [US-XXX]. Verified: [list criteria]"
   - SKIP implementation - do NOT refactor or rewrite working code
   - Continue to next story

DO NOT implement stories that are already complete.
```

---

### 3.3: Enhanced Acceptance Criteria (Implement based on #3 decision)

**Placeholder for implementation details - depends on user choice from Phase 1**

---

### 3.4: Dependency Metadata (Implement based on #4 decision)

**Placeholder for implementation details - depends on user choice from Phase 1**

---

### 3.5: Hung Iteration Recovery (Implement based on #6 decision)

**Placeholder for implementation details - depends on user choice from Phase 1**

---

## Phase 4: Testing & Validation

### 4.1: Unit Tests for Process Cleanup

**Tests to create:**
- Test: Cleanup trap fires on normal exit
- Test: Cleanup trap fires on Ctrl+C (SIGINT)
- Test: Cleanup trap fires on kill (SIGTERM)
- Test: Orphaned processes killed with SIGKILL fallback
- Test: PID files cleaned up correctly
- Test: Duplicate run detection works

---

### 4.2: Integration Tests for Timeout

**Tests to create:**
- Test: Iteration times out after configured duration
- Test: Loop continues to next iteration after timeout
- Test: Progress file updated with timeout information
- Test: Partial commits preserved after timeout

---

### 4.3: Test "Already Implemented" Detection

**Test scenarios:**
- Story with all criteria already satisfied → marked complete
- Story with partial implementation → agent completes remaining work
- Story with no implementation → agent implements normally
- False positive: agent thinks it's done but isn't → manual validation

---

### 4.4: Regression Test with Flight505 PRD

**Re-run the original test:**
- Use the same Flight505 Marketplace Q1 Enhancements PRD
- Verify US-007 no longer hangs (either completes or times out gracefully)
- Verify all 12 stories complete or fail gracefully
- Verify no orphaned processes remain
- Verify progress.txt contains complete information

**Success Criteria:**
- No iterations hang indefinitely
- Loop completes or reaches max iterations
- All processes cleaned up
- Clear logs show what happened at each iteration

---

## Phase 5: Documentation Updates

### 5.1: Update CLAUDE.md

**Sections to add/update:**
- Process management features
- Timeout configuration
- "Already implemented" detection behavior
- PID file management
- Troubleshooting hung iterations

---

### 5.2: Update commands/start.md

**Add user guidance:**
- What to expect during long-running executions
- How to monitor progress
- How to safely interrupt SDK Bridge
- How to resume after interruption

---

### 5.3: Create Troubleshooting Guide

**Document common issues:**
- "SDK Bridge already running" error → how to check/kill
- Iteration timeout → causes and solutions
- Orphaned processes → how to detect and clean
- Hung iterations → how to detect and recover

---

## Implementation Checklist

**Phase 1: Analysis (User Input Required)**
- [ ] Analyze and recommend: Iteration timeout strategy (#1)
- [ ] Analyze and recommend: "Already implemented" detection (#2)
- [ ] Analyze and recommend: Acceptance criteria specificity (#3)
- [ ] Analyze and recommend: Task dependency metadata (#4)
- [ ] Analyze and recommend: Task decomposition strategy (#5)
- [ ] Analyze and recommend: Hung iteration recovery (#6)
- [ ] Get user decisions on all 6 items

**Phase 2: Process Management**
- [ ] Implement trap-based cleanup handler
- [ ] Implement Claude process tracking
- [ ] Implement per-branch PID files
- [ ] Implement stderr logging with prefixes
- [ ] Test Ctrl+C cleanup behavior
- [ ] Test no orphaned processes remain

**Phase 3: Timeout & Recovery**
- [ ] Implement iteration timeout (based on #1)
- [ ] Implement "already implemented" detection (based on #2)
- [ ] Enhance acceptance criteria (based on #3)
- [ ] Add dependency metadata (based on #4)
- [ ] Implement hung iteration recovery (based on #6)

**Phase 4: Testing**
- [ ] Write unit tests for process cleanup
- [ ] Write integration tests for timeout
- [ ] Test "already implemented" detection
- [ ] Run regression test with Flight505 PRD
- [ ] Verify no hangs, no orphaned processes

**Phase 5: Documentation**
- [ ] Update CLAUDE.md with new features
- [ ] Update commands/start.md with guidance
- [ ] Create troubleshooting guide
- [ ] Add examples for common scenarios

**Phase 6: Release**
- [ ] Merge to main branch
- [ ] Delete test branch
- [ ] Update plugin version
- [ ] Update marketplace.json
- [ ] Test installation from marketplace

---

## Success Metrics

**Process Management:**
- ✅ No orphaned Claude processes after any termination method
- ✅ Clean Ctrl+C interruption with clear feedback
- ✅ Parallel execution on different branches works
- ✅ Duplicate runs blocked with helpful error

**Timeout & Recovery:**
- ✅ No iterations hang for more than [configured timeout]
- ✅ Timeout events logged clearly in progress.txt
- ✅ Loop continues gracefully after timeout
- ✅ Partial work preserved after timeout

**"Already Implemented" Detection:**
- ✅ Agent correctly identifies already-done stories
- ✅ False positive rate < 5%
- ✅ Clear documentation when story skipped
- ✅ No refactoring of working code

**Overall Resilience:**
- ✅ SDK Bridge completes or fails gracefully (no indefinite hangs)
- ✅ All processes cleaned up on any exit path
- ✅ Clear logs show exactly what happened
- ✅ Users can monitor, interrupt, and resume safely

---

## Notes for Implementer

1. **Start with Phase 1:** Get user decisions on all 6 analysis items before coding
2. **Phase 2 is independent:** Can implement process management regardless of Phase 1 decisions
3. **Phase 3 depends on Phase 1:** Wait for user choices before implementing timeout/recovery
4. **Test thoroughly:** The original test hung for 32+ minutes - ensure this can't happen again
5. **Keep it simple:** Follow the "radical simplicity" philosophy - prefer obvious solutions
6. **Document as you go:** Update docs in parallel with implementation

**Remember:** This plan treats everything as net new work, even though some items were tested on the `fix/sdk-bridge-process-cleanup` branch. Start fresh from `main`.
