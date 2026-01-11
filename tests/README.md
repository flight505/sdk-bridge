# SDK Bridge Plugin Test Suite

This directory contains automated tests for validating the SDK Bridge plugin installation, functionality, and correctness.

## Quick Start

### Run All Tests
```bash
bash tests/run_all_tests.sh
```

### Run Individual Test
```bash
bash tests/test_installation.sh
bash tests/test_sdk.sh
bash tests/test_command_consolidation.sh
```

### Validate Project After Handoff
```bash
cd /path/to/your/project
bash /path/to/sdk-bridge-marketplace/tests/verify_file_creation.sh
bash /path/to/sdk-bridge-marketplace/tests/verify_git_commits.sh
```

## Test Categories

### Installation Tests
- **test_installation.sh**: Verifies all 7 Python scripts are installed
- **test_sdk.sh**: Verifies Claude Agent SDK is functional

### Command Structure Tests
- **test_command_consolidation.sh**: Checks for duplicate commands

### File Verification Tests
- **verify_file_creation.sh**: Validates files are actually created (not just reported)
- **verify_git_commits.sh**: Validates git commits contain real file changes

## Test Status

| Test | Status | Notes |
|------|--------|-------|
| test_installation.sh | ❌ FAIL | Only 1/7 scripts installed |
| test_sdk.sh | ✅ PASS | SDK functional |
| test_command_consolidation.sh | ⚠️ WARN | Duplicate handoff commands |
| verify_file_creation.sh | ❌ FAIL | Files not created |
| verify_git_commits.sh | ❌ FAIL | Empty commits |

## Known Issues

1. **Installation Incomplete**: Only `autonomous_agent.py` installed, missing 6 v2 scripts
2. **File Creation**: Features marked complete but files don't exist
3. **Empty Commits**: Git commits created but no files staged
4. **Command Duplication**: Both `handoff.md` and `handoff-v2.md` exist

## Expected Test Results After Fixes

After implementing fixes from TESTING_STRATEGY.md:

```
✅ test_installation.sh: All 7 files installed
✅ test_sdk.sh: SDK functional
✅ test_command_consolidation.sh: Unified handoff command
✅ verify_file_creation.sh: All files created
✅ verify_git_commits.sh: Non-empty commits
```

## Adding New Tests

1. Create test script: `tests/test_new_feature.sh`
2. Make executable: `chmod +x tests/test_new_feature.sh`
3. Add to `run_all_tests.sh`
4. Document in this README

## Test Script Guidelines

All test scripts should:
- Use `#!/bin/bash` and `set -euo pipefail`
- Return exit code 0 on success, non-zero on failure
- Print clear ✅/❌ status messages
- Include summary section with results
- Be runnable from any directory

## Related Documentation

- **TESTING_STRATEGY.md**: Comprehensive testing strategy and validation approach
- **CLAUDE.md**: Plugin architecture and development guidelines
- **README.md**: User-facing plugin documentation

## Support

For issues with tests, see TESTING_STRATEGY.md section 10 for troubleshooting.
