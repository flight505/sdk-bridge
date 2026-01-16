# Atomic Write Operations - Usage Guide

## Overview

SDK Bridge provides atomic write helpers to prevent file corruption from concurrent access between CLI and SDK agents. These helpers use the temp-file + atomic-rename pattern to ensure data consistency.

## Why Atomic Writes?

**The Problem**: SDK Bridge uses file-based state sharing between two processes (CLI Agent and SDK Agent). Without atomic operations, race conditions can corrupt state files:

```
CLI reads handoff-context.json (partial write) → corrupted JSON
SDK writes feature_list.json → CLI reads mid-write → parse error
```

**The Solution**: Write to temp file first, then atomically rename to target (POSIX `mv` is atomic):

```
1. Write to .tmp.XXXXXX
2. Atomic rename to target.json
3. Readers always see complete, valid files
```

## Bash Helper: atomic-write.sh

**Location**: `${CLAUDE_PLUGIN_ROOT}/scripts/atomic-write.sh`

**Usage**:
```bash
#!/bin/bash

# Simple text write
bash atomic-write.sh "Hello World" ".claude/status.txt"

# JSON write (use jq to generate content)
CONTENT=$(jq -n '{status: "running", session: 5}')
bash atomic-write.sh "$CONTENT" ".claude/handoff-context.json"
```

**Example: Update Session Count**
```bash
HANDOFF_FILE=".claude/handoff-context.json"

# Read current state
CURRENT=$(cat "$HANDOFF_FILE")

# Update with jq
UPDATED=$(echo "$CURRENT" | jq '.session_count += 1 | .last_update = now | strftime("%Y-%m-%dT%H:%M:%SZ")')

# Atomic write
bash "${CLAUDE_PLUGIN_ROOT}/scripts/atomic-write.sh" "$UPDATED" "$HANDOFF_FILE"
```

## Python Helper: atomic_file_ops.py

**Location**: `${CLAUDE_PLUGIN_ROOT}/scripts/atomic_file_ops.py`

**Import**:
```python
import sys
from pathlib import Path

# Add scripts directory to path
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from atomic_file_ops import (
    atomic_write_json,
    atomic_append_text,
    safe_read_json,
    create_backup
)
```

### Function Reference

#### `atomic_write_json(data: Dict[str, Any], target_path: str) -> None`

Atomically write dictionary as JSON.

**Example: Update Handoff Context**
```python
from atomic_file_ops import atomic_write_json, safe_read_json

# Read current state
context = safe_read_json('.claude/handoff-context.json', default={})

# Update fields
context['session_count'] = context.get('session_count', 0) + 1
context['last_update'] = datetime.now(timezone.utc).isoformat()

# Atomic write
atomic_write_json(context, '.claude/handoff-context.json')
```

**Example: Create Completion Signal**
```python
completion_data = {
    'reason': 'all_features_passing',
    'session_count': 15,
    'completion_time': datetime.now(timezone.utc).isoformat()
}

atomic_write_json(completion_data, '.claude/sdk_complete.json')
```

#### `atomic_append_text(text: str, target_path: str) -> None`

Atomically append text to file (reads existing + appends + writes atomically).

**Example: Session Memory Log**
```python
from atomic_file_ops import atomic_append_text

session_log = f"""
=== Session {session_num} ===
Feature: {feature_id}
Status: {status}
Timestamp: {datetime.now().isoformat()}
"""

atomic_append_text(session_log, 'claude-progress.txt')
```

**Example: Error Log**
```python
error_entry = f"[{datetime.now()}] ERROR: {error_message}\n"
atomic_append_text(error_entry, '.claude/sdk-bridge.log')
```

#### `safe_read_json(path: str, default: Dict[str, Any] | None = None) -> Dict[str, Any]`

Safely read JSON with fallback to default if file missing or corrupted.

**Example: Read Configuration**
```python
from atomic_file_ops import safe_read_json

# With default
config = safe_read_json('.claude/sdk-bridge.local.md', default={'enabled': False})

# Check if file existed
if config.get('enabled'):
    model = config.get('model', 'claude-sonnet-4-5-20250929')
```

**Example: Read Feature List**
```python
features = safe_read_json('feature_list.json', default=[])

for feature in features:
    if not feature.get('passes', False):
        print(f"TODO: {feature['description']}")
```

#### `create_backup(source_path: str, backup_suffix: str | None = None) -> str`

Create timestamped backup of file.

**Example: Pre-Modification Backup**
```python
from atomic_file_ops import create_backup, atomic_write_json, safe_read_json

# Create backup before modifying
backup_path = create_backup('.claude/handoff-context.json')
print(f"Backup created: {backup_path}")

# Now safe to modify
context = safe_read_json('.claude/handoff-context.json')
context['session_count'] += 1
atomic_write_json(context, '.claude/handoff-context.json')
```

**Example: Custom Backup Suffix**
```python
# Create backup with custom suffix
backup_path = create_backup('feature_list.json', backup_suffix='before-session-5')
# Creates: feature_list.json.before-session-5.bak
```

## Integration Examples

### Harness Script Pattern

```python
#!/usr/bin/env python3
import sys
from pathlib import Path

# Setup path for atomic_file_ops
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from atomic_file_ops import (
    atomic_write_json,
    safe_read_json,
    create_backup
)

def main():
    # Read state safely
    context = safe_read_json('.claude/handoff-context.json', default={
        'session_count': 0,
        'features_completed': []
    })

    # Create backup before modifications
    create_backup('.claude/handoff-context.json')

    # Update state
    context['session_count'] += 1

    # Write atomically
    atomic_write_json(context, '.claude/handoff-context.json')

if __name__ == '__main__':
    main()
```

### Monitor Script Pattern

```bash
#!/bin/bash
set -euo pipefail

HANDOFF_FILE=".claude/handoff-context.json"
ATOMIC_WRITE="${CLAUDE_PLUGIN_ROOT}/scripts/atomic-write.sh"

# Read current state
CURRENT=$(cat "$HANDOFF_FILE" 2>/dev/null || echo '{}')

# Check if completed
FEATURES_TOTAL=$(jq 'length' feature_list.json)
FEATURES_PASSING=$(jq '[.[] | select(.passes==true)] | length' feature_list.json)

if [ "$FEATURES_PASSING" -eq "$FEATURES_TOTAL" ]; then
  # Create completion signal atomically
  COMPLETION=$(jq -n \
    --arg reason "all_features_passing" \
    --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{reason: $reason, completion_time: $time}')

  bash "$ATOMIC_WRITE" "$COMPLETION" ".claude/sdk_complete.json"
fi
```

## Best Practices

### ✅ DO

1. **Always use atomic writes for state files**:
   - `.claude/handoff-context.json`
   - `.claude/sdk_complete.json`
   - `feature_list.json`
   - `claude-progress.txt`

2. **Create backups before major changes**:
   ```python
   create_backup('.claude/handoff-context.json')
   # Now modify safely
   ```

3. **Use safe_read_json with defaults**:
   ```python
   config = safe_read_json('.claude/config.json', default={})
   ```

4. **Validate after reading**:
   ```python
   features = safe_read_json('feature_list.json', default=[])
   if not isinstance(features, list):
       logger.error("feature_list.json corrupted!")
       sys.exit(1)
   ```

### ❌ DON'T

1. **Don't use regular file writes for state files**:
   ```python
   # ❌ WRONG - Race condition!
   with open('.claude/handoff-context.json', 'w') as f:
       json.dump(data, f)

   # ✅ RIGHT - Atomic
   atomic_write_json(data, '.claude/handoff-context.json')
   ```

2. **Don't append without atomic helper**:
   ```python
   # ❌ WRONG - Not atomic!
   with open('claude-progress.txt', 'a') as f:
       f.write(log_entry)

   # ✅ RIGHT - Atomic
   atomic_append_text(log_entry, 'claude-progress.txt')
   ```

3. **Don't read without error handling**:
   ```python
   # ❌ WRONG - Crashes on missing file
   with open('.claude/handoff-context.json') as f:
       context = json.load(f)

   # ✅ RIGHT - Safe with default
   context = safe_read_json('.claude/handoff-context.json', default={})
   ```

## Error Handling

All atomic operations raise exceptions on failure:

```python
from atomic_file_ops import atomic_write_json

try:
    atomic_write_json(data, '.claude/handoff-context.json')
except IOError as e:
    logger.error(f"Failed to write handoff context: {e}")
    # Fallback: Try backup location
    atomic_write_json(data, '.claude/handoff-context.json.emergency')
except ValueError as e:
    logger.error(f"Data cannot be serialized: {e}")
    sys.exit(1)
```

## File Corruption Recovery

The `/sdk-bridge:resume` command automatically detects and recovers from corrupted state files:

1. Validates JSON syntax
2. Restores from most recent `.bak` file
3. Creates new safety backups
4. Reports recovery status

Manual recovery:
```bash
# List available backups
ls -lt .claude/handoff-context.json.*.bak

# Restore from backup
cp .claude/handoff-context.json.1704985200.bak .claude/handoff-context.json
```

## Testing Atomic Writes

```python
import json
from pathlib import Path
from atomic_file_ops import atomic_write_json, safe_read_json

def test_atomic_write():
    test_file = '.claude/test.json'

    # Write data
    data = {'test': True, 'count': 42}
    atomic_write_json(data, test_file)

    # Read back
    result = safe_read_json(test_file)
    assert result == data

    # Cleanup
    Path(test_file).unlink()
    print("✅ Atomic write test passed")

if __name__ == '__main__':
    test_atomic_write()
```

## Performance Notes

- **Overhead**: Minimal (~1-2ms per write for typical state files)
- **Disk I/O**: Slightly higher (temp file creation), but prevents corruption
- **Recommended**: Use for all state files, even frequent updates
- **Not needed**: For transient files like logs (unless appending)

## References

- **Implementation**: `scripts/atomic-write.sh`, `scripts/atomic_file_ops.py`
- **Usage**: All harness scripts should import and use these helpers
- **Pattern**: Temp file + atomic rename (POSIX standard)
- **Recovery**: `/sdk-bridge:resume` command validates and restores
