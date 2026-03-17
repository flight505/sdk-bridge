# SDK Bridge

![SDK Bridge Hero](./assets/sdk-bridge-hero.jpg)

[![Version](https://img.shields.io/badge/version-7.0.0-blue.svg)](https://github.com/flight505/sdk-bridge)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://github.com/anthropics/claude-code)

> **Why "SDK Bridge"?** It bridges the gap between your high-level requirements and autonomous AI execution—transforming human intent into working code through the Claude Code CLI.

PRD-driven parallel development assistant that generates PRDs, orchestrates Agent Teams for parallel story implementation, and enforces quality through TDD and two-stage review.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## What's New in v7.0.0

- **Agent Teams orchestration** — Multiple implementer teammates run in parallel, each claiming and implementing independent stories simultaneously
- **Shared task coordination** — TaskCreate/TaskList/TaskUpdate replace the bash loop; the start command is the team lead
- **4 Agent Teams hooks** — TaskCompleted (validation gate), TeammateIdle (work guard), SessionStart (context injection), PreCompact (story preservation)
- **Dependency graph analysis** — prd-converter now outputs parallel groups and suggested teammate count
- **Simplified config** — Removed iteration/timeout/mode settings; no more bash loop to configure
- **3 agents** — implementer (teammate), reviewer (full-branch), code-reviewer (full-branch)
- **progress.jsonl** — Structured JSON lines replace progress.txt for machine-readable pattern sharing

---

## Architecture

```
/sdk-bridge:start (team lead)
    │
    ├── prd-generator skill    → tasks/prd-feature.md
    ├── prd-converter skill    → prd.json + dependency graph
    │
    ├── TaskCreate (one per story)
    │
    ├── Agent Teams (N implementer teammates in parallel)
    │   ├── teammate 1: claim US-001 → implement → TaskUpdate(completed)
    │   ├── teammate 2: claim US-002 → implement → TaskUpdate(completed)
    │   └── teammate N: claim US-003 → implement → TaskUpdate(completed)
    │
    ├── reviewer subagent      → full branch diff review
    └── code-reviewer subagent → full branch code quality (optional)
```

### Components

| Component | Count | Purpose |
|-----------|-------|---------|
| Commands | 1 | Interactive wizard + team lead orchestrator |
| Skills | 2 | PRD generator, PRD converter with dependency graph |
| Agents | 3 | implementer (teammate), reviewer, code-reviewer |
| Hooks | 4 | TaskCompleted, TeammateIdle, SessionStart, PreCompact |

---

## Prerequisites

- [Claude Code CLI](https://code.claude.com) v2.1.32+
- Agent Teams enabled: `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
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
# Enable Agent Teams
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Run the interactive wizard
/sdk-bridge:start
```

That's it. SDK Bridge guides you through PRD generation, review, configuration, and launches an Agent Teams parallel execution.

---

## How It Works

### The Flow

```
1. PRD Generation
   → Clarifying questions → tasks/prd-feature.md

2. PRD Review
   → Approve, improve, edit, or regenerate

3. JSON Conversion
   → prd.json + dependency graph analysis
   → "Group 1: US-001 | Group 2: US-002, US-003 (parallel) | Group 3: US-004"
   → Suggested teammate count: 2

4. Agent Teams Execution
   → git checkout -b sdk-bridge/feature
   → TaskCreate for each story
   → Spawn N implementer teammates
   → Teammates claim stories, implement with TDD, commit, mark complete
   → TaskCompleted hook validates after each story (test/build/typecheck)
   → TeammateIdle hook prevents early shutdown while work remains

5. Post-Completion Review
   → reviewer subagent: full branch diff vs all acceptance criteria
   → code-reviewer subagent: architecture, security, types, tests (optional)

6. Done
   → prd.json marked complete → progress.jsonl updated → report to user
```

### Key Files

| File | Purpose |
|------|---------|
| `prd.json` | Task list with execution status (source of truth) |
| `tasks/prd-[feature].md` | Human-readable PRD |
| `progress.jsonl` | Append-only learnings log (JSON lines, machine-readable) |
| `.claude/sdk-bridge.config.json` | Configuration |

---

## Configuration

Created automatically by the wizard, or edit `.claude/sdk-bridge.config.json`:

```json
{
  "max_teammates": 5,
  "branch_prefix": "sdk-bridge",
  "test_command": "npm test",
  "build_command": "npm run build",
  "typecheck_command": "tsc --noEmit",
  "code_review": true
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `max_teammates` | 5 | Maximum concurrent implementer teammates |
| `branch_prefix` | "sdk-bridge" | Git branch prefix |
| `test_command` | "" | Run after each story completion |
| `build_command` | "" | Run after each story completion |
| `typecheck_command` | "" | Run after each story completion |
| `code_review` | true | Run code-reviewer after all stories complete |

---

## Quality Gates

SDK Bridge v7 enforces quality through:

- **TDD discipline** — Implementers write tests before implementation (RED-GREEN-REFACTOR)
- **TaskCompleted hook** — Runs test/build/typecheck after each story; blocks completion on failure
- **TeammateIdle hook** — Prevents teammates from stopping while incomplete stories remain
- **Pattern sharing** — Implementers append discoveries to progress.jsonl; teammates share codebase knowledge
- **Two-stage review** — Spec compliance (reviewer) then code quality (code-reviewer) on full branch diff
- **Dependency enforcement** — Stories with `depends_on` cannot be claimed until dependencies complete

---

## Debugging

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# View learnings and patterns
cat progress.jsonl | jq .

# Check git history
git log --oneline -10

# Check for incomplete run
bash ${CLAUDE_PLUGIN_ROOT}/scripts/watchdog.sh

# Verify dependencies
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

---

## References

- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference.md)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams.md)
- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)
- [Claude Code Plugins](https://github.com/anthropics/claude-code)

---

## License

MIT (c) Jesper Vang
