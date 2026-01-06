---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 20
reserve_sessions: 2
progress_stall_threshold: 3
auto_handoff_after_plan: false
---

# SDK Bridge Configuration

This project is configured for SDK bridge workflows.

## Settings Explained

- **model**: Claude model for SDK sessions
  - `claude-sonnet-4-5-20250929` (default, fast and capable)
  - `claude-opus-4-5-20251101` (most capable, slower and more expensive)

- **max_sessions**: Total sessions before giving up (default: 20)

- **reserve_sessions**: Keep N sessions for manual recovery (default: 2)

- **progress_stall_threshold**: Stop if no progress for N sessions (default: 3)

- **auto_handoff_after_plan**: Automatically handoff after /plan creates feature_list.json (default: false)

## Usage

After initialization:

1. Create feature_list.json (use `/plan` or manually)
2. Run `/sdk-bridge:handoff` to start autonomous work
3. Monitor with `/sdk-bridge:status`
4. Resume with `/sdk-bridge:resume` when complete

## Configuration

You can edit this file to customize settings for this project.
