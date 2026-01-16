#!/bin/bash
# Atomic write helper - prevents file corruption from concurrent access
# Usage: atomic-write.sh <content> <target-file>

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: atomic-write.sh <content> <target-file>" >&2
  exit 1
fi

CONTENT="$1"
TARGET="$2"

# Create temp file in same directory as target (ensures same filesystem for atomic mv)
TARGET_DIR=$(dirname "$TARGET")
TEMP_FILE=$(mktemp "$TARGET_DIR/.tmp.XXXXXX")

# Write content to temp file
echo "$CONTENT" > "$TEMP_FILE"

# Atomic rename (guaranteed atomic on POSIX filesystems)
mv "$TEMP_FILE" "$TARGET"

# Success
exit 0
