# Changelog

All notable changes to SDK Bridge are documented here.

---

## [7.1.0] - 2026-03-27

Quality-of-life improvements: resume support, task naming validation, permission transparency, and documentation fixes.

### Added
- **Resume detection** in `/sdk-bridge:start` — detects existing `prd.json` and offers resume, archive, or fresh start before asking for project input
- **`TaskCreated` hook** (`hooks/validate-task-name.sh`) — validates task subjects follow `[US-XXX]: Title` format; script is ready but registration deferred (`TaskCreated` event not yet in hooks schema)
- **`effort: high`** on implementer agent — complex TDD implementation benefits from higher reasoning effort
- **`/loop` progress monitor** in start.md — after spawning teammates, offers to set up automatic `/loop 5m` progress reporting within the session
- **Monitoring section** in README.md — documents `/loop` as the primary monitoring method, watchdog.sh as fallback for outside sessions
- **Permissions guidance** in Checkpoint 6 — warns users that teammates inherit the lead's permission mode and suggests `--dangerously-skip-permissions` for autonomous execution

### Fixed
- **prd.json coordination gap** — implementer no longer reads or modifies prd.json; all story details now included in TaskCreate descriptions; dependency checking uses TaskList `blockedBy` exclusively; only the team lead updates prd.json after all stories complete
- **`progress.txt` → `progress.jsonl`** in prd-converter archiving section (stale v6 reference)
- **Duplicate "How to Start"** in code-reviewer.md — removed contradictory second section that used `git diff` instead of `git diff main...HEAD`
- **Catastrophic failure in `validate-task.sh`** — missing config file now returns `{"continue": false}` to stop the teammate instead of silently passing validation

### Removed
- **`sdk-bridge-evaluation.md`** — stale v5/v6 evaluation document that described removed architecture (bash loop, worktree isolation, failure-analyzer skill, architect/merger agents)

### Documentation
- **CLAUDE.md** — added `permissionMode` limitation gotcha, updated hooks table to 5 events, version bump
- **README.md** — added permissions prerequisite, monitoring section, updated version badge and hooks count

---

## [7.0.0] - 2026-03-17

Complete architectural rewrite: replaces the bash orchestration loop with native Claude Code Agent Teams for parallel story execution.

### Added
- **Agent Teams orchestration** — `/sdk-bridge:start` command acts as team lead, spawning N implementer teammates that run in parallel and coordinate via shared task list
- **`TaskCompleted` hook** (`hooks/validate-task.sh`) — runs `test_command`, `build_command`, `typecheck_command` after each story; exit 2 sends failure output back as feedback to the teammate
- **`TeammateIdle` hook** (`hooks/check-idle.sh`) — checks `prd.json` for remaining stories; exit 2 prevents teammates from stopping prematurely
- **`SessionStart` hook** (`hooks/inject-context.sh`) — injects PRD progress summary (project, branch, N/N stories) into session context on startup and resume
- **`PreCompact` hook** (`hooks/preserve-context.sh`) — re-injects current story criteria and codebase patterns from `progress.jsonl` before context compaction
- **`scripts/watchdog.sh`** — shows incomplete stories and resume instructions when a run crashes or is interrupted
- **Dependency graph analysis** in prd-converter skill — after conversion, outputs parallel groups and suggested teammate count
- **`progress.jsonl`** — structured JSON lines replace `progress.txt`; implementers append per-story pattern entries; PreCompact hook reads from it
- **`max_teammates` config field** — controls concurrent teammate count (default: 5; actual count is `min(max_teammates, parallel_story_groups)`)
- **Task tools on implementer** — `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate` added to implementer frontmatter for story claiming workflow
- **Peer pattern sharing** — implementers broadcast codebase discoveries as JSON entries to `progress.jsonl`, shared with other teammates during PreCompact

### Changed
- **`commands/start.md`** — rewritten from bash-loop launcher to inline team lead orchestrator (5 checkpoints + orchestration phase with TaskCreate, Agent Teams spawn, monitor, review)
- **`agents/implementer.md`** — rewritten for Agent Teams: removed `isolation: worktree`, `skills: [failure-analyzer]`, inline PostToolUse hook; added task-claiming workflow (TaskList → claim → implement → commit → TaskUpdate → repeat)
- **`agents/reviewer.md`** — updated to review full feature branch diff across all stories (`git diff main...HEAD`) instead of per-story review; accepts `progress.jsonl` for implementation context
- **`agents/code-reviewer.md`** — updated to review full branch diff; added `How to Start` section with `git diff main...HEAD` instructions
- **`skills/prd-generator/SKILL.md`** — updated story size guidance: "self-contained for one teammate"; added note about parallel execution and independent verifiability
- **`skills/prd-converter/SKILL.md`** — updated for Agent Teams: "independently implementable by one teammate"; added Dependency Graph Output section; replaced `sdk-bridge.sh` archiving note; replaced `progress.txt` with `progress.jsonl`
- **`scripts/check-deps.sh`** — removed `coreutils`/`timeout` check (no bash loop); added Agent Teams environment check (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **`scripts/prd.json.example`** — updated with full dependency fields (`depends_on`, `related_to`, `implementation_hint`, `check_before_implementing`) showing parallel and sequential story patterns
- **`hooks/hooks.json`** — rewritten: removed `PreToolUse`, `SubagentStart`, `SubagentStop`; added `TaskCompleted`, `TeammateIdle`; updated `SessionStart` matcher (`startup|resume`) and script path
- **`.claude-plugin/plugin.json`** — version `7.0.0`; removed `failure-analyzer` skill, `architect` and `merger` agents; updated description and keywords
- **`CLAUDE.md`** — complete rewrite for v7.0: updated architecture diagram, hooks table, config schema, execution flow, gotchas
- **`README.md`** — complete rewrite: Agent Teams flow diagram, component table, hook behaviour table, v6 vs v7 comparison table

### Removed
- **`agents/architect.md`** — read-only codebase explorer (role absorbed into implementer's "check before implementing" step)
- **`agents/merger.md`** — git branch operations (start command handles branching inline)
- **`skills/failure-analyzer/SKILL.md`** — error categorization skill (replaced by `TaskCompleted` hook feedback loop)
- **`scripts/sdk-bridge.sh`** — bash orchestration loop (replaced by Agent Teams in start.md)
- **`scripts/prompt.md`** — iteration instructions for bash loop (no longer needed)
- **`scripts/check-git.sh`** — git diagnostics script
- **`hooks/check-destructive.sh`** — `PreToolUse` safety check (removed with bash loop)
- **`hooks/inject-learnings.sh`** — `SubagentStart` learnings injection (replaced by `TeammateIdle` + `progress.jsonl`)
- **`hooks/validate-result.sh`** — `SubagentStop` validation gate (replaced by `TaskCompleted` hook)
- **`hooks/inject-prd-context.sh`** — `PreCompact` context injection (replaced by `preserve-context.sh`)
- **`hooks/auto-lint.sh`** — inline `PostToolUse` typecheck hook on implementer (removed with worktree isolation)
- **`progress.txt`** — replaced by `progress.jsonl`
- **Config fields**: `max_iterations`, `iteration_timeout`, `execution_mode`, `execution_model`, `effort_level`, `fallback_model` (bash loop settings, no longer applicable)

---

## [6.0.0] - 2026-03-07

### Added
- **Worktree isolation** — each story runs in an isolated git worktree (no cross-story file interference)
- **`--json-schema` structured output** — enforced JSON response from every iteration, replaces fragile string parsing
- **`fallback_model` config field** — resilience when primary model is overloaded (e.g., `"fallback_model": "sonnet"`)
- **`SubagentStart` hook** (`inject-learnings.sh`) — injects `progress.txt` learnings into implementer context before each story
- **`PreCompact` hook** (`inject-prd-context.sh`) — re-injects current story context before context compaction
- **Inline `PostToolUse` hook** on implementer — runs typecheck after every `Edit`/`Write` in interactive path
- **Agent memory** (`memory: project`) — implementer, reviewer, and code-reviewer accumulate cross-session knowledge
- **Advisory code review** — separate Sonnet instance reviews completed story diffs (logged to `progress.txt`, non-blocking)
- **`effort_level` config field** — Opus 4.6 effort level (`"high"` | `"medium"`)

### Changed
- Implementer agent: added `isolation: worktree`, `skills: [failure-analyzer]`, inline PostToolUse hook
- `sdk-bridge.sh`: reads config with `jq`; passes `--json-schema` to every Claude invocation; handles worktree isolation flow
- Reviewer and code-reviewer now run per-story (not per-branch)
- `progress.txt`: structured learnings format with story ID, patterns, files

### Fixed
- Structured output parsing reliability (was grep-based, now schema-enforced)
- Cross-story file interference from parallel (sequential) context accumulation

---

## [5.0.0] - 2026-03-04

### Added
- **5 subagents** from TaskPlex proven infrastructure: architect, implementer, reviewer, code-reviewer, merger
- **3 hooks**: SessionStart (context injection), PreToolUse (command safety), SubagentStop (validation gate)
- **Failure analyzer skill** — categorizes errors (`env_missing`, `test_failure`, `timeout`, `code_error`, `dependency_missing`, `unknown`) with retry strategy
- **JSON config** at `.claude/sdk-bridge.config.json` with legacy YAML fallback
- **Resume intelligence** — detects completed stories on interrupted runs, carries forward learnings
- **Quality gate commands** — configurable `test_command`, `build_command`, `typecheck_command`
- **Code review toggle** — optional adversarial code-reviewer agent after validation
- **TDD discipline** inlined in implementer agent (RED-GREEN-REFACTOR)
- **Two-stage review** — spec compliance (reviewer) then code quality (code-reviewer)
- **Git safety** — `check-destructive.sh` blocks force push, `reset --hard`, push to main
- **Git diagnostics** — `check-git.sh` outputs JSON diagnostic report

### Changed
- Config format: YAML frontmatter → JSON (`sdk-bridge.config.json`)
- Wizard Checkpoint 6: Added quality settings (test/build/typecheck auto-detect, code review toggle)
- `sdk-bridge.sh`: Config reading uses `jq`, with legacy YAML fallback

---

## [4.0.0] - 2026-01-22

### Added
- Interactive wizard with 7 checkpoints
- PRD generator skill with smart decomposition (5-criteria threshold)
- PRD converter skill with dependency inference
- Configurable iteration timeouts (default: 15 min)
- Already-implemented detection (prompt-based)
- Robust process management (trap-based cleanup, per-branch PIDs)
- Verifiable acceptance criteria requirements
- Dependency tracking metadata (`depends_on`, `related_to`, `implementation_hint`, `check_before_implementing`)
- Automatic archiving of previous runs

### Removed
- All 10 commands (replaced with single `/sdk-bridge:start`)
- 2 validation agents
- Python harness (replaced with bash loop)
- Complex state management
