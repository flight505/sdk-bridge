# SDK Bridge Plugin - Quick Test Guide

**TL;DR**: Copy-paste these commands to validate your plugin installation and functionality.

---

## 1. Quick Health Check (30 seconds)

Run these three tests to verify basic installation:

```bash
cd /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace

# Test 1: Check all Python scripts installed (expect 7/7)
bash tests/test_installation.sh

# Test 2: Verify SDK works (expect v0.1.18+)
bash tests/test_sdk.sh

# Test 3: Check command structure (expect warning about duplicates)
bash tests/test_command_consolidation.sh
```

**Expected Output**:
```
✅ ALL FILES INSTALLED (7/7)
✅ SDK VALIDATION COMPLETE
⚠️  COMMAND CONSOLIDATION RECOMMENDED
```

---

## 2. Create Test Project (v1.4.0)

Test the v1.4.0 workflow end-to-end:

```bash
# Step 1: Create test project
cd /tmp
mkdir sdk-test-v1
cd sdk-test-v1

# Step 2: Initialize git
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "# Test Project" > README.md
git add README.md
git commit -m "Initial commit"

# Step 3: Create feature_list.json
cat > feature_list.json <<'EOF'
[
  {
    "description": "Create hello.txt file with 'Hello World'",
    "test": "File hello.txt exists with content 'Hello World'",
    "passes": false
  },
  {
    "description": "Create goodbye.txt file with 'Goodbye World'",
    "test": "File goodbye.txt exists with content 'Goodbye World'",
    "passes": false
  }
]
EOF

# Step 4: Create CLAUDE.md
cat > CLAUDE.md <<'EOF'
# Test Project Protocol

When implementing features:
1. Read the feature from feature_list.json
2. Create the exact file mentioned in the description
3. Write the exact content mentioned
4. Say SUCCESS when done

For example:
- "Create hello.txt file with 'Hello World'" means:
  - Create file: hello.txt
  - Content: exactly "Hello World"
EOF

# Step 5: Ready to test
echo ""
echo "✅ Test project ready: $PWD"
echo ""
echo "Next steps:"
echo "  1. Run: /sdk-bridge:init"
echo "  2. Run: /sdk-bridge:handoff"
echo "  3. Wait for completion (check: tail -f .claude/sdk-bridge.log)"
echo "  4. Validate results (see validation commands below)"
```

### Validate Results

After the SDK agent completes:

```bash
# Check if files were actually created
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_file_creation.sh .

# Check if git commits have content
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_git_commits.sh .

# Manual checks
ls -la hello.txt goodbye.txt
cat hello.txt
cat goodbye.txt
git log --oneline
git log -p  # Show file diffs in commits
```

**Expected Results**:
```
✅ VERIFICATION PASSED: All files created
✅ VERIFICATION PASSED: All commits have file changes
```

---

## 3. Create Test Project (v2.0)

Test v2.0 features (dependency graph, parallel planning):

```bash
# Step 1: Create test project
cd /tmp
mkdir sdk-test-v2
cd sdk-test-v2

# Step 2: Initialize git
git init
git config user.email "test@example.com"
git config user.name "Test User"
echo "# v2 Test" > README.md
git add README.md
git commit -m "Initial commit"

# Step 3: Create feature_list.json with dependencies
cat > feature_list.json <<'EOF'
[
  {
    "id": "feat-001",
    "description": "Create config.json with {\"app\": \"test\", \"version\": \"1.0.0\"}",
    "test": "File config.json exists with JSON content",
    "dependencies": [],
    "priority": 10,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Create main.py that imports json and reads config.json",
    "test": "File main.py exists and imports json",
    "dependencies": ["feat-001"],
    "priority": 5,
    "passes": false
  },
  {
    "id": "feat-003",
    "description": "Create utils.py with function def hello(): return 'hello'",
    "test": "File utils.py exists with hello function",
    "dependencies": [],
    "priority": 5,
    "passes": false
  }
]
EOF

# Step 4: Create CLAUDE.md
cat > CLAUDE.md <<'EOF'
# v2 Test Project Protocol

Implement features exactly as described:
- config.json: {"app": "test", "version": "1.0.0"}
- main.py: import json, then open and read config.json
- utils.py: def hello(): return "hello"
EOF

# Step 5: Ready to test
echo ""
echo "✅ v2 Test project ready: $PWD"
echo ""
echo "Next steps:"
echo "  1. Run: /sdk-bridge:init"
echo "  2. Run: /sdk-bridge:plan-v2  (should show dependency graph)"
echo "  3. Run: /sdk-bridge:handoff-v2"
echo "  4. Wait for completion"
echo "  5. Validate results"
```

### Validate v2 Results

```bash
# Check dependency graph was created
cat .claude/feature-graph.json | jq .
cat .claude/execution-plan.json | jq .

# Check files created
ls -la config.json main.py utils.py

# Validate content
cat config.json | jq .
grep "import json" main.py
grep "def hello" utils.py

# Run verification tests
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_file_creation.sh .
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_git_commits.sh .
```

---

## 4. Debugging Failed Tests

### Issue: Files not created

**Symptoms**:
```
❌ VERIFICATION FAILED: 2 files not created
  ❌ FILE MISSING: hello.txt
```

**Debug Steps**:
```bash
# Check SDK logs
tail -100 .claude/sdk-bridge.log

# Check feature_list.json
cat feature_list.json | jq '.[] | select(.passes == true)'

# Check git commits
git log --oneline
git diff HEAD~1  # See what last commit changed

# Check if SDK process is still running
cat .claude/sdk-bridge.pid
ps aux | grep $(cat .claude/sdk-bridge.pid)

# Check for completion signal
cat .claude/sdk_complete.json | jq .
```

**Common Causes**:
1. SDK session didn't actually create files (check logs for errors)
2. Files created but not in expected location
3. Feature marked as "passes: true" prematurely
4. Git commit created without staging files

### Issue: Empty commits

**Symptoms**:
```
❌ VERIFICATION FAILED: 2 empty commits
  Commit abc123: ❌ EMPTY COMMIT (no files changed)
```

**Debug Steps**:
```bash
# See commit details
git log -p

# Check if files exist but weren't committed
git status

# Check SDK's git commands in logs
grep "git add" .claude/sdk-bridge.log
grep "git commit" .claude/sdk-bridge.log
```

**Common Causes**:
1. autonomous_agent.py creates commit before files are staged
2. Files created in wrong directory
3. Git add command failed silently

### Issue: SDK not starting

**Symptoms**:
```
No SDK commits found
.claude/sdk-bridge.pid missing
```

**Debug Steps**:
```bash
# Check if harness exists
ls -la ~/.claude/skills/long-running-agent/harness/autonomous_agent.py

# Try running harness manually
~/.claude/skills/long-running-agent/.venv/bin/python \
  ~/.claude/skills/long-running-agent/harness/autonomous_agent.py \
  --project-dir . \
  --model claude-sonnet-4-5-20250929 \
  --max-iterations 2

# Check API authentication
echo $CLAUDE_CODE_OAUTH_TOKEN
echo $ANTHROPIC_API_KEY
```

---

## 5. Quick Reference

### Test Files Location
```
sdk-bridge-marketplace/
├── tests/
│   ├── test_installation.sh           # ✅ All scripts installed?
│   ├── test_sdk.sh                    # ✅ SDK functional?
│   ├── test_command_consolidation.sh  # ⚠️ Duplicate commands?
│   ├── verify_file_creation.sh        # ✅ Files actually exist?
│   └── verify_git_commits.sh          # ✅ Commits have content?
├── TESTING_STRATEGY.md                # Full testing documentation
├── TEST_RESULTS.md                    # Latest test results
└── QUICK_TEST_GUIDE.md                # This file
```

### One-Liner Test Commands

```bash
# Installation check
bash tests/test_installation.sh && echo "PASS" || echo "FAIL"

# SDK check
bash tests/test_sdk.sh && echo "PASS" || echo "FAIL"

# File verification (run from project directory)
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_file_creation.sh . && echo "PASS" || echo "FAIL"

# Git verification (run from project directory)
bash /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace/tests/verify_git_commits.sh . && echo "PASS" || echo "FAIL"
```

### Test Status Dashboard

Run this to see all test statuses at once:

```bash
cd /Users/jesper/Projects/Dev_projects/Claude_SDK/sdk-bridge-marketplace

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SDK Bridge Plugin - Test Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -n "Installation: "
bash tests/test_installation.sh > /dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL"

echo -n "SDK: "
bash tests/test_sdk.sh > /dev/null 2>&1 && echo "✅ PASS" || echo "❌ FAIL"

echo -n "Commands: "
bash tests/test_command_consolidation.sh > /dev/null 2>&1 && echo "✅ PASS" || echo "⚠️  WARN"

echo ""
echo "Integration tests require manual workflow (see test project setup above)"
```

---

## 6. Success Checklist

After running tests, you should see:

- [x] ✅ All 7 Python scripts installed
- [x] ✅ Claude Agent SDK functional
- [ ] ✅ Only 1 handoff command (after consolidation fix)
- [ ] ✅ Test project files actually created
- [ ] ✅ Git commits contain file changes
- [ ] ✅ v2 dependency graph works
- [ ] ✅ All features marked as complete exist in filesystem

**Current Status**: 2/7 passing (installation tests only)

**Goal**: 7/7 passing before v2.0 release

---

## 7. Common Questions

**Q: How long do test projects take to complete?**
A: v1 test (2 simple features): ~5-10 minutes
   v2 test (3 features with dependencies): ~10-15 minutes

**Q: Can I speed up testing?**
A: Yes, reduce max_sessions in `.claude/sdk-bridge.local.md` to 5 for faster feedback.

**Q: What if tests pass but real project fails?**
A: Test projects are intentionally simple. Real projects may have more complex issues. Add your failing scenario as a new test case.

**Q: Should I run tests before every commit?**
A: Run `test_installation.sh` and `test_command_consolidation.sh` before commits that change plugin structure. Run full integration tests before releases.

---

**Need Help?**
- Full testing strategy: `TESTING_STRATEGY.md`
- Test results: `TEST_RESULTS.md`
- Plugin architecture: `CLAUDE.md`
