# SDK Bridge v5.0.0 — Evaluation Report

**Date:** 2026-03-07
**Evaluated by:** Claude Opus 4.6 using skill-creator methodology + claude-docs-skill
**Sources:** cli-full-docs.txt (58 pages), cli-quick-reference.md, changelog.md — all verified against official docs

---

## Part 1: Skill-by-Skill Evaluation

### Skill: `prd-generator`

**Strengths:**
- Well-structured lettered options (A/B/C/D) for fast user responses
- Good story sizing guidance (3-5 criteria, max 6)
- Layer-based decomposition patterns are practical
- "Must verify" acceptance criteria format is excellent for autonomous execution

**Weaknesses:**
- Description is too narrow: `"Triggers on: create a prd, write prd for..."` — misses common phrasings like "plan a feature", "scope this out", "break this into tasks"
- No awareness of existing codebase — asks generic questions rather than analyzing the project first
- Missing: priority/effort estimation per story
- The skill doesn't use the `architect` subagent to explore the codebase before generating the PRD

**Improvement opportunities:**
- Could use the architect agent to scan the codebase first, then generate context-aware PRDs
- Add `context: fork` to run the PRD generation in a subagent for better isolation
- Widen trigger description for better skill matching

---

### Skill: `prd-converter`

**Strengths:**
- Excellent dependency inference rules (true vs false dependencies)
- `check_before_implementing` field is clever — gives agents grep commands
- Story size validation with jq one-liner
- Archiving logic for previous runs

**Weaknesses:**
- Description only triggers on explicit "convert prd" phrases
- Schema is hardcoded in the skill body — should reference an external schema file
- No validation that acceptance criteria actually contain "Must verify" commands
- `priority` field is just ordering, not actual priority (high/medium/low)

**Improvement opportunities:**
- Add schema validation step after conversion
- Could auto-generate `check_before_implementing` commands more intelligently using codebase analysis

---

### Skill: `failure-analyzer`

**Strengths:**
- Clean category taxonomy with detection patterns
- Structured JSON output format
- `user-invocable: false` is correct — only used by implementer

**Weaknesses:**
- Very lightweight — only 47 lines, could be more sophisticated
- Missing categories: `merge_conflict`, `rate_limit`, `context_overflow`, `permission_denied`
- No pattern matching for common framework-specific errors (Next.js, Django, etc.)
- No learning — same errors recur without accumulated knowledge

**Improvement opportunities:**
- Add persistent memory so the analyzer learns project-specific error patterns
- Add `rate_limit` category (important for the bash loop)
- Add `context_overflow` for when stories are too large

---

### Command: `start.md`

**Strengths:**
- 7-checkpoint wizard is well-structured
- Smart defaults for iterations (2.5x/3.5x/5x stories)
- Timeout calculation based on criteria complexity
- Good model selection options (Sonnet/Opus high/Opus medium)

**Weaknesses:**
- References `TodoWrite` tool which was renamed to `Agent` in v2.1.63
- Uses `Task` tool references which should now be `Agent` tool
- Missing: `--max-turns` and `--max-budget-usd` flags (available since late 2025)
- Missing: `--json-schema` for structured output validation
- Missing: `--worktree` / `isolation: worktree` support
- Missing: `--fallback-model` option for resilience
- No option for Agent Teams (experimental but available)
- Execution settings don't expose `--agent` flag which could replace ad-hoc subagent spawning

**Improvement opportunities:**
- Add worktree isolation option to settings
- Add budget cap option (`--max-budget-usd`)
- Add `--json-schema` to get structured implementer output
- Add `--fallback-model sonnet` for Opus runs (resilience)
- Replace Task/TodoWrite references with Agent tool

---

### Agent: `architect`

**Strengths:**
- Clean read-only constraint with explicit disallowedTools
- `memory: project` is appropriate

**Weaknesses:**
- `model: sonnet` is hardcoded — should be configurable or `inherit`
- Missing `isolation: worktree` — would benefit from clean workspace
- No `maxTurns` control (defaults could be high)
- Description is generic — should specify when to use vs Explore built-in

**Improvement opportunities:**
- Add `isolation: worktree` for clean exploration
- Consider `memory: project` to persist architectural discoveries

---

### Agent: `implementer`

**Strengths:**
- Excellent TDD enforcement instructions
- Good "check before implementing" workflow
- `skills: [failure-analyzer]` preloads the right skill
- `permissionMode: bypassPermissions` is correct for autonomous execution
- `maxTurns: 150` gives enough room

**Weaknesses:**
- Missing `isolation: worktree` — THIS IS THE BIGGEST WIN. Each story should run in an isolated worktree
- Missing `background: true` option for parallel story execution
- Missing `hooks` in frontmatter — the SubagentStop hook in hooks.json works, but per-agent hooks would be cleaner
- No `memory: project` — implementer learns patterns per-story but forgets across stories
- `model: inherit` means it uses whatever the user's session model is, but the bash loop already sets `--model`

**Improvement opportunities:**
- Add `isolation: worktree` — each story gets a clean repo copy, no interference
- Add `memory: project` — learns codebase patterns across iterations
- Add inline `hooks` for PostToolUse validation (run linter after Edit/Write)
- Consider `mcpServers` for project-specific tools

---

### Agent: `reviewer`

**Strengths:**
- Two-phase review (spec compliance + validation) is solid
- Skeptical by default ("treat with skepticism")
- Clear verdict rules (approve/request_changes/reject)

**Weaknesses:**
- `model: haiku` may be too lightweight for nuanced spec compliance checking
- Missing `memory: project` — doesn't learn what common spec issues look like
- No `hooks` in frontmatter

**Improvement opportunities:**
- Consider `model: sonnet` for better spec understanding
- Add `memory: project` to accumulate review patterns

---

### Agent: `code-reviewer`

**Strengths:**
- Adversarial posture is good
- Clear severity taxonomy (Critical/Important/Minor)
- Good verdict thresholds

**Weaknesses:**
- Missing `memory: project` — this agent would hugely benefit from persistent memory to track architectural patterns, recurring issues, and project conventions

**Improvement opportunities:**
- Add `memory: project` — most impactful for this agent
- Could reference project-specific coding standards via `skills`

---

### Agent: `merger`

**Strengths:**
- Focused scope — just git operations
- `--no-ff` merge preserves history

**Weaknesses:**
- `model: haiku` is fine for simple git ops
- Missing `permissionMode` documentation — uses `bypassPermissions` which is correct
- No `memory` needed for this agent

---

### Hooks: `hooks.json`

**Strengths:**
- SessionStart context injection is useful
- PreToolUse/Bash destructive command blocking is essential
- SubagentStop/implementer validation is the quality gate

**Weaknesses:**
- Only 3 hooks — missing several valuable events
- No `SubagentStart` hook to inject per-story context
- No `PreCompact` hook to preserve critical context during long implementations
- No `PostToolUse` hook to auto-format after edits
- No `TaskCompleted` hook for completion enforcement
- No `WorktreeCreate`/`WorktreeRemove` hooks for worktree lifecycle
- `session-context.sh` doesn't check for `.claude/sdk-bridge.config.json`
- `validate-result.sh` truncates at 4000 chars — could lose critical error info

**Improvement opportunities:**
- Add `SubagentStart` hook to inject progress.txt learnings into implementer context
- Add `PreCompact` hook to re-inject PRD context before compaction
- Add `PostToolUse` for Edit/Write to run auto-format

---

### Script: `sdk-bridge.sh` (Main Loop)

**Strengths:**
- Robust process management with cleanup
- Per-branch PID files prevent duplicate runs
- Resume intelligence with progress detection
- Timeout handling with retry option
- Archive previous runs automatically

**Weaknesses — THE BIGGEST AREA FOR IMPROVEMENT:**

1. **No `--json-schema` flag** — The bash loop uses `--output-format json` but doesn't validate the structure of the implementer's response. Adding `--json-schema` would ensure every iteration returns properly structured status/results.

2. **No `--max-turns` flag** — Each iteration can run indefinitely within the timeout. Adding `--max-turns 100` would cap runaway iterations.

3. **No `--max-budget-usd`** — No cost protection per iteration.

4. **No `--fallback-model`** — If Opus is overloaded, the iteration fails rather than falling back to Sonnet.

5. **No `--worktree` / `-w` flag** — Each Claude `-p` instance works in the same directory. With `-w`, each iteration would get an isolated worktree.

6. **No `--agent` flag** — The loop sends raw prompt.md text via `-p`. Using `--agent implementer` would use the actual implementer agent definition with all its configuration.

7. **No `--agents` flag** — Could define all 5 agents dynamically via JSON, passing them to each iteration.

8. **No structured output validation** — The loop just checks for `<promise>COMPLETE</promise>` string. With `--json-schema`, it could validate a proper completion schema.

9. **Missing `--continue` / `--resume`** — Each iteration is completely fresh. While this prevents context rot, it also loses valuable in-session learning. Consider using `--continue` for retry iterations on the same story.

10. **No code review orchestration** — The `CODE_REVIEW` config is read but never used in the loop. The code-reviewer agent is never invoked from the bash loop.

---

## Part 2: New Claude Features Available (Verified Against Docs)

### Confirmed Available (GA)

| Feature | Documentation Source | Impact |
|---------|---------------------|--------|
| `isolation: worktree` in agent frontmatter | sub-agents.md | **HIGH** — each agent gets isolated repo |
| `memory: user\|project\|local` in agent frontmatter | sub-agents.md | **HIGH** — agents learn across sessions |
| `hooks` in agent frontmatter (PreToolUse, PostToolUse, Stop) | sub-agents.md | **MEDIUM** — per-agent hook scoping |
| `skills` in agent frontmatter | sub-agents.md | **MEDIUM** — inject skills at startup |
| `background: true` in agent frontmatter | sub-agents.md | **MEDIUM** — run agents in background |
| `mcpServers` in agent frontmatter | sub-agents.md | **LOW** — MCP per agent |
| `SubagentStart` hook event | hooks.md | **MEDIUM** — inject context when agent starts |
| `SubagentStop` hook event | hooks.md | Already used |
| `TeammateIdle` hook event | hooks.md | **LOW** — agent teams only |
| `TaskCompleted` hook event | hooks.md | **MEDIUM** — enforce completion criteria |
| `WorktreeCreate` hook event | hooks.md | **MEDIUM** — track worktree lifecycle |
| `WorktreeRemove` hook event | hooks.md | **MEDIUM** — cleanup after worktree |
| `PreCompact` hook event | hooks.md | **HIGH** — re-inject context before compaction |
| `InstructionsLoaded` hook event | hooks.md | **LOW** — async, informational |
| `SessionEnd` hook event | hooks.md | **LOW** — cleanup |
| `--json-schema` CLI flag | cli-reference.md | **HIGH** — structured output validation |
| `--max-turns` CLI flag | cli-reference.md | **MEDIUM** — cap runaway iterations |
| `--max-budget-usd` CLI flag | cli-reference.md | **MEDIUM** — cost protection |
| `--fallback-model` CLI flag | cli-reference.md | **MEDIUM** — resilience |
| `--agent` CLI flag | cli-reference.md | **HIGH** — use agent definitions directly |
| `--agents` CLI flag | cli-reference.md | **MEDIUM** — dynamic agent definitions |
| `-w` / `--worktree` CLI flag | cli-reference.md | **HIGH** — worktree isolation from CLI |
| `--append-system-prompt-file` CLI flag | cli-reference.md | **MEDIUM** — inject prompts from file |
| `--add-dir` CLI flag | cli-reference.md | **LOW** — multi-directory access |
| Agent Teams (experimental) | agent-teams.md | **LOW** — not ready for production |
| Agent SDK (Python/TypeScript) | headless.md | **MEDIUM** — programmatic alternative to bash |
| `prompt` hooks (LLM-evaluated) | hooks.md | **MEDIUM** — judgment-based validation |
| `agent` hooks (agentic verifier) | hooks.md | **LOW** — complex verification |
| HTTP hooks | hooks.md | **LOW** — webhook integration |

### NOT Available (Hallucinated by Research Agent)

The research agent mentioned some features that I could NOT verify in the docs:
- `WorktreeCreate`/`WorktreeRemove` **are** real (verified)
- Agent SDK **is** real (mentioned on headless.md page)
- Everything else checked out against the actual documentation

---

## Part 3: Prioritized Improvement Recommendations

### Tier 1: High Impact, Low Risk — IMPLEMENTED in v6.0.0 (47d3427)

#### 1. ~~Add `isolation: worktree` to implementer agent~~ DONE
```yaml
---
name: implementer
isolation: worktree
memory: project
---
```
**Why:** Each story implementation gets a clean, isolated copy of the repo. No risk of one story's partial changes affecting the next. The worktree auto-cleans if no changes are made.

#### 2. ~~Add `memory: project` to key agents~~ DONE (already present; fixed Task->Agent deprecation)
```yaml
# implementer.md
memory: project

# code-reviewer.md
memory: project

# reviewer.md
memory: project
```
**Why:** Agents accumulate codebase knowledge across iterations. The implementer learns patterns, the reviewers learn what to watch for. This directly replaces the manual `progress.txt` pattern with native persistent memory.

#### 3. ~~Add `--json-schema` to bash loop~~ DONE
```bash
claude -p "$(cat "$SCRIPT_DIR/prompt.md")" \
  --output-format json \
  --json-schema '{"type":"object","required":["story_id","status"],"properties":{"story_id":{"type":"string"},"status":{"enum":["completed","failed","skipped"]},"error_category":{"type":"string"},"files_modified":{"type":"array","items":{"type":"string"}},"learnings":{"type":"array","items":{"type":"string"}}}}' \
  --allowedTools "Bash,Read,Edit,Write,Glob,Grep,Skill" \
  --no-session-persistence \
  --model "$EXECUTION_MODEL"
```
**Why:** Guarantees structured output from every iteration. No more parsing `<promise>COMPLETE</promise>` strings. The loop can programmatically read `status`, `story_id`, and `error_category`.

#### 4. ~~Add `--fallback-model` for resilience~~ DONE
```bash
$TIMEOUT_CMD $ITERATION_TIMEOUT claude -p "$(cat "$SCRIPT_DIR/prompt.md")" \
  --model "$EXECUTION_MODEL" \
  --fallback-model sonnet \
  ...
```
**Why:** If Opus is overloaded, the iteration falls back to Sonnet instead of failing entirely.

#### 5. ~~Add `PreCompact` hook~~ DONE
```json
{
  "PreCompact": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/inject-prd-context.sh",
          "timeout": 3000
        }
      ]
    }
  ]
}
```
**Why:** Long implementations can trigger context compaction. This hook re-injects the PRD story context and progress.txt learnings before compaction happens, preventing the agent from "forgetting" what it's working on.

---

### Tier 2: Reassessed Through the Ralph Loop Lens

SDK Bridge is based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/). The core
philosophy: **fresh context per iteration, bash simplicity, no session state**. Each `claude -p`
invocation is disposable — it reads prd.json, does one story, writes results, exits. The bash loop
is intentionally dumb. Cost is not a concern because it targets OAuth/Max subscribers with unlimited
usage.

Every Tier 2 proposal must be evaluated against this: **does it make the loop smarter, or does it
make the loop more complex without improving outcomes?**

#### 6. Use `--agent implementer` instead of raw `--prompt` — DEFERRED

```bash
claude -p "Implement the next incomplete story from prd.json" \
  --agent implementer \
  --model "$EXECUTION_MODEL"
```

**Ralph assessment:** The `--agent` flag would use the implementer agent definition (tools,
permissions, skills, memory, isolation) instead of manually specifying `--allowedTools` and passing
prompt.md via `-p`. However, there's a tension:

- **Pro:** The implementer already defines tools, permissions, skills, maxTurns — duplicating this
  in the bash loop is DRY violation
- **Pro:** Would get `isolation: worktree` from the agent definition for free
- **Con:** `claude -p --agent` runs the agent as the *main thread*, not as a subagent. This means
  `SubagentStop` hooks won't fire — the validate-result.sh quality gate bypasses entirely
- **Con:** The bash loop needs explicit control over `--allowedTools` to prevent the agent from
  spawning its own subagents (which would nest indefinitely)
- **Con:** prompt.md contains iteration-specific instructions (read prd.json, append to
  progress.txt, check completion) that differ from the implementer agent's system prompt

**Verdict:** Not compatible with the current architecture without reworking how validation hooks
fire. The bash loop's `prompt.md` approach is actually correct for the Ralph pattern — each
iteration gets the full instruction set as a fresh prompt. The implementer agent definition is
designed for *native subagent* invocation (from interactive sessions), not for the bash loop.

**Revisit when:** Claude Code adds a way to run `--agent` as main thread while still firing
Stop hooks, or when the loop is migrated to Agent SDK.

#### 7. ~~Add `SubagentStart` hook for implementer~~ DONE (789bf49)

```json
{
  "SubagentStart": [
    {
      "matcher": "implementer",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/inject-learnings.sh",
          "timeout": 5000
        }
      ]
    }
  ]
}
```

**Ralph assessment:** Aligns perfectly. The Ralph pattern's weakness is that each iteration starts
with zero codebase knowledge. Currently, prompt.md tells the agent to "Read the Codebase Patterns
section in progress.txt" — but this depends on the agent actually doing it. A SubagentStart hook
injects the patterns automatically into context, making the knowledge transfer deterministic rather
than probabilistic.

**Note:** This only fires for *native subagent* invocations (interactive sessions using the
implementer agent), not for the `claude -p` bash loop. The bash loop still relies on prompt.md
telling the agent to read progress.txt. So this improves the interactive path but doesn't change
the autonomous loop.

**Verdict:** Low-risk addition. Improves the interactive `/sdk-bridge:start` path. Does not affect
the bash loop (which is fine — the loop already handles this via prompt.md instructions).

#### 8. Add `--max-turns` and `--max-budget-usd` — SKIP

**Ralph assessment:** Does not fit the design.

- **Cost:** SDK Bridge targets Max/OAuth subscribers. There's no per-API-call billing. `--max-budget-usd`
  is meaningless in this context and would add false constraints.
- **Turns:** The timeout already caps wall-clock time per iteration. Adding `--max-turns` would
  create a second exit condition that's harder to reason about. If an iteration is taking too many
  turns, it will hit the timeout — that's the designed safety valve.
- **Ralph principle:** Keep the loop dumb. More exit conditions = more failure modes to debug.

**Verdict:** Skip entirely. Not needed for the target audience.

#### 9. ~~Add inline hooks to implementer for auto-linting~~ DONE (789bf49)

```yaml
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/hooks/auto-lint.sh"
          timeout: 10000
```

**Ralph assessment:** Catches errors closer to the source. Currently, lint/format issues are only
caught at the end (SubagentStop validation). If the implementer makes 15 edits and the last
validation finds lint errors from edit #3, it wastes context fixing something that could have been
caught immediately.

**Caveat:** Only fires for native subagent invocations. The bash loop's `claude -p` instances
don't load agent frontmatter hooks. But the SubagentStop validate-result.sh already covers the
bash loop path.

**Implementation note:** Needs a lightweight `auto-lint.sh` script that reads the project's
configured lint command. Should be fast (<5s) and only run on the changed file, not the whole
project.

**Verdict:** Good addition for interactive path. No impact on bash loop (which has its own
validation).

#### 10. ~~Implement code review in bash loop~~ DONE (789bf49)

The `CODE_REVIEW` config exists but is never used in the bash loop. This is the only Tier 2 item
that directly improves the Ralph loop.

```bash
# After successful validation, optionally run code review
if [ "$CODE_REVIEW" = "true" ] && [ "$STORY_STATUS" = "completed" ]; then
  echo "Running code review for $STORY_ID..."
  REVIEW_OUTPUT=$($TIMEOUT_CMD 300 claude -p "Review code changes for story $STORY_ID. Read prd.json, run git diff, check quality." \
    --output-format json \
    --allowedTools "Read,Grep,Glob,Bash" \
    --no-session-persistence \
    --model "sonnet" 2>&1)
  # Log review but don't block — code review is advisory
  echo "$REVIEW_OUTPUT" >> "$PROGRESS_FILE"
fi
```

**Ralph assessment:** Fits the pattern well. A fresh Claude instance reviews the changes, then
exits. Advisory only — doesn't block progress. Uses Sonnet (fast, cheap even on API key) rather
than the implementation model. Adds ~1 minute per story.

**Important design choice:** Review should be advisory (logged) not blocking. The Ralph pattern
values forward progress. If code review blocks, a false positive stalls the entire loop. The
human reviews everything at the end anyway.

**Verdict:** Implement. Closes the gap between config and behavior.

---

### Tier 3: Future / Experimental

#### 11. Migrate bash loop to Agent SDK (Python/TypeScript) — AGAINST for now

**Ralph assessment:** The bash loop is the right tool for this job. It's ~470 lines, trivially
debuggable (`bash -x`), runs anywhere, no dependencies beyond `jq` and `claude`. The Agent SDK
adds Python/TypeScript runtime requirements, package management, and abstraction layers.

The Ralph pattern's entire value proposition is that the orchestration is dumb and disposable.
A Python SDK wrapper makes the orchestration smarter, which means more ways to fail.

**Consider when:** The bash script genuinely can't express the needed logic — parallel story
execution, complex dependency graphs, real-time streaming dashboards.

#### 12. Experiment with Agent Teams for parallel stories — WATCH

Independent stories could theoretically run as teammates. But Agent Teams is experimental,
high-token-cost, and adds coordination overhead. The current sequential approach is predictable
and debuggable.

**Consider when:** Agent Teams is stable AND you have PRDs with 10+ independent stories that
would benefit from parallelism.

#### 13. Add `prompt` hooks for judgment-based validation — INTERESTING

LLM-evaluated hooks could catch nuanced issues that shell scripts miss (e.g., "does this
implementation follow the project's conventions?"). But they add non-determinism to the
validation step and cost per invocation.

**Consider when:** The deterministic hooks (typecheck, test, build) are not catching enough
real issues.

---

## Part 4: Skill Description Improvements — DONE

Descriptions updated with cross-triggering guard rails. When sdk-bridge and TaskPlex are both installed, generic phrases like "plan work", "break into tasks", "run this", "start implementing" must NOT trigger sdk-bridge skills — those belong to TaskPlex's brainstorm/writing-plans/TDD skills.

### Applied Descriptions

**prd-generator:**
- Before: `"...Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."`
- After: `"Generate a Product Requirements Document (PRD) for SDK Bridge autonomous execution. Use when the user explicitly asks to create a PRD, write requirements, generate user stories for sdk-bridge, or scope a feature into a PRD. Also trigger on 'create prd', 'write prd for', 'spec out for sdk-bridge', 'generate requirements document'. Do NOT trigger on general planning, brainstorming, or task decomposition — those belong to other skills."`

**prd-converter:**
- Before: `"...Triggers on: convert this prd, turn this into sdk-bridge format, create prd.json from this, convert prd to json."`
- After: `"Convert markdown PRDs into prd.json execution format for SDK Bridge autonomous agents. Use when a PRD document exists and needs to be converted to SDK Bridge's JSON format. Trigger on 'convert prd', 'convert to prd.json', 'turn this PRD into sdk-bridge format', 'create prd.json from this PRD'. Also used internally by /sdk-bridge:start at the conversion checkpoint. Do NOT trigger on general JSON conversion or plan execution requests."`

**failure-analyzer:**
- Fine as-is (not user-invocable, only used by implementer skill injection)

---

## Summary

### v6.0.0 (SHIPPED — commit 47d3427)

All Tier 1 items implemented:
1. `isolation: worktree` on implementer agent
2. `memory: project` verified on implementer/reviewer/code-reviewer (+ deprecated `Task` -> `Agent` fix)
3. `--json-schema` structured output with prd.json completion detection
4. `--fallback-model` configurable resilience
5. `PreCompact` hook with inject-prd-context.sh

### Tier 2 (SHIPPED — commit 789bf49)

Reassessed through Ralph loop principles, three items implemented:

| # | Item | Status | Benefit |
|---|------|--------|---------|
| 7 | SubagentStart hook (inject learnings) | **DONE** | Deterministic knowledge transfer for interactive path |
| 9 | PostToolUse auto-lint on implementer | **DONE** | Earlier error detection for interactive path |
| 10 | Code review in bash loop | **DONE** | Closes the config-vs-behavior gap, advisory review per story |

### Items Deferred or Skipped

| # | Item | Verdict | Rationale |
|---|------|---------|-----------|
| 6 | `--agent` flag in bash loop | **DEFERRED** | Breaks SubagentStop hook chain; prompt.md approach is correct for Ralph. Revisit when `--agent` supports Stop hooks as main thread, or when migrating to Agent SDK. |
| 8 | `--max-turns` / `--max-budget-usd` | **SKIPPED** | OAuth/Max subscribers don't need cost caps; timeout is the designed safety valve. More exit conditions = more failure modes. |
| 11 | Agent SDK migration | **SKIPPED** | Bash loop is the right abstraction for the Ralph pattern — ~470 lines, trivially debuggable, no dependencies. Consider when bash genuinely can't express the needed logic. |
| 12 | Agent Teams for parallel stories | **WATCHING** | Experimental, high token cost, sequential is more predictable and debuggable. Consider when Agent Teams is stable and PRDs have 10+ independent stories. |
| 13 | `prompt` hooks for judgment-based validation | **WATCHING** | Non-deterministic validation adds complexity. Consider when deterministic hooks (typecheck, test, build) aren't catching enough real issues. |
