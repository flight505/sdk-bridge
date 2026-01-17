# Decomposition Prompt Templates

## Purpose

This file contains the actual prompts used when invoking the decompose-task skill.
Commands use these templates to ensure consistent, high-quality decompositions.

---

## Standard Decomposition Prompt

Use this for general task decomposition:

```
You are decomposing a software development task into executable features for an autonomous agent.

**USER TASK:**
{user_task_description}

**YOUR JOB:**
Generate a valid JSON array of features following this exact schema:

```json
[
  {
    "id": "feat-001",
    "description": "Clear, actionable description (20-150 chars)",
    "test": "Concrete verification criteria",
    "dependencies": [],
    "tags": ["layer", "domain"],
    "priority": 100,
    "passes": false
  }
]
```

**MANDATORY CONSTRAINTS:**

1. **Feature Count:** 5-25 features total
2. **Granularity:** Each feature = 15-30 minutes of work
3. **Architecture:** Follow layers: infrastructure → data → logic → interface → integration
4. **Dependencies:** Must be explicit (use feat-XXX IDs from this list)
5. **Test Criteria:** Must be concrete and verifiable
6. **DRY:** No duplicate functionality across features
7. **YAGNI:** Only decompose what was requested (no extras)

**SCHEMA RULES:**

- `id`: Format "feat-NNN" where NNN is zero-padded (001, 002, ...)
- `description`: Start with action verb, 20-150 chars
- `test`: Concrete verification (CLI output, API response, file check)
- `dependencies`: Array of feat-XXX IDs (empty array if none)
- `tags`: Array of strings (layer + domain)
- `priority`: Integer 0-100 (100 = highest)
- `passes`: Always false initially

**EXAMPLE:**

Input: "Add user login with JWT tokens"

Output:
```json
[
  {
    "id": "feat-001",
    "description": "Install jsonwebtoken and bcrypt npm packages",
    "test": "package.json contains jsonwebtoken@^9.0.0 and bcrypt@^5.0.0",
    "dependencies": [],
    "tags": ["infrastructure", "dependencies"],
    "priority": 100,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Create POST /api/auth/login endpoint handler",
    "test": "POST /api/auth/login returns 404 (not implemented yet)",
    "dependencies": ["feat-001"],
    "tags": ["api", "auth"],
    "priority": 90,
    "passes": false
  },
  {
    "id": "feat-003",
    "description": "Implement JWT token generation on valid credentials",
    "test": "Valid login returns 200 with {token: string} in response body",
    "dependencies": ["feat-002"],
    "tags": ["auth", "security"],
    "priority": 85,
    "passes": false
  },
  {
    "id": "feat-004",
    "description": "Add bcrypt password verification in login handler",
    "test": "Invalid password returns 401 Unauthorized",
    "dependencies": ["feat-002"],
    "tags": ["auth", "security"],
    "priority": 85,
    "passes": false
  }
]
```

**NOW DECOMPOSE THE TASK ABOVE INTO VALID JSON.**

Output ONLY the JSON array, no additional text.
```

---

## Usage in Commands

Commands should invoke this prompt template like:

```bash
# Read template
PROMPT_TEMPLATE=$(cat "${CLAUDE_PLUGIN_ROOT}/skills/decompose-task/references/prompt-templates.md")

# Extract standard prompt section (between first two ```)
DECOMP_PROMPT=$(echo "$PROMPT_TEMPLATE" | sed -n '/^```$/,/^```$/p' | sed '1d;$d')

# Substitute user input
USER_TASK="Build a todo list API"
FULL_PROMPT="${DECOMP_PROMPT//\{user_task_description\}/$USER_TASK}"

# Save for LLM invocation
echo "$FULL_PROMPT" > .claude/decomposition-prompt.txt

# Invoke decompose-task skill with Skill tool
# Skill will read .claude/decomposition-prompt.txt and generate .claude/proposed-features.json
```

---

## Advanced Prompts (Future)

### Refinement Prompt

Use when user wants to refine existing decomposition:

```
CURRENT DECOMPOSITION:
{current_features_json}

USER FEEDBACK:
{user_refinement_request}

Modify the decomposition to address the feedback while maintaining:
- Valid schema
- Dependency integrity
- DRY/YAGNI principles

Output updated JSON array.
```

### Add Features Prompt

Use when user wants to add to existing decomposition:

```
EXISTING FEATURES:
{current_features_json}

NEW REQUIREMENTS:
{additional_features_request}

Add new features to the list that:
- Don't duplicate existing functionality
- Correctly depend on existing features where needed
- Follow same naming/priority pattern
- Maintain topological order

Output complete JSON array (existing + new).
```
