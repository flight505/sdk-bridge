# SDK Bridge UX Hardening Plan
**Date**: 2026-01-16
**Version**: 2.2.3 (Target)
**Priority**: CRITICAL

## Executive Summary

**What Happened**: User ran `/sdk-bridge:init` and experienced the legacy multi-command workflow instead of the v2.0 generative UI with interactive AskUserQuestion prompts.

**Root Causes Identified**:
1. **Command Discovery Issue**: `/init` appears before `/start` alphabetically, misleading users
2. **Semantic Confusion**: "init" sounds like "first step," but `/start` is actually the modern entry point
3. **Missing File Bug**: `parallel_coordinator.py` not installed due to version mismatch in commands
4. **Documentation Gap**: README, SKILL.md, and user-facing docs still reference legacy workflow

**Impact**:
- 67% more steps in legacy workflow
- Lost AskUserQuestion interactive configuration
- Lost TodoWrite live progress tracking
- Lost generative UI experience
- Degraded first impression

---

## Investigation Findings

### Finding 1: Command Naming & Discovery (CRITICAL)

**Agent**: a29298e (command discoverability investigation)

**Problem**:
- Users type `/sdk-bridge:` + Tab and see alphabetical list
- `/sdk-bridge:init` appears at position 5
- `/sdk-bridge:start` appears at position 10
- "init" semantically signals "initialize first"
- "start" sounds like "start after init"

**Evidence**:
- README.md (lines 26-84): Shows legacy workflow with `/init`
- SKILL.md (lines 10-14): Only lists init, handoff, status, resume, cancel
- CONTEXT_sdk-bridge.md: Mixed messaging (acknowledges start but promotes init)
- No deprecation warning in init.md

**Key Files**:
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/README.md` (OUTDATED)
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/skills/sdk-bridge-patterns/SKILL.md` (OUTDATED)
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/commands/init.md` (NO WARNING)

**User Journey Failure**:
```
1. User installs plugin
2. Types /sdk-bridge: and presses Tab
3. Sees /sdk-bridge:init before /sdk-bridge:start
4. Reads: "Initialize project for SDK bridge"
5. Thinks: "This sounds like the first step!"
6. Runs /sdk-bridge:init → Legacy workflow
7. Never discovers /sdk-bridge:start → Missed v2.0 features
```

---

### Finding 2: Missing parallel_coordinator.py (BLOCKER)

**Agent**: a5264d5 (missing file diagnosis)

**Problem**:
- File exists in plugin bundle: `plugins/sdk-bridge/scripts/parallel_coordinator.py` ✅
- File included in installation scripts ✅
- **But version check hardcoded to 2.2.1 in commands** ❌
- Plugin actual version is 2.2.2
- Users with v2.2.1 installed show "UP_TO_DATE" and skip reinstall
- Missing file blocks parallel execution mode

**Evidence**:
```bash
# User's error:
nohup: /Users/jesper/.claude/skills/long-running-agent/.venv/bin/python
/Users/jesper/.claude/skills/long-running-agent/harness/parallel_coordinator.py:
No such file or directory

# Version mismatch:
plugin.json:         v2.2.2 ✅
marketplace.json:    v2.2.2 ✅
init.md line 19:     v2.2.1 ❌
start.md line 19:    v2.2.1 ❌
```

**Git History**:
- Commit `4e6e9b8`: Bumped to v2.2.1
- Commit `fcd55eb`: Bumped to v2.2.2
- **Both commits forgot to update version strings in init.md/start.md**

**Key Files**:
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/commands/init.md` (line 19)
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/commands/start.md` (line 19)

---

### Finding 3: UX Workflow Analysis (DESIGN)

**Agent**: a8c1e97 (command workflow UX analysis)

**Comparison Table**:

| Feature | `/init` (Legacy) | `/start` (v2.0+) |
|---------|-----------------|------------------|
| **Auto-install** | ✅ Silent | ✅ Silent |
| **Interactive UI** | ❌ No | ✅ AskUserQuestion (3-4 questions) |
| **Progress tracking** | ⚠️ Install only | ✅ Full TodoWrite (install → launch) |
| **Configuration** | ⚠️ File with defaults | ✅ Interactive prompts |
| **Launches agent** | ❌ Requires separate `/handoff` | ✅ Auto-launches |
| **Model selection** | ❌ Edit file | ✅ Interactive choice |
| **Session count** | ❌ Edit file | ✅ Interactive choice (10/20/30/50) |
| **Parallel mode** | ❌ Edit file | ✅ Interactive choice (if plan exists) |
| **Advanced features** | ⚠️ Defaults (no choice) | ✅ Multi-select checkboxes |

**Workflow Comparison**:

**Legacy Path** (init → handoff):
1. `/sdk-bridge:init` → Creates config with defaults
2. Manually edit `.claude/sdk-bridge.local.md` (if needed)
3. `/sdk-bridge:handoff` → Launches agent
4. `tail -f .claude/sdk-bridge.log` → Monitor externally
5. `/sdk-bridge:status` → Manual polling

**Total**: 2-3 commands, 5-7 steps

**Modern Path** (start):
1. `/sdk-bridge:start` → Interactive setup + auto-launch
2. `/sdk-bridge:watch` (optional live polling)

**Total**: 1-2 commands, 2-4 steps

**Reduction**: 67% fewer commands, 50% fewer steps, zero manual editing

---

## Hardening Plan

### Phase 1: Critical Fixes (v2.2.3 - IMMEDIATE)

**Target**: Ship within 24 hours

#### Fix 1.1: Update Version Strings (BLOCKER)

**Files**:
- `plugins/sdk-bridge/commands/init.md` (line 19)
- `plugins/sdk-bridge/commands/start.md` (line 19)

**Change**:
```bash
# Before:
PLUGIN_VERSION="2.2.1"

# After:
PLUGIN_VERSION="2.2.2"
```

**Verification**:
```bash
# After fix:
1. Reinstall plugin
2. Run /sdk-bridge:init
3. Should show "UPDATE_AVAILABLE" and reinstall
4. Verify: ls ~/.claude/skills/long-running-agent/harness/ | grep parallel_coordinator.py
```

**Impact**: Unblocks parallel execution for all users

---

#### Fix 1.2: Add Deprecation Warning to /init (UX)

**File**: `plugins/sdk-bridge/commands/init.md`

**Add at top** (after frontmatter, before "# Initialize Project"):
```markdown
---
description: "⚠️ DEPRECATED: Use /sdk-bridge:start for modern workflow"
argument-hint: "[project-dir]"
allowed-tools: ["Bash", "Read", "Write", "TodoWrite", "Task"]
---

# ⚠️ Deprecated Command - Use /sdk-bridge:start Instead

**This command is part of the legacy v1.x workflow.**

For the modern v2.0+ experience with interactive configuration:
👉 **Run `/sdk-bridge:start` instead**

## Why /sdk-bridge:start is better:
- ✅ Interactive setup (no manual file editing)
- ✅ Auto-launches agent (no separate /handoff needed)
- ✅ Live progress tracking
- ✅ Guided configuration

## Continue with legacy /init?

If you prefer the legacy workflow, I'll proceed with manual configuration below.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Initialize Project for SDK Bridge (Legacy)
```

**Impact**: Educates users at point of use, reduces future /init usage

---

#### Fix 1.3: Update Command Descriptions (DISCOVERY)

**File**: `plugins/sdk-bridge/.claude-plugin/plugin.json`

**Change**:
```json
{
  "commands": [
    {
      "path": "./commands/init.md",
      "description": "⚠️ DEPRECATED: Use /sdk-bridge:start (legacy manual setup)"
    },
    {
      "path": "./commands/start.md",
      "description": "✅ RECOMMENDED: Interactive setup & auto-launch (one command)"
    }
  ]
}
```

**Note**: Command descriptions come from frontmatter, not plugin.json. Update frontmatter instead:

**File**: `plugins/sdk-bridge/commands/init.md` (line 2)
```yaml
description: "⚠️ DEPRECATED: Use /sdk-bridge:start (legacy manual setup)"
```

**File**: `plugins/sdk-bridge/commands/start.md` (line 2)
```yaml
description: "✅ RECOMMENDED: Interactive setup & auto-launch (one command)"
```

**Impact**: Clear guidance in command listings

---

### Phase 2: Documentation Updates (v2.2.3 - SAME RELEASE)

#### Fix 2.1: Update README.md (PUBLIC DOCS)

**File**: `plugins/sdk-bridge/README.md`

**Changes**:

**Lines 23-37** (Quick Start section):
- Move v2.0 workflow to top
- Add warning badge to legacy workflow
- Add comparison table

**Lines 77-85** (Commands list):
- Mark `/init` and `/handoff` as "(Legacy)"
- Add missing commands: `start`, `watch`, `plan`, `observe`, `enable-parallel`, `approve`

**Lines 155-175** (Architecture):
- Update commands list to include all 12 commands
- Mark legacy commands clearly

**Add new section** (after Architecture, before Troubleshooting):
```markdown
## Migration Guide: v1.x → v2.0

### Quick Summary
- **Old**: `/sdk-bridge:init` + `/sdk-bridge:handoff` (2 commands, manual config)
- **New**: `/sdk-bridge:start` (1 command, interactive UI)

### Why Migrate?
- ✅ 67% fewer commands
- ✅ Interactive configuration (AskUserQuestion)
- ✅ Live progress tracking (TodoWrite)
- ✅ Auto-launch (no separate handoff)

### Deprecated Commands
- `/sdk-bridge:init` → Use `/sdk-bridge:start`
- `/sdk-bridge:handoff` → Included in `/sdk-bridge:start`
- `/sdk-bridge:lra-setup` → Auto-installs during `/sdk-bridge:start`

### When to Use Legacy Commands
- Scripting/automation (init creates config files programmatically)
- CI/CD pipelines (non-interactive environments)
- Advanced users who prefer manual configuration
```

---

#### Fix 2.2: Update SKILL.md (IN-CHAT DOCS)

**File**: `plugins/sdk-bridge/skills/sdk-bridge-patterns/SKILL.md`

**Lines 10-14** (Quick Reference):
```markdown
**Commands**:
- `/sdk-bridge:start` - **[RECOMMENDED]** Interactive setup & auto-launch
- `/sdk-bridge:watch` - Live progress monitoring
- `/sdk-bridge:status` - Quick status check
- `/sdk-bridge:resume` - Resume in CLI after completion
- `/sdk-bridge:cancel` - Stop running SDK agent
- `/sdk-bridge:init` - **[LEGACY]** Manual configuration (use /start instead)
- `/sdk-bridge:handoff` - **[LEGACY]** Manual launch (use /start instead)
```

**Update workflow sections** to reference `/start` instead of `/init`:
- Lines 30-50: Change "Plan → Init → Handoff" to "Plan → Start"
- Lines 100-120: Update examples to use `/start`

---

#### Fix 2.3: Update CLAUDE.md (DEV DOCS)

**File**: `CLAUDE.md`

**Lines 297-320** (Workflow sections):
```markdown
**RECOMMENDED Workflow (v2.0+):**
1. User runs `/sdk-bridge:start` → Auto-detects setup status, installs harness if needed (silent), shows interactive config UI, launches agent
2. User runs `/sdk-bridge:plan` (optional, before start) → creates `feature-graph.json`, `execution-plan.json` for parallel execution
[...]

**DEPRECATED Workflow (v1.x - Legacy):**
⚠️ This workflow is deprecated. Use `/sdk-bridge:start` for modern experience.

1. User runs `/sdk-bridge:lra-setup` (first time only) → installs 7 harness scripts to `~/.claude/skills/`
2. User runs `/sdk-bridge:init` → creates `sdk-bridge.local.md` with advanced feature flags
[...]
```

---

### Phase 3: Advanced Improvements (v2.3.0 - NEXT MINOR)

#### Improvement 3.1: Create Welcome Command

**New file**: `plugins/sdk-bridge/commands/help.md`

```markdown
---
description: "Show getting started guide and command overview"
argument-hint: ""
allowed-tools: []
---

# SDK Bridge - Getting Started

Welcome to SDK Bridge v2.0! 🚀

## Quick Start (Recommended)

For first-time setup and launch:
```
/sdk-bridge:start
```

This provides:
- ✅ Interactive configuration (model, sessions, features)
- ✅ Auto-installation if needed
- ✅ Automatic agent launch
- ✅ Live progress tracking

## Advanced Workflows

### Planning & Dependencies
```
/sdk-bridge:plan
```
Analyze feature dependencies and create execution plan for parallel mode.

### Monitoring
```
/sdk-bridge:watch      # Live progress polling (30s)
/sdk-bridge:status     # Quick status check
/sdk-bridge:observe    # View agent logs
```

### Control
```
/sdk-bridge:approve    # Review pending high-risk operations
/sdk-bridge:cancel     # Stop running agent
/sdk-bridge:resume     # Review completed work
```

## Legacy Commands (v1.x)

⚠️ **These commands are deprecated in v2.0+**

- `/sdk-bridge:init` → Use `/sdk-bridge:start` instead
- `/sdk-bridge:handoff` → Now part of `/sdk-bridge:start`
- `/sdk-bridge:lra-setup` → Auto-installs during `/sdk-bridge:start`

## Documentation

- **Full docs**: See `SKILL.md` loaded when skill activates
- **Developer docs**: `CLAUDE.md` for internal architecture
- **Context**: `CONTEXT_sdk-bridge.md` for consolidated reference

## Need Help?

- Troubleshooting: Check `.claude/sdk-bridge.log`
- Issues: https://github.com/flight505/sdk-bridge/issues
- Marketplace: https://github.com/flight505/flight505-marketplace
```

**Add to plugin.json** commands array:
```json
"./commands/help.md"
```

---

#### Improvement 3.2: Add Soft Redirect in /init

**File**: `plugins/sdk-bridge/commands/init.md`

**After deprecation warning, before proceeding**:
```markdown
## ⚠️ Continue with Legacy Workflow?

You can proceed with manual configuration, but I recommend using the modern workflow.

**Use AskUserQuestion**:
```json
{
  "questions": [{
    "question": "How would you like to proceed?",
    "header": "Setup",
    "multiSelect": false,
    "options": [
      {
        "label": "Use /sdk-bridge:start (Recommended)",
        "description": "Modern interactive workflow with guided setup"
      },
      {
        "label": "Continue with /init (Legacy)",
        "description": "Manual configuration, requires separate /handoff"
      }
    ]
  }]
}
```

If user selects "Use /sdk-bridge:start":
```markdown
Redirecting to modern workflow...

**Use Task tool**:
```
Task(
  subagent_type="general-purpose",
  description="Run /sdk-bridge:start",
  prompt="Execute /sdk-bridge:start command for the user"
)
```

If user selects "Continue with /init":
```markdown
Proceeding with legacy manual configuration...
[Continue with existing init.md logic]
```

**Impact**: Soft redirect with user consent, educates without forcing

---

### Phase 4: Telemetry & Monitoring (v2.3.0)

#### Add Usage Tracking

**Purpose**: Understand command usage patterns

**Metrics to track**:
1. Command invocation counts:
   - `/start` vs `/init` usage ratio
   - First-time vs returning users
2. Redirect events:
   - Users who clicked "Use /start" in soft redirect
   - Users who continued with legacy /init
3. Feature adoption:
   - % users enabling semantic memory
   - % users enabling parallel execution
   - % users customizing advanced settings
4. Success rates:
   - % sessions completing successfully
   - Average sessions to completion
   - Most common failure reasons

**Implementation**:
- Add telemetry calls in command frontmatter
- Use Claude Code's existing analytics framework
- Privacy-preserving (no PII, no code)

**Dashboard**:
- Weekly report on command usage
- Migration progress (target: 80% on /start by v2.4.0)
- Feature adoption trends

---

### Phase 5: Cleanup (v3.0.0 - MAJOR)

#### Remove Deprecated Commands

**Breaking changes**:
1. Remove `/sdk-bridge:init` entirely
2. Remove `/sdk-bridge:handoff` entirely
3. Remove `/sdk-bridge:lra-setup` entirely

**Migration period**:
- v2.2.3 (now): Add deprecation warnings
- v2.3.0: Add soft redirects
- v2.4.0: Make redirects mandatory (remove "continue with legacy" option)
- v2.5.0: Final warning before removal
- v3.0.0: Delete legacy commands

**Rationale**:
- Gives users 3+ months to migrate
- Clear deprecation timeline
- Reduces maintenance burden

---

## Implementation Checklist

### v2.2.3 (Critical Fixes - IMMEDIATE)

- [ ] Fix 1.1: Update version strings in init.md (line 19) and start.md (line 19)
  - Change `PLUGIN_VERSION="2.2.1"` → `PLUGIN_VERSION="2.2.2"`

- [ ] Fix 1.2: Add deprecation warning to init.md (top of file)
  - Add banner explaining /start is recommended

- [ ] Fix 1.3: Update command descriptions in frontmatter
  - init.md: Add "⚠️ DEPRECATED" prefix
  - start.md: Add "✅ RECOMMENDED" prefix

- [ ] Fix 2.1: Update README.md
  - Move v2.0 workflow to top
  - Add migration guide section
  - Update commands list (all 12 commands)

- [ ] Fix 2.2: Update SKILL.md
  - Reorder commands (start first)
  - Mark legacy commands
  - Update workflow examples

- [ ] Fix 2.3: Update CLAUDE.md
  - Rename "Simplified" → "RECOMMENDED"
  - Rename "Legacy" → "DEPRECATED"
  - Add migration timeline

- [ ] Test: Verify parallel_coordinator.py installs correctly
  ```bash
  /plugin uninstall sdk-bridge@sdk-bridge-marketplace
  /plugin install sdk-bridge@sdk-bridge-marketplace
  ls ~/.claude/skills/long-running-agent/harness/ | grep parallel_coordinator.py
  ```

- [ ] Test: Verify deprecation warning shows in /init
  ```bash
  /sdk-bridge:init
  # Should show warning banner at top
  ```

- [ ] Commit: "fix: update version strings, add deprecation warnings (v2.2.3)"

- [ ] Version: Bump to v2.2.3 in all locations
  - plugin.json
  - marketplace.json
  - CLAUDE.md (line 3)
  - README.md (line 5)

- [ ] Push: Trigger webhook for marketplace update

### v2.3.0 (Advanced Improvements - NEXT SPRINT)

- [ ] Improvement 3.1: Create /sdk-bridge:help command
  - Add help.md file
  - Register in plugin.json
  - Test command appears in listing

- [ ] Improvement 3.2: Add soft redirect in /init
  - Add AskUserQuestion prompt
  - Handle "Use /start" selection → redirect
  - Handle "Continue with /init" selection → proceed
  - Test both paths

- [ ] Improvement 4.1: Add telemetry tracking
  - Track command usage
  - Track redirect events
  - Track feature adoption
  - Create dashboard

- [ ] Commit: "feat: add welcome command and soft redirects (v2.3.0)"

- [ ] Version: Bump to v2.3.0

- [ ] Push: Release to marketplace

### v3.0.0 (Cleanup - FUTURE)

- [ ] Remove deprecated commands
  - Delete init.md
  - Delete handoff.md
  - Delete lra-setup.md

- [ ] Update plugin.json
  - Remove deleted commands from registry

- [ ] Update documentation
  - Remove all legacy workflow references
  - Update examples to use modern workflow only

- [ ] Breaking change announcement
  - GitHub release notes
  - Marketplace changelog
  - Migration guide for remaining users

- [ ] Version: Bump to v3.0.0 (MAJOR)

---

## Success Criteria

**v2.2.3 Release**:
- ✅ All users can install parallel_coordinator.py
- ✅ /init shows deprecation warning
- ✅ Documentation updated to promote /start
- ✅ No breaking changes

**v2.3.0 Release**:
- ✅ Soft redirect reduces /init usage by 50%
- ✅ /help command provides clear guidance
- ✅ Telemetry tracking active
- ✅ Feature adoption measured

**v3.0.0 Release**:
- ✅ 90%+ users on modern workflow
- ✅ Legacy commands removed
- ✅ Codebase simplified
- ✅ Maintenance burden reduced

---

## Risk Assessment

### Low Risk
- Version string updates (isolated change)
- Documentation updates (non-breaking)
- Deprecation warnings (informational)

### Medium Risk
- Soft redirect (could confuse users if poorly implemented)
- Telemetry (privacy concerns, requires clear opt-out)

### High Risk
- Removing commands in v3.0 (breaking change, requires migration period)

**Mitigation**:
- Test all changes in local environment before release
- Stage rollout (v2.2.3 warnings → v2.3.0 redirects → v3.0.0 removal)
- Clear communication in release notes
- Provide migration guide for all breaking changes

---

## Timeline

| Version | Release Date | Focus | Scope |
|---------|-------------|-------|-------|
| v2.2.3 | 2026-01-17 (24h) | Critical fixes | Version strings, deprecation warnings, docs |
| v2.3.0 | 2026-01-30 (2 weeks) | UX improvements | Welcome command, soft redirects, telemetry |
| v2.4.0 | 2026-02-28 (1 month) | Mandatory migration | Hard redirects, remove "continue with legacy" |
| v2.5.0 | 2026-03-31 (2 months) | Final warnings | Announce v3.0 removal |
| v3.0.0 | 2026-05-01 (3+ months) | Breaking changes | Remove legacy commands |

---

## Appendix A: Agent Investigation Details

### Agent a29298e (Command Discoverability)
- **Runtime**: 1m 1s
- **Tool uses**: 18
- **Tokens**: 26.7k
- **Key finding**: README.md completely outdated, shows only v1.x workflow
- **Resume**: Can continue investigation of user onboarding flow

### Agent a5264d5 (Missing File Diagnosis)
- **Runtime**: Not specified
- **Tool uses**: Multiple file reads, git history
- **Tokens**: Not specified
- **Key finding**: Version mismatch between plugin (2.2.2) and commands (2.2.1)
- **Resume**: Can verify fix after version update

### Agent a8c1e97 (UX Workflow Analysis)
- **Runtime**: Not specified
- **Tool uses**: Comparative analysis, workflow mapping
- **Tokens**: Not specified
- **Key finding**: 67% reduction in commands with modern workflow
- **Resume**: Can continue detailed UX improvement research

---

## Appendix B: Related Issues

### Issue 1: Parallel Execution Errors
**Symptom**: Users see "parallel_coordinator.py: No such file or directory"
**Root cause**: Version string mismatch
**Fix**: v2.2.3 Fix 1.1
**Status**: Blocked until release

### Issue 2: User Confusion About Commands
**Symptom**: Users run /init when they should run /start
**Root cause**: Alphabetical ordering, naming semantics
**Fix**: v2.2.3 Fix 1.2, 1.3, 2.1-2.3
**Status**: Blocked until release

### Issue 3: Feature Adoption Low
**Symptom**: Users don't know about v2.0 features
**Root cause**: No interactive onboarding
**Fix**: Guide users to /start instead of /init
**Status**: Indirect fix via above changes

---

## Appendix C: Key File Paths

### Commands
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/commands/init.md`
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/commands/start.md`

### Documentation
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/README.md`
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/skills/sdk-bridge-patterns/SKILL.md`
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/CLAUDE.md`

### Configuration
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/.claude-plugin/plugin.json`
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/.claude-plugin/marketplace.json`

### Scripts
- `/Users/jesper/Projects/Dev_projects/Claude_SDK/flight505-marketplace/sdk-bridge/plugins/sdk-bridge/scripts/parallel_coordinator.py` (exists, not installed)
- `/Users/jesper/.claude/skills/long-running-agent/harness/` (installation target)

---

**End of Hardening Plan**
