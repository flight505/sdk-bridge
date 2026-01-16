"""
Atomic file operations for SDK Bridge harness scripts.

Prevents file corruption from concurrent access by using atomic write operations.
"""

import json
import os
import tempfile
from pathlib import Path
from typing import Any, Dict


def atomic_write_json(data: Dict[str, Any], target_path: str) -> None:
    """
    Atomically write JSON data to file.

    Uses temp file + atomic rename to prevent corruption from concurrent reads.

    Args:
        data: Dictionary to write as JSON
        target_path: Target file path

    Raises:
        IOError: If write fails
        ValueError: If data cannot be serialized to JSON
    """
    target = Path(target_path)
    target_dir = target.parent

    # Ensure directory exists
    target_dir.mkdir(parents=True, exist_ok=True)

    # Create temp file in same directory (ensures same filesystem for atomic mv)
    with tempfile.NamedTemporaryFile(
        mode='w',
        dir=target_dir,
        prefix='.tmp.',
        suffix='.json',
        delete=False
    ) as tmp_file:
        json.dump(data, tmp_file, indent=2)
        tmp_path = tmp_file.name

    try:
        # Atomic rename (guaranteed atomic on POSIX)
        os.replace(tmp_path, target_path)
    except Exception as e:
        # Clean up temp file on error
        try:
            os.unlink(tmp_path)
        except:
            pass
        raise IOError(f"Failed to atomically write {target_path}: {e}")


def atomic_append_text(text: str, target_path: str) -> None:
    """
    Atomically append text to file.

    Reads existing content, appends new text, and writes atomically.

    Args:
        text: Text to append
        target_path: Target file path

    Raises:
        IOError: If read/write fails
    """
    target = Path(target_path)

    # Read existing content (if file exists)
    existing_content = ""
    if target.exists():
        existing_content = target.read_text()

    # Combine existing + new
    new_content = existing_content + text

    # Write atomically
    target_dir = target.parent
    target_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(
        mode='w',
        dir=target_dir,
        prefix='.tmp.',
        suffix='.txt',
        delete=False
    ) as tmp_file:
        tmp_file.write(new_content)
        tmp_path = tmp_file.name

    try:
        os.replace(tmp_path, target_path)
    except Exception as e:
        try:
            os.unlink(tmp_path)
        except:
            pass
        raise IOError(f"Failed to atomically append to {target_path}: {e}")


def safe_read_json(path: str, default: Dict[str, Any] | None = None) -> Dict[str, Any]:
    """
    Safely read JSON file with fallback to default.

    Args:
        path: Path to JSON file
        default: Default value if file doesn't exist or is invalid

    Returns:
        Parsed JSON data or default
    """
    if default is None:
        default = {}

    try:
        with open(path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def create_backup(source_path: str, backup_suffix: str | None = None) -> str:
    """
    Create timestamped backup of file.

    Args:
        source_path: Path to source file
        backup_suffix: Optional suffix (default: timestamp)

    Returns:
        Path to backup file

    Raises:
        FileNotFoundError: If source doesn't exist
    """
    source = Path(source_path)

    if not source.exists():
        raise FileNotFoundError(f"Cannot backup non-existent file: {source_path}")

    if backup_suffix is None:
        import time
        backup_suffix = str(int(time.time()))

    backup_path = f"{source_path}.{backup_suffix}.bak"

    # Copy content
    content = source.read_text()
    Path(backup_path).write_text(content)

    return backup_path
