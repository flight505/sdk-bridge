---
description: "Resume CLI interaction after SDK agent completes"
argument-hint: ""
---

# Resume After SDK Agent Completion

Let me help you resume interactive work after the SDK agent has completed.

## Check for Completion Signal

```bash
if [ ! -f ".claude/sdk_complete.json" ]; then
  echo "⚠️  SDK agent hasn't signaled completion yet"
  echo ""

  # Check if still running
  if [ -f ".claude/sdk-bridge.pid" ]; then
    PID=$(cat .claude/sdk-bridge.pid)
    if ps -p $PID > /dev/null 2>&1; then
      echo "SDK agent is still running (PID: $PID)"
      echo ""
      echo "Check current status:"
      echo "  /sdk-bridge:status"
      exit 0
    else
      echo "SDK agent process has stopped but didn't create completion signal."
      echo "This may indicate a crash or error."
      echo ""
      echo "Check the logs:"
      echo "  tail -50 .claude/sdk-bridge.log"
      echo ""
      echo "If the work looks complete, you can continue anyway."
    fi
  else
    echo "No SDK agent appears to be running."
    echo ""
    echo "To start one, run: /sdk-bridge:handoff"
    exit 0
  fi
fi
```

## Parse Completion Signal

```bash
if [ -f ".claude/sdk_complete.json" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "SDK Agent Completion Report"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Read completion data
  REASON=$(jq -r '.reason // "unknown"' .claude/sdk_complete.json)
  TOTAL_SESSIONS=$(jq -r '.session_count // "?"' .claude/sdk_complete.json)
  FINAL_COMMIT=$(jq -r '.final_commit // ""' .claude/sdk_complete.json)

  echo "Completion Reason: $REASON"
  echo "Total Sessions: $TOTAL_SESSIONS"
  if [ -n "$FINAL_COMMIT" ]; then
    echo "Final Commit: ${FINAL_COMMIT:0:8}"
  fi
  echo ""
fi
```

## Analyze Feature Progress

```bash
echo "Feature Progress:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

FEATURES_TOTAL=$(jq 'length' feature_list.json)
FEATURES_PASSING=$(jq '[.[] | select(.passes==true)] | length' feature_list.json)
FEATURES_REMAINING=$((FEATURES_TOTAL - FEATURES_PASSING))
COMPLETION_PCT=$((FEATURES_PASSING * 100 / FEATURES_TOTAL))

echo "  Total: $FEATURES_TOTAL features"
echo "  ✅ Completed: $FEATURES_PASSING ($COMPLETION_PCT%)"
echo "  ❌ Remaining: $FEATURES_REMAINING"
echo ""

# Show completed features
if [ "$FEATURES_PASSING" -gt 0 ]; then
  echo "Completed Features:"
  jq -r '.[] | select(.passes==true) | "  ✅ " + .description' feature_list.json | head -20

  if [ "$FEATURES_PASSING" -gt 20 ]; then
    echo "  ... and $((FEATURES_PASSING - 20)) more"
  fi
  echo ""
fi

# Show remaining features
if [ "$FEATURES_REMAINING" -gt 0 ]; then
  echo "Remaining Features:"
  jq -r '.[] | select(.passes==false) | "  ❌ " + .description' feature_list.json | head -10

  if [ "$FEATURES_REMAINING" -gt 10 ]; then
    echo "  ... and $((FEATURES_REMAINING - 10)) more"
  fi
  echo ""
fi
```

## Review Recent Commits

```bash
# Get handoff commit if available
if [ -f ".claude/handoff-context.json" ]; then
  HANDOFF_COMMIT=$(jq -r '.git_commit' .claude/handoff-context.json 2>/dev/null || echo "")
fi

if [ -n "$HANDOFF_COMMIT" ] && [ "$HANDOFF_COMMIT" != "none" ]; then
  echo "Commits Since Handoff:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  git log --oneline ${HANDOFF_COMMIT}..HEAD 2>/dev/null | head -20 || \
    git log --oneline --since="2 hours ago" | head -20
  echo ""
else
  echo "Recent Commits:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  git log --oneline -20
  echo ""
fi
```

## Check Tests and Build

```bash
echo "Verification:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if tests exist and run them
if [ -f "package.json" ] && jq -e '.scripts.test' package.json > /dev/null 2>&1; then
  echo "Running tests..."
  if npm test 2>&1 | tail -10; then
    echo "✅ Tests passing"
  else
    echo "⚠️  Some tests may be failing - check above"
  fi
  echo ""
elif command -v pytest &> /dev/null && [ -d "tests" ]; then
  echo "Running tests..."
  if pytest 2>&1 | tail -10; then
    echo "✅ Tests passing"
  else
    echo "⚠️  Some tests may be failing - check above"
  fi
  echo ""
fi

# Check build if available
if [ -f "package.json" ] && jq -e '.scripts.build' package.json > /dev/null 2>&1; then
  echo "Checking build..."
  if npm run build 2>&1 | tail -5; then
    echo "✅ Build successful"
  else
    echo "⚠️  Build may have issues - check above"
  fi
  echo ""
fi
```

## Summary and Next Steps

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$FEATURES_REMAINING" -eq 0 ]; then
  echo "🎉 All features complete!"
  echo ""
  echo "The SDK agent successfully implemented all $FEATURES_TOTAL features."
  echo ""
  echo "Recommended next steps:"
  echo "  1. Review the commits to understand what was changed"
  echo "  2. Run comprehensive tests"
  echo "  3. Manual testing of critical features"
  echo "  4. Deploy or continue development"
else
  echo "SDK agent completed $FEATURES_PASSING of $FEATURES_TOTAL features."
  echo ""
  echo "Recommended next steps:"
  echo "  1. Review completed work"
  echo "  2. Fix any test failures"
  echo "  3. Continue with remaining features:"
  echo ""
  echo "     You can either:"
  echo "     • Hand off again: /sdk-bridge:handoff"
  echo "     • Complete remaining features manually in CLI"
  echo "     • Refine feature descriptions and hand off again"
fi

echo ""
```

## Clean Up State Files

```bash
# Archive completion signal
if [ -f ".claude/sdk_complete.json" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  mv .claude/sdk_complete.json .claude/sdk_complete.$TIMESTAMP.json
  echo "Archived completion signal to: .claude/sdk_complete.$TIMESTAMP.json"
fi

# Remove PID file
if [ -f ".claude/sdk-bridge.pid" ]; then
  rm -f .claude/sdk-bridge.pid
  echo "Removed PID file"
fi

echo ""
echo "✅ Resumed in CLI mode"
echo ""
echo "You can now continue working interactively."
echo "To hand off again later: /sdk-bridge:handoff"
echo ""
```
