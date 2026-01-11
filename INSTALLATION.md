# SDK Bridge Installation Guide

## Clean Installation Instructions

This guide provides step-by-step instructions for installing the SDK Bridge plugin cleanly, ensuring no conflicts with previous installations.

## Prerequisites

- Claude Code CLI installed and configured
- Git repository (recommended for version control)
- Python 3.8+ installed
- API authentication configured (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY)

## Installation Methods

### Method 1: Install from flight505-marketplace (Recommended)

This method installs SDK Bridge from the flight505 marketplace containing multiple curated plugins.

```bash
# Step 1: Add the flight505 marketplace
/plugin marketplace add flight505/flight505-marketplace

# Step 2: Install SDK Bridge plugin
/plugin install sdk-bridge@flight505-marketplace

# Step 3: Verify installation
/plugin list
# You should see: sdk-bridge@flight505-marketplace (version 1.9.0)

# Step 4: Run initial setup (installs harness scripts)
/sdk-bridge:lra-setup
```

### Method 2: Install from sdk-bridge-marketplace (Direct)

This method installs SDK Bridge directly from its standalone marketplace.

```bash
# Step 1: Add the sdk-bridge marketplace
/plugin marketplace add flight505/sdk-bridge-marketplace

# Step 2: Install SDK Bridge plugin
/plugin install sdk-bridge@sdk-bridge-marketplace

# Step 3: Verify installation
/plugin list
# You should see: sdk-bridge@sdk-bridge-marketplace (version 1.9.0)

# Step 4: Run initial setup (installs harness scripts)
/sdk-bridge:lra-setup
```

## Verification

After installation, verify all commands are available:

```bash
# Should display all 10 SDK Bridge commands:
# /sdk-bridge:lra-setup
# /sdk-bridge:init
# /sdk-bridge:plan
# /sdk-bridge:enable-parallel
# /sdk-bridge:handoff
# /sdk-bridge:approve
# /sdk-bridge:observe
# /sdk-bridge:status
# /sdk-bridge:resume
# /sdk-bridge:cancel
```

## First-Time Setup

```bash
# Step 1: Install harness scripts (first-time only)
/sdk-bridge:lra-setup
# Installs 7 harness scripts to ~/.claude/skills/long-running-agent/harness/

# Step 2: Navigate to your project
cd /path/to/your/project

# Step 3: Initialize SDK Bridge in project
/sdk-bridge:init
# Creates .claude/sdk-bridge.local.md configuration

# Step 4: Create feature plan (using /plan or manually)
/plan
# Creates feature_list.json

# Step 5: (Optional) Analyze dependencies for parallel execution
/sdk-bridge:plan
# Creates .claude/execution-plan.json

# Step 6: (Optional) Enable parallel mode if recommended
/sdk-bridge:enable-parallel
# Updates config to enable parallel execution

# Step 7: Hand off to autonomous agent
/sdk-bridge:handoff
# Launches SDK agent in background
```

## Troubleshooting

### Old Installation Conflicts

If you encounter errors about existing installations:

```bash
# Step 1: Check for old installations
ls -la ~/.claude/plugins/cache/

# Step 2: Remove old sdk-bridge cache
rm -rf ~/.claude/plugins/cache/sdk-bridge-marketplace

# Step 3: Check installed plugins
cat ~/.claude/plugins/installed_plugins.json | jq '.plugins'

# Step 4: Uninstall old version if present
/plugin uninstall sdk-bridge@sdk-bridge-marketplace
/plugin uninstall sdk-bridge@flight505-marketplace

# Step 5: Restart Claude Code and try installation again
```

### Marketplace Not Found

If you get "marketplace not found" error:

```bash
# Check known marketplaces
cat ~/.claude/plugins/known_marketplaces.json | jq 'keys'

# Remove marketplace if corrupted
/plugin marketplace remove flight505-marketplace
# OR
/plugin marketplace remove sdk-bridge-marketplace

# Re-add marketplace
/plugin marketplace add flight505/flight505-marketplace
```

### Commands Not Appearing

If `/sdk-bridge:*` commands don't appear after installation:

```bash
# Step 1: Verify plugin is installed
/plugin list

# Step 2: Check plugin location
ls -la ~/.claude/plugins/cache/flight505-marketplace/sdk-bridge/1.9.0/

# Step 3: Restart Claude Code CLI

# Step 4: If still not working, reinstall
/plugin uninstall sdk-bridge@flight505-marketplace
/plugin install sdk-bridge@flight505-marketplace
```

## Clean Uninstall

To completely remove SDK Bridge:

```bash
# Step 1: Uninstall plugin
/plugin uninstall sdk-bridge@flight505-marketplace

# Step 2: Remove harness scripts (optional)
rm -rf ~/.claude/skills/long-running-agent/

# Step 3: Remove project configuration (per project)
rm -f .claude/sdk-bridge.local.md
rm -f .claude/handoff-context.json
rm -f .claude/execution-plan.json
rm -f .claude/sdk-bridge.pid
rm -f .claude/sdk-bridge.log
rm -f .claude/sdk_complete.json

# Step 4: Remove cache
rm -rf ~/.claude/plugins/cache/flight505-marketplace/sdk-bridge/
```

## Directory Structure After Installation

```
~/.claude/
├── plugins/
│   ├── cache/
│   │   └── flight505-marketplace/
│   │       └── sdk-bridge/
│   │           └── 1.9.0/
│   │               ├── .claude-plugin/plugin.json
│   │               ├── commands/ (10 commands)
│   │               ├── agents/ (2 agents)
│   │               ├── skills/ (1 skill)
│   │               ├── hooks/ (hooks.json + scripts)
│   │               └── scripts/ (bundled harness scripts)
│   ├── installed_plugins.json
│   └── known_marketplaces.json
└── skills/
    └── long-running-agent/
        └── harness/
            ├── autonomous_agent.py (v1.4.0)
            ├── hybrid_loop_agent.py (v2.0)
            ├── semantic_memory.py
            ├── model_selector.py
            ├── approval_system.py
            ├── dependency_graph.py
            └── parallel_coordinator.py
```

## Next Steps

After installation, see:
- **README.md** - Feature overview and quick start
- **Quick Start Guide** - Basic workflow
- **/sdk-bridge-patterns** skill - Comprehensive usage guide (2800+ lines)
- **workflow-example.md** - End-to-end TaskFlow app example
- **handoff-scenarios.md** - 10 common scenarios with workflows

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/flight505/sdk-bridge-marketplace
- Issues: https://github.com/flight505/sdk-bridge-marketplace/issues
