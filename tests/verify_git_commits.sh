#!/bin/bash
# Git Commit Content Validation Test
# Verifies git commits contain actual file changes, not empty commits
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Git Commit Content Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Check if git repo
if [ ! -d ".git" ]; then
  echo "❌ Not a git repository: $PROJECT_DIR"
  exit 1
fi

echo "✅ Git repository found"
echo ""

# Get all SDK commits
SDK_COMMITS=$(git log --oneline --grep="SDK: completed feature" --reverse | awk '{print $1}' || echo "")

if [ -z "$SDK_COMMITS" ]; then
  echo "⚠️  No SDK commits found (grep pattern: 'SDK: completed feature')"
  echo "   This test verifies SDK-created commits only."
  exit 0
fi

TOTAL_COMMITS=0
EMPTY_COMMITS=0
COMMITS_WITH_CHANGES=0

while IFS= read -r commit; do
  TOTAL_COMMITS=$((TOTAL_COMMITS + 1))

  # Get commit message
  MSG=$(git log -1 --pretty=%B "$commit")

  # Check if commit has file changes
  CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "$commit" || echo "")
  CHANGE_COUNT=$(echo "$CHANGED_FILES" | grep -v '^$' | wc -l)

  echo "Commit $TOTAL_COMMITS: $commit"
  echo "  Message: $MSG"

  if [ -z "$CHANGED_FILES" ] || [ "$CHANGE_COUNT" -eq 0 ]; then
    echo "  ❌ EMPTY COMMIT (no files changed)"
    EMPTY_COMMITS=$((EMPTY_COMMITS + 1))
  else
    echo "  ✅ Changes: $CHANGE_COUNT file(s)"
    echo "$CHANGED_FILES" | sed 's/^/     - /'
    COMMITS_WITH_CHANGES=$((COMMITS_WITH_CHANGES + 1))
  fi

  echo ""
done <<< "$SDK_COMMITS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total SDK commits: $TOTAL_COMMITS"
echo "  Commits with changes: $COMMITS_WITH_CHANGES"
echo "  Empty commits: $EMPTY_COMMITS"
echo ""

if [ "$EMPTY_COMMITS" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED: $EMPTY_COMMITS empty commits"
  echo ""
  echo "Empty commits indicate the SDK reported feature completion but"
  echo "did not actually stage and commit any file changes."
  exit 1
else
  echo "✅ VERIFICATION PASSED: All commits have file changes"
  exit 0
fi
