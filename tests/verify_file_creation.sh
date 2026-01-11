#!/bin/bash
# File Creation Verification Test
# Verifies files are ACTUALLY created, not just reported as complete
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  File Creation Verification Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

# Load feature list
if [ ! -f "feature_list.json" ]; then
  echo "❌ feature_list.json not found in $PROJECT_DIR"
  exit 1
fi

echo "✅ Found feature_list.json"
echo ""

# Extract all features marked as passes: true
COMPLETED=$(jq -r '.[] | select(.passes == true) | .description' feature_list.json 2>/dev/null || echo "")

if [ -z "$COMPLETED" ]; then
  echo "⚠️  No completed features found (all passes: false)"
  echo "   This test verifies files for completed features only."
  exit 0
fi

echo "Checking files for each completed feature..."
echo ""

FEATURE_COUNT=0
FILE_FOUND=0
FILE_MISSING=0

while IFS= read -r feature; do
  FEATURE_COUNT=$((FEATURE_COUNT + 1))
  echo "Feature $FEATURE_COUNT: $feature"

  # Try to extract filename from description
  # Common patterns: "Create X file", "Add X.py", "Implement X.js"
  FILENAME=$(echo "$feature" | grep -oE '\b[a-zA-Z0-9_-]+\.(txt|py|js|json|md|sh|yml|yaml|toml|cfg|ini)\b' | head -1 || echo "")

  if [ -n "$FILENAME" ]; then
    if [ -f "$FILENAME" ]; then
      SIZE=$(wc -c < "$FILENAME")
      echo "  ✅ File exists: $FILENAME ($SIZE bytes)"
      FILE_FOUND=$((FILE_FOUND + 1))
    else
      echo "  ❌ FILE MISSING: $FILENAME"
      FILE_MISSING=$((FILE_MISSING + 1))
    fi
  else
    echo "  ⚠️  Could not extract filename from description"
  fi

  echo ""
done <<< "$COMPLETED"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Features marked complete: $FEATURE_COUNT"
echo "  Files found: $FILE_FOUND"
echo "  Files missing: $FILE_MISSING"
echo ""

if [ "$FILE_MISSING" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED: $FILE_MISSING files not created"
  echo ""
  echo "This indicates features were marked as 'passes: true' but the"
  echo "corresponding files do not exist in the filesystem."
  exit 1
elif [ "$FEATURE_COUNT" -eq 0 ]; then
  echo "⚠️  No features to verify (none marked as complete)"
  exit 0
else
  echo "✅ VERIFICATION PASSED: All files created"
  exit 0
fi
