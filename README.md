# SDK Bridge

![SDK Bridge Hero](./assets/sdk-bridge-hero.jpg)

[![Version](https://img.shields.io/badge/version-6.0.0-blue.svg)](https://github.com/flight505/sdk-bridge)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://github.com/anthropics/claude-code)

> **Why "SDK Bridge"?** It bridges the gap between your high-level requirements and autonomous AI execution—transforming human intent into working code through the Claude Code CLI.

Interactive autonomous development assistant that generates PRDs, converts them to execution format, and runs fresh Claude agent loops with quality gates until all work is complete.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## What's New in v6.0.0

- **Worktree isolation** — Each implementer story runs in an isolated git worktree, no cross-story interference
- **Structured output** — `--json-schema` enforces validated JSON from every iteration (replaces string parsing)
- **Fallback model** — Configurable `--fallback-model` for resilience when primary model is overloaded
- **5 hooks** — Added SubagentStart (inject learnings), PreCompact (preserve context during compaction), PostToolUse (auto-lint)
- **Advisory code review** — Fresh Sonnet instance reviews each completed story's diff, logged to progress.txt
- **Agent memory** — `memory: project` on implementer, reviewer, and code-reviewer for cross-session learning
- **Wider skill triggers** — prd-generator and prd-converter trigger on natural language ("plan this", "run this")

### Previous (v5.0.0)

- 5 subagents — architect, implementer (with TDD), reviewer (two-stage), code-reviewer, merger
- Failure categorization — Analyzes errors, recommends retry strategy
- JSON config — `.claude/sdk-bridge.config.json` replaces YAML frontmatter
- Resume intelligence — Detects completed stories on interrupted runs
- Quality gates — Test, build, typecheck commands run after each story

---

## Architecture

![SDK Bridge Architecture](./assets/sdk-bridge-architecture.png?v=6.0.0)

SDK Bridge uses a **bash orchestration loop** that spawns fresh Claude CLI instances for each iteration. State persists via:
- **prd.json** — Source of truth for story completion status
- **progress.txt** — Append-only log of learnings and patterns
- **Git commits** — Code changes from previous iterations

Each iteration is a fresh Claude instance with clean context. The bash coordinator reads state files, spawns a new Claude CLI process, and continues until all stories pass or max iterations reached.

### Components

| Component | Count | Purpose |
|-----------|-------|---------|
| Commands | 1 | Interactive wizard (`/sdk-bridge:start`) |
| Skills | 3 | PRD generator, PRD converter, failure analyzer |
| Agents | 5 | architect, implementer, reviewer, code-reviewer, merger |
| Hooks | 5 | Context injection, safety checks, validation gates, learnings injection, compaction protection |

---

## Interactive Workflow

![SDK Bridge Wizard](./assets/sdk-bridge-wizard.png?v=6.0.0)

SDK Bridge guides you through a **7-checkpoint interactive workflow**:

1. **Dependency Check** — Verifies `claude` CLI, `jq`, and `coreutils`
2. **Project Input** — Describe your project or provide a file path
3. **Generate PRD** — Creates structured PRD with clarifying questions
4. **Review PRD** — Approve, suggest improvements, edit manually, or start over
5. **Convert to JSON** — Transforms markdown PRD to executable `prd.json`
6. **Execution Settings** — Iterations, timeout, mode, model, quality commands, code review
7. **Launch** — Starts the autonomous orchestration loop

---

## Prerequisites

- [Claude Code CLI](https://code.claude.com)
- `jq` JSON parser (`brew install jq` on macOS)
- Git repository for your project
- Authentication (OAuth token or API key)

**Authentication (choose one):**

```bash
# Option 1: OAuth Token (recommended for Max subscribers)
claude setup-token
export CLAUDE_CODE_OAUTH_TOKEN='your-token'

# Option 2: API Key
export ANTHROPIC_API_KEY='your-key'
```

---

## Installation

```bash
# Add marketplace
/plugin marketplace add flight505/flight505-marketplace

# Install plugin
/plugin install sdk-bridge@flight505-marketplace
```

---

## Quick Start

```bash
# Run the interactive wizard
/sdk-bridge:start
```

That's it! SDK Bridge will guide you through PRD generation, review, configuration, and launch.

---

## How It Works

### The Loop

```
for iteration in 1..max_iterations:
  1. Read prd.json to find next story where "passes": false
  2. Spawn fresh Claude instance (isolated worktree, clean context)
  3. Claude implements ONE story:
     - Check for existing implementation first
     - Implement with TDD discipline
     - Auto-lint after each edit (PostToolUse hook)
     - Run quality checks (test, build, typecheck)
     - Commit if checks pass
     - Update prd.json to mark story complete
     - Append learnings to progress.txt
  4. Parse structured JSON output (status, story_id, error_category)
  5. Run advisory code review (Sonnet, if enabled)
  6. If all stories pass, exit; otherwise continue
```

### Key Files

| File | Purpose |
|------|---------|
| `prd.json` | Task list with execution status (source of truth) |
| `tasks/prd-[feature].md` | Human-readable PRD |
| `progress.txt` | Append-only learnings log |
| `.claude/sdk-bridge.config.json` | Configuration (JSON) |

---

## Configuration

Created automatically by the wizard, or edit `.claude/sdk-bridge.config.json`:

```json
{
  "max_iterations": 20,
  "iteration_timeout": 3600,
  "execution_mode": "foreground",
  "execution_model": "opus",
  "effort_level": "high",
  "branch_prefix": "sdk-bridge",
  "test_command": "npm test",
  "build_command": "npm run build",
  "typecheck_command": "tsc --noEmit",
  "code_review": true,
  "fallback_model": "sonnet"
}
```

**Model Selection:**
- **Sonnet 4.5** — Fast and efficient, good for most tasks
- **Opus 4.6 (high effort)** — Best quality, adaptive reasoning, 128K output
- **Opus 4.6 (medium effort)** — Opus quality at 76% fewer tokens

**Planning phase:** Set `export CLAUDE_CODE_SUBAGENT_MODEL=opus` for best PRD quality.

---

## Foreground vs Background

**Foreground (default):**
- See live output as Claude works
- Easy to stop with Ctrl+C

**Background:**
- Runs in background, you continue working
- Check progress: `tail -f .claude/sdk-bridge.log`
- Stop: `kill $(cat .claude/sdk-bridge.pid)`

---

## Quality Gates

SDK Bridge v6 enforces quality at multiple levels:

- **Worktree isolation** — Each story runs in an isolated git worktree, no cross-story interference
- **TDD discipline** — Implementer writes tests before implementation
- **Auto-lint on edit** — PostToolUse hook runs typecheck after every Edit/Write (interactive path)
- **Automated checks** — Test, build, typecheck commands run after each story
- **Structured output** — `--json-schema` validates every iteration returns proper status/results
- **Advisory code review** — Fresh Sonnet instance reviews completed story diffs (logged, non-blocking)
- **Two-stage review** — Spec compliance (reviewer) then code quality (code-reviewer)
- **Failure categorization** — Errors are analyzed and retried with appropriate strategy
- **Context preservation** — PreCompact hook re-injects story context before compaction
- **Resume intelligence** — Interrupted runs detect and skip completed stories

---

## Tips for Success

1. **Small stories** — Each should complete in one Claude context window
2. **Quality checks** — Configure test/build/typecheck commands for automatic validation
3. **Verification commands** — Include specific verification in acceptance criteria
4. **Progress.txt patterns** — Learnings carry forward between iterations

---

## Debugging

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# View learnings
cat progress.txt

# Check git history
git log --oneline -10

# Monitor live (background mode)
tail -f .claude/sdk-bridge.log
```

---

## References

- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference.md)
- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)
- [Claude Code Plugins](https://github.com/anthropics/claude-code)

---

## License

MIT (c) Jesper Vang
