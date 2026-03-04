# Changelog

All notable changes to SDK Bridge will be documented in this file.

## [5.0.0] - 2026-03-04

### Added
- **5 subagents** from TaskPlex proven infrastructure: architect, implementer, reviewer, code-reviewer, merger
- **3 hooks**: SessionStart (context injection), PreToolUse (command safety), SubagentStop (validation gate)
- **Failure analyzer skill** — categorizes errors (env_missing, test_failure, timeout, code_error, dependency_missing, unknown) with retry strategy
- **JSON config** at `.claude/sdk-bridge.config.json` with legacy YAML fallback
- **Resume intelligence** — detects completed stories on interrupted runs, carries forward learnings
- **Quality gate commands** — configurable test, build, typecheck commands in config
- **Code review toggle** — optional adversarial code-reviewer agent after validation
- **TDD discipline** inlined in implementer agent prompt (RED-GREEN-REFACTOR)
- **Two-stage review** — spec compliance (reviewer) then code quality (code-reviewer)
- **Git safety** — check-destructive.sh blocks force push, reset --hard, push to main
- **Git diagnostics** — check-git.sh outputs JSON diagnostic report

### Changed
- Config format: YAML frontmatter (`.claude/sdk-bridge.local.md`) -> JSON (`.claude/sdk-bridge.config.json`)
- Wizard Checkpoint 6: Added quality settings (test/build/typecheck auto-detect, code review toggle)
- sdk-bridge.sh: Config reading uses jq instead of grep/sed, with legacy fallback
- plugin.json: Added agents array, failure-analyzer skill, expanded metadata

## [4.8.1] - 2026-02-15

### Fixed
- Minor bug fixes and stability improvements

## [4.0.0] - 2026-01-22

### Added
- Interactive wizard with 7 checkpoints
- PRD generator skill with smart decomposition (5-criteria threshold)
- PRD converter skill with dependency inference
- Configurable iteration timeouts (default: 15 min)
- Already-implemented detection (prompt-based)
- Robust process management (trap-based cleanup, per-branch PIDs)
- Verifiable acceptance criteria requirements
- Dependency tracking metadata
- Automatic archiving of previous runs

### Removed
- All 10 commands (replaced with single `/start`)
- 2 validation agents
- Python harness (replaced with bash loop)
- Complex state management
