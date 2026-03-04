#!/bin/bash
# check-git.sh — Git repository diagnostic for SDK-Bridge
#
# Checks git state and outputs a JSON diagnostic report.
# The wizard (start.md) reads this output to decide what to ask the user.
#
# Exit codes:
#   0 = repo exists and is ready (may still have warnings)
#   1 = no git repo found (needs init)
#
# Output: JSON object on stdout with diagnostic fields.
# All log messages go to stderr so they don't pollute the JSON output.

set -e

log() { echo "[check-git] $1" >&2; }

# ----- 1. Check if we're inside a git repository -----

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  jq -n '{
    "has_repo": false,
    "needs_init": true,
    "cwd": $cwd
  }' --arg cwd "$(pwd)"
  exit 1
fi

# ----- 2. Gather git state -----

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
IS_DETACHED="false"
if [ -z "$CURRENT_BRANCH" ]; then
  IS_DETACHED="true"
  CURRENT_BRANCH="(detached HEAD)"
fi

# Uncommitted changes
DIRTY_FILES=$(git status --porcelain 2>/dev/null || echo "")
DIRTY_COUNT=0
STAGED_COUNT=0
UNSTAGED_COUNT=0
UNTRACKED_COUNT=0

if [ -n "$DIRTY_FILES" ]; then
  DIRTY_COUNT=$(echo "$DIRTY_FILES" | wc -l | tr -d ' ')
  STAGED_COUNT=$(echo "$DIRTY_FILES" | grep -c '^[MADRC]' || true)
  UNSTAGED_COUNT=$(echo "$DIRTY_FILES" | grep -c '^.[MADRC]' || true)
  UNTRACKED_COUNT=$(echo "$DIRTY_FILES" | grep -c '^??' || true)
fi

IS_DIRTY="false"
if [ "$DIRTY_COUNT" -gt 0 ]; then
  IS_DIRTY="true"
fi

# Remote configured?
HAS_REMOTE="false"
if git remote -v 2>/dev/null | grep -q .; then
  HAS_REMOTE="true"
fi

STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ' || true)
STASH_COUNT=${STASH_COUNT:-0}

# ----- 3. Check .gitignore for SDK-Bridge state files -----

GITIGNORE_FILE="$GIT_ROOT/.gitignore"
MISSING_IGNORES=""
for entry in prd.json progress.txt .claude/sdk-bridge.config.json .claude/sdk-bridge.log; do
  if [ ! -f "$GITIGNORE_FILE" ] || ! grep -qF "$entry" "$GITIGNORE_FILE" 2>/dev/null; then
    if [ -n "$MISSING_IGNORES" ]; then
      MISSING_IGNORES="$(printf '%s\n%s' "$MISSING_IGNORES" "$entry")"
    else
      MISSING_IGNORES="$entry"
    fi
  fi
done

MISSING_IGNORES_JSON="[]"
if [ -n "$MISSING_IGNORES" ]; then
  MISSING_IGNORES_JSON=$(printf '%s\n' "$MISSING_IGNORES" | jq -R . | jq -s .)
fi

# ----- 4. Check for existing prd.json -----

HAS_COMMITS="true"
if ! git rev-parse HEAD > /dev/null 2>&1; then
  HAS_COMMITS="false"
fi

# ----- 5. Output JSON diagnostic -----

DIRTY_SUMMARY="[]"
if [ -n "$DIRTY_FILES" ]; then
  DIRTY_SUMMARY=$(echo "$DIRTY_FILES" | head -10 | jq -R . | jq -s .)
fi

jq -n \
  --argjson has_repo true \
  --argjson needs_init false \
  --arg git_root "$GIT_ROOT" \
  --arg current_branch "$CURRENT_BRANCH" \
  --argjson is_detached "$IS_DETACHED" \
  --argjson is_dirty "$IS_DIRTY" \
  --argjson dirty_count "$DIRTY_COUNT" \
  --argjson staged_count "$STAGED_COUNT" \
  --argjson unstaged_count "$UNSTAGED_COUNT" \
  --argjson untracked_count "$UNTRACKED_COUNT" \
  --argjson dirty_files "$DIRTY_SUMMARY" \
  --argjson has_remote "$HAS_REMOTE" \
  --argjson stash_count "$STASH_COUNT" \
  --argjson has_commits "$HAS_COMMITS" \
  --argjson missing_ignores "$MISSING_IGNORES_JSON" \
  '{
    has_repo: $has_repo,
    needs_init: $needs_init,
    git_root: $git_root,
    current_branch: $current_branch,
    is_detached: $is_detached,
    is_dirty: $is_dirty,
    dirty_count: $dirty_count,
    staged_count: $staged_count,
    unstaged_count: $unstaged_count,
    untracked_count: $untracked_count,
    dirty_files: $dirty_files,
    has_remote: $has_remote,
    stash_count: $stash_count,
    has_commits: $has_commits,
    missing_ignores: $missing_ignores
  }'

exit 0
