# CLAUDE.md

**Version 6.0.0** | Last Updated: 2026-03-07

Developer instructions for the SDK Bridge plugin for Claude Code CLI.

---

## Overview

SDK Bridge is an **interactive autonomous development assistant** providing a single command (`/sdk-bridge:start`) that:
1. Generates detailed PRDs with clarifying questions
2. Converts to executable JSON format
3. Runs fresh Claude agent loops with quality gates until all work is complete

**Philosophy:** Radical simplicity. One command, interactive wizard, fresh Claude instances each iteration. Quality enforced through TDD, two-stage review, and failure categorization.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

---

## Architecture

```
sdk-bridge/
├── .claude-plugin/plugin.json        # Plugin manifest
├── agents/                            # 5 subagents
│   ├── architect.md                   # Read-only codebase explorer
│   ├── implementer.md                 # Code a single story (TDD + verify)
│   ├── reviewer.md                    # Spec compliance + validation (two-phase)
│   ├── code-reviewer.md              # Code quality review (opt-in)
│   └── merger.md                      # Git branch operations
├── commands/
│   └── start.md                       # Interactive wizard (7 checkpoints)
├── skills/
│   ├── prd-generator/                 # PRD creation with clarifying questions
│   ├── prd-converter/                 # Markdown -> JSON converter
│   └── failure-analyzer/              # Error categorization + retry strategy
├── hooks/
│   ├── hooks.json                     # 3 hooks across 3 events
│   ├── session-context.sh             # SessionStart: inject prd.json awareness
│   ├── check-destructive.sh           # PreToolUse: block dangerous commands
│   └── validate-result.sh             # SubagentStop: test/build/typecheck gate
├── scripts/
│   ├── sdk-bridge.sh                  # Main bash loop
│   ├── prompt.md                      # Instructions for each Claude iteration
│   ├── check-deps.sh                  # Dependency checker
│   ├── check-git.sh                   # Git repository diagnostics
│   └── prd.json.example              # Reference format
└── examples/                          # Example PRDs
```

### Subagents

| Agent | Model | Permission | Purpose | Isolation | Memory |
|-------|-------|------------|---------|-----------|--------|
| architect | sonnet | dontAsk | Read-only codebase explorer | — | project |
| implementer | inherit | bypassPermissions | Code a single story (TDD + verify) | worktree | project |
| reviewer | haiku | dontAsk | Spec compliance + validation (two-phase) | — | project |
| code-reviewer | sonnet | dontAsk | Code quality review (opt-in) | — | project |
| merger | haiku | bypassPermissions | Git branch operations | — | — |

### Hooks

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | session-context.sh | Detects active prd.json, reports story progress |
| PreToolUse (Bash) | check-destructive.sh | Blocks force push, reset --hard, etc. |
| SubagentStop (implementer) | validate-result.sh | Runs test/build/typecheck commands |
| PreCompact | inject-prd-context.sh | Re-injects current story + patterns before compaction |

**Note:** SubagentStop hooks fire for native subagents only, NOT for `claude -p` instances from the bash loop. The bash loop uses `prompt.md` for quality checks.

### State Files (User's Project)

```
.claude/
├── sdk-bridge.config.json     # Config (JSON)
├── sdk-bridge-{branch}.pid   # Per-branch PID file
└── sdk-bridge.log             # Background mode log

tasks/
└── prd-{feature}.md           # Human-readable PRD

prd.json                       # Execution format (source of truth)
progress.txt                   # Learnings log (append-only)
```

---

## Configuration

`.claude/sdk-bridge.config.json`:

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
  "code_review": true
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `max_iterations` | number | 20 | Stop after N iterations |
| `iteration_timeout` | number | 3600 | Timeout per iteration (seconds) |
| `execution_mode` | string | "foreground" | "foreground" or "background" |
| `execution_model` | string | "sonnet" | "sonnet" or "opus" |
| `effort_level` | string | "" | "low", "medium", "high" (Opus only) |
| `branch_prefix` | string | "sdk-bridge" | Git branch prefix |
| `test_command` | string | "" | e.g. "npm test" |
| `build_command` | string | "" | e.g. "npm run build" |
| `typecheck_command` | string | "" | e.g. "tsc --noEmit" |
| `code_review` | bool | true | Enable code-reviewer after validation |
| `fallback_model` | string | "" | Fallback model if primary overloaded (e.g. "sonnet") |

**Legacy support:** Falls back to `.claude/sdk-bridge.local.md` (YAML frontmatter) if JSON config not found.

---

## Development Guidelines

### When in doubt, use the claude-docs-skill

If the project has `claude-docs-skill` installed in `.claude/skills/`, use it for Claude API, CLI, SDK, hooks, plugins, or agent questions.

### Modifying Components

- **Agents** — YAML frontmatter defines tools, model, permissionMode, maxTurns. Keep tool lists minimal (least privilege). Use `haiku` for cheap/fast, `sonnet` for quality, `inherit` for user's model.
- **Skills** — Single responsibility. Lettered options (A, B, C, D) for questions.
- **Hooks** — `${CLAUDE_PLUGIN_ROOT}` resolves to install path. Scripts must be `chmod +x`. Sync hooks need `statusMessage` and `timeout`.
- **Scripts** — `set -e` for fail-fast. Bash 3.2 compatible (no `declare -A`). `jq` is the only JSON parser.
- **Commands** — Use `AskUserQuestion` at decision points. Follow 7-checkpoint structure.

### Testing Changes

```bash
# Reinstall and test
/plugin uninstall sdk-bridge@flight505-marketplace
/plugin install sdk-bridge@flight505-marketplace
# Restart Claude Code, then:
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

## Authentication

```bash
# OAuth (recommended for Max subscribers)
claude setup-token
export CLAUDE_CODE_OAUTH_TOKEN='your-token'

# API key (fallback)
export ANTHROPIC_API_KEY='your-key'
```

---

## Gotchas

- Shell scripts must be **bash 3.2 compatible** — no `declare -A`, no bash 4+ features
- `jq` is the only JSON parser — no yq or Python for JSON
- `hooks/hooks.json` is **auto-discovered** — never add `"hooks"` field to plugin.json
- `PermissionRequest` hooks do NOT fire in `-p` (headless) mode
- `set -e` + `[ cond ] && action` at end of function = silent crash — use `if/then/fi`
- Hook scripts run in non-interactive shells — aliases and `.zshrc` not loaded
- Exit 2 messages must go to stderr; stdout is for structured JSON output
- SubagentStop hooks only fire for native subagents, not `claude -p` bash loop instances
- Implementer runs in worktree isolation — file changes are in a temporary copy, merged back on success
- Agent memory persists in `.claude/agent-memory/<agent-name>/` — check into git for team sharing
- `--json-schema` enforces structured output; iterations that can't produce valid JSON will fail

---

## Debugging

```bash
# Check installation
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins | keys'

# Verify plugin structure
ls -la ~/.claude/plugins/cache/flight505-marketplace/sdk-bridge/*/

# Test script directly
bash scripts/sdk-bridge.sh 1

# Verify dependencies
bash scripts/check-deps.sh

# Validate hooks.json
jq . hooks/hooks.json
```

---

## References

- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference.md)
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless.md)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks.md)
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents.md)
- [Plugin Development](https://github.com/anthropics/claude-code/blob/main/docs/plugins.md)
- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)

---

**Maintained by:** Jesper Vang (@flight505)
**Repository:** https://github.com/flight505/sdk-bridge
**License:** MIT
