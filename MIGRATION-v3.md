# Migration Guide: v2.x → v3.0.0

## Breaking Changes

SDK Bridge v3.0.0 removes all deprecated v1.x commands.

### Removed Commands

| Deprecated Command | v3.0.0 Replacement | Notes |
|-------------------|-------------------|-------|
| `/sdk-bridge:init` | `/sdk-bridge:start` | Interactive setup with auto-launch |
| `/sdk-bridge:handoff` | `/sdk-bridge:start` | Now part of start command |
| `/sdk-bridge:lra-setup` | Automatic | Auto-installs during start |

### Migration Steps

1. **Stop using deprecated commands immediately**
   - Replace `/sdk-bridge:init` + `/sdk-bridge:handoff` with `/sdk-bridge:start`
   - Remove `/sdk-bridge:lra-setup` from scripts (now automatic)

2. **Update automation/scripts**
   - If using init in CI/CD: See "Non-Interactive Usage" below
   - If using handoff: Remove and rely on start's auto-launch

3. **Test with v2.2.3+ before upgrading to v3.0.0**
   - Deprecation warnings will guide you
   - Verify your workflow works with /start

### Non-Interactive Usage (CI/CD)

For non-interactive environments, create config file manually:

```bash
# Create .claude/sdk-bridge.local.md with your settings
cat > .claude/sdk-bridge.local.md << 'EOF'
---
enabled: true
model: claude-sonnet-4-5-20250929
max_sessions: 20
---
EOF

# Then run start (will detect existing config and skip UI)
/sdk-bridge:start
```

### Timeline

- **v2.2.3** (2026-01-17): Deprecation warnings added
- **v2.4.0** (2026-02-28): Hard redirects (cannot use deprecated commands)
- **v2.5.0** (2026-03-31): Final warning before removal
- **v3.0.0** (2026-05-01): Deprecated commands removed

### Need Help?

- Issues: https://github.com/flight505/sdk-bridge/issues
- Documentation: See SKILL.md for full v2.0 workflow
