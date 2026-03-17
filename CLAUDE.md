# CLAUDE.md

**Version 7.0.0** | Last Updated: 2026-03-17

Developer instructions for the SDK Bridge plugin for Claude Code CLI.

---

## Overview

SDK Bridge is an **interactive autonomous development assistant** providing a single command (`/sdk-bridge:start`) that:
1. Generates detailed PRDs with clarifying questions
2. Converts to executable JSON format with dependency graph analysis
3. Orchestrates Agent Teams for parallel story implementation until all work is complete

**Philosophy:** Radical simplicity. One command, interactive wizard, Agent Teams parallelism. Quality enforced through TDD, TaskCompleted validation gates, and two-stage post-completion review.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Architecture

```
sdk-bridge/
├── .claude-plugin/plugin.json        # Plugin manifest
├── agents/                            # 3 agents
│   ├── implementer.md                 # Teammate: claim, code, commit, share
│   ├── reviewer.md                    # Full-branch spec compliance review
│   └── code-reviewer.md              # Full-branch code quality review
├── commands/
│   └── start.md                       # Interactive wizard + team lead orchestrator
├── skills/
│   ├── prd-generator/                 # PRD creation with clarifying questions
│   └── prd-converter/                 # Markdown → JSON + dependency graph
├── hooks/
│   ├── hooks.json                     # 4 hooks across 4 events
│   ├── validate-task.sh               # TaskCompleted: test/build/typecheck gate
│   ├── check-idle.sh                  # TeammateIdle: prevents early shutdown
│   ├── inject-context.sh              # SessionStart: injects PRD status
│   └── preserve-context.sh            # PreCompact: re-injects story context
└── scripts/
    ├── check-deps.sh                  # Dependency checker (claude, jq, agent-teams)
    ├── watchdog.sh                    # Crash recovery guide
    └── prd.json.example              # Reference format with parallel execution
```

### Agents

| Agent | Role | Model | Permission | Purpose |
|-------|------|-------|------------|---------|
| implementer | teammate | inherit | bypassPermissions | Claim tasks, TDD, commit, share patterns |
| reviewer | subagent | haiku | dontAsk | Post-completion full-branch spec compliance |
| code-reviewer | subagent | sonnet | dontAsk | Post-completion full-branch code quality |

### Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | inject-context.sh | Injects PRD progress into session context |
| TaskCompleted | validate-task.sh | Runs test/build/typecheck; exit 2 blocks completion |
| TeammateIdle | check-idle.sh | Prevents teammates from stopping while stories remain |
| PreCompact | preserve-context.sh | Re-injects current story + patterns before compaction |

### State Files (User's Project)

```
.claude/
└── sdk-bridge.config.json     # Config (JSON)

tasks/
└── prd-{feature}.md           # Human-readable PRD

prd.json                       # Execution format (source of truth)
progress.jsonl                 # Learnings log (append-only, JSON lines)
```

---

## Execution Flow

```
/sdk-bridge:start
  → Checkpoint 1: check-deps.sh (claude, jq, CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)
  → Checkpoint 2: User describes project
  → Checkpoint 3: prd-generator skill → tasks/prd-feature.md
  → Checkpoint 4: User reviews and approves PRD
  → Checkpoint 5: prd-converter skill → prd.json + dependency graph
  → Checkpoint 6: Configure quality commands + code review
  → Orchestration:
      git checkout -b [branchName]
      TaskCreate for each story
      Agent Teams: N implementer teammates in parallel
        teammate: TaskList → claim → implement (TDD) → commit → TaskUpdate(completed)
        validate-task.sh fires on TaskCompleted → test/build/typecheck gate
        check-idle.sh fires on TeammateIdle → blocks if stories remain
      Wait for all tasks → completed
      Spawn reviewer subagent → full branch diff review
      Spawn code-reviewer subagent (if enabled) → full branch quality review
      prd.json: all passes = true
      progress.jsonl: final summary entry
```

---

## Configuration

`.claude/sdk-bridge.config.json`:

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

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max_teammates` | number | 5 | Maximum concurrent implementer teammates |
| `branch_prefix` | string | "sdk-bridge" | Git branch prefix |
| `test_command` | string | "" | e.g. "npm test" |
| `build_command` | string | "" | e.g. "npm run build" |
| `typecheck_command` | string | "" | e.g. "tsc --noEmit" |
| `code_review` | bool | true | Enable code-reviewer after all stories complete |

---

## Development Guidelines

### When in doubt, use the claude-docs-skill

If the project has `claude-docs-skill` installed in `.claude/skills/`, use it for Claude API, CLI, SDK, hooks, plugins, or agent questions.

### Modifying Components

- **Agents** — YAML frontmatter defines tools, model, permissionMode, maxTurns. Implementer is a teammate (no worktree isolation, has Task tools). Reviewer and code-reviewer are subagents (read-only, review full branch diff).
- **Skills** — Single responsibility. Lettered options (A, B, C, D) for questions.
- **Hooks** — `${CLAUDE_PLUGIN_ROOT}` resolves to install path. Scripts must be `chmod +x`. Sync hooks need `statusMessage` and `timeout`. `TaskCompleted` and `TeammateIdle` are Agent Teams events.
- **Scripts** — `set -e` for fail-fast. Bash 3.2 compatible (no `declare -A`). `jq` is the only JSON parser.
- **Commands** — Use `AskUserQuestion` at decision points. The start command is both wizard and team lead orchestrator.

### Testing Changes

```bash
# Reinstall and test
/plugin uninstall sdk-bridge@flight505-marketplace
/plugin install sdk-bridge@flight505-marketplace
# Enable Agent Teams, then:
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
/sdk-bridge:start
```

### File Conventions

| Context | Pattern |
|---------|---------|
| Commands (markdown) | `${CLAUDE_PLUGIN_ROOT}/scripts/file.sh` |
| Skills (markdown) | Relative paths `./examples/file.md` |
| Hooks (JSON) | `${CLAUDE_PLUGIN_ROOT}/scripts/file.sh` |
| Bash scripts | Absolute paths `$HOME/.claude/...` |
| Naming | `kebab-case` everywhere |
| Permissions | `chmod +x scripts/*.sh && git add --chmod=+x scripts/*.sh` |

---

## Gotchas

- **Agent Teams is experimental** — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Shell scripts must be **bash 3.2 compatible** — no `declare -A`, no bash 4+ features
- `jq` is the only JSON parser — no yq or Python for JSON
- `hooks/hooks.json` is **auto-discovered** — never add `"hooks"` field to plugin.json
- `PermissionRequest` hooks do NOT fire in `-p` (headless) mode
- `set -e` + `[ cond ] && action` at end of function = silent crash — use `if/then/fi`
- Hook scripts run in non-interactive shells — aliases and `.zshrc` not loaded
- Exit 2 messages must go to stderr; stdout is for structured JSON output
- Implementer runs as a teammate with shared filesystem — no worktree isolation
- Teammates coordinate via TaskList/TaskUpdate — they do NOT share memory directly
- progress.jsonl replaces progress.txt — use JSON lines format for machine-readability
- Token cost: parallel teammates multiply token usage; `max_teammates` controls this

---

## Debugging

```bash
# Check installation
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | keys'

# Verify plugin structure
ls -la ~/.claude/plugins/cache/flight505-marketplace/sdk-bridge/*/

# Check for incomplete run
bash scripts/watchdog.sh

# Verify dependencies
bash scripts/check-deps.sh

# Validate hooks.json
jq . hooks/hooks.json

# Check story status
cat prd.json | jq '.userStories[] | {id, title, passes}'
```

---

## References

- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference.md)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams.md)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks.md)
- [Plugin Development](https://github.com/anthropics/claude-code/blob/main/docs/plugins.md)
- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)

---

**Maintained by:** Jesper Vang (@flight505)
**Repository:** https://github.com/flight505/sdk-bridge
**License:** MIT
