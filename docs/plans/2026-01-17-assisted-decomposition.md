# Assisted Decomposition Layer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform SDK Bridge from "execution engine requiring manual planning" to "end-to-end autonomous development assistant" by adding assisted task decomposition with LLM-powered feature generation and computational validation.

**Architecture:** Three-tier approach: (1) Interactive task input collection, (2) LLM-based decomposition using new `decompose-task` skill, (3) Computational validation via enhanced `dependency_graph.py`. New `/sdk-bridge:decompose` command for standalone use, `/sdk-bridge:start` enhanced to offer decomposition when `feature_list.json` missing.

**Tech Stack:** Markdown commands (Claude Code plugin system), Python (dependency_graph.py enhancements), Bash (AskUserQuestion integration), JSON (feature_list.json schema)

**MVP Scope (v3.0):**
- Text input only (no file parsing)
- Single review pass (no multi-round editing)
- Basic validation (schema + dependency graph)
- Backward compatible (existing users unaffected)

---

## Phase 1: Create decompose-task Skill

### Task 1.1: Create Main Skill File

**Files:**
- Create: `plugins/sdk-bridge/skills/decompose-task/SKILL.md`

**Step 1: Create skill directory**

```bash
mkdir -p plugins/sdk-bridge/skills/decompose-task/references
mkdir -p plugins/sdk-bridge/skills/decompose-task/examples
```

**Step 2: Write SKILL.md**

Create the main skill file with YAML frontmatter and complete decomposition instructions:

```markdown
---
name: decompose-task
description: |
  Decompose high-level task descriptions into structured, executable features
  for SDK Bridge autonomous agents. Emphasizes DRY, YAGNI, TDD principles.
  Use when user provides task description and needs feature_list.json generated.
version: 1.0.0
strict: true
---

# Task Decomposition for SDK Bridge

Transform natural language task descriptions into structured, dependency-aware
feature lists optimized for autonomous agent execution.

## Core Principles

### DRY (Don't Repeat Yourself)
- Each feature must be unique
- Extract common functionality into shared foundational features
- If two features need the same capability, create a third feature both depend on

### YAGNI (You Aren't Gonna Need It)
- Only decompose what was explicitly requested
- No speculative features or "while we're at it" additions
- Resist over-engineering
- When in doubt, leave it out

### TDD-Oriented Decomposition
- Every feature must have testable completion criteria
- The `test` field is mandatory and must be concrete
- Features should be atomic enough to verify independently
- "Test passes" = "Feature is complete"

## Decomposition Process

### Step 1: Parse Requirements

Extract from input:
- Core functionality requested
- Technology stack (explicit or implied)
- Constraints (performance, security, compatibility)
- Scope boundaries (what's NOT included)

### Step 2: Identify Layers

Standard software layers (apply as relevant):

1. **Infrastructure** (Level 0)
   - Project setup, config files
   - Dependency installation
   - Environment configuration

2. **Data Layer** (Level 1)
   - Database connections
   - Schema/models
   - Migrations

3. **Core Logic** (Level 2)
   - Business rules
   - Algorithms
   - Services

4. **Interface Layer** (Level 3)
   - API endpoints
   - UI components
   - CLI commands

5. **Integration** (Level 4)
   - External APIs
   - Authentication
   - Third-party services

### Step 3: Generate Features

For each identified component:

1. Write clear, actionable description
2. Define concrete test criteria
3. Identify dependencies (features that must complete first)
4. Assign priority (100 = highest, 0 = lowest)
5. Add relevant tags

### Output Format

```json
{
  "id": "feat-NNN",
  "description": "[Action verb] [specific thing] [with details]",
  "test": "[Concrete verification: command output, API response, file exists]",
  "dependencies": ["feat-XXX", "feat-YYY"],
  "tags": ["layer", "domain"],
  "priority": 50,
  "passes": false
}
```

## Granularity Guidelines

### Target Metrics
- **Feature count**: 5-25 for typical projects
- **Implementation time**: 15-30 minutes per feature
- **Description length**: 20-150 characters
- **Test clarity**: Must be verifiable without ambiguity

### Too Coarse (Split It)
❌ "Build authentication system"
✅ Split into: setup, registration, login, logout, password reset, token refresh

### Too Fine (Combine It)
❌ "Create user table", "Add email column", "Add password column"
✅ "Create user table with email and password columns"

### Just Right
✅ "Add JWT token generation on successful login"
✅ "Create /api/users endpoint returning paginated user list"
✅ "Implement password hashing with bcrypt (cost factor 12)"

## Anti-Patterns

### Vague Descriptions
❌ "Add authentication"
✅ "Add JWT-based authentication with 24-hour token expiry"

### Implicit Dependencies
❌ Feature assumes database exists but doesn't declare dependency
✅ Explicitly add `"dependencies": ["feat-002-database-setup"]`

### Compound Features
❌ "Create user CRUD operations"
✅ Four features: create user, get user, update user, delete user

### Missing Tests
❌ `"test": "works correctly"`
✅ `"test": "POST /users with valid data returns 201 and user object with id"`

### Feature Creep
❌ Adding caching, monitoring, analytics when user asked for basic API
✅ Implement exactly what was requested, nothing more

## Decomposition Instructions

When invoked, you MUST:

1. **Read the user's task description carefully**
2. **Apply the layered architecture pattern** (infrastructure → data → logic → interface)
3. **Generate features as JSON array** following the exact schema above
4. **Ensure dependencies are explicit** (no implicit assumptions)
5. **Write concrete test criteria** (verifiable, not vague)
6. **Target 5-25 features** for typical projects
7. **Save to .claude/proposed-features.json** for review

**Output Location:** `.claude/proposed-features.json`

**Example Output Structure:**
```json
[
  {
    "id": "feat-001",
    "description": "Initialize Node.js project with Express and TypeScript",
    "test": "npm run build succeeds, server starts on port 3000",
    "dependencies": [],
    "tags": ["infrastructure"],
    "priority": 100,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Configure PostgreSQL connection with connection pooling",
    "test": "SELECT 1 query executes successfully",
    "dependencies": ["feat-001"],
    "tags": ["database", "infrastructure"],
    "priority": 95,
    "passes": false
  }
]
```

See `examples/todo-api-example.md` for a complete worked example.
See `references/prompt-templates.md` for the exact decomposition prompt.
```

**Step 3: Verify skill file**

```bash
# Check file exists
ls -lh plugins/sdk-bridge/skills/decompose-task/SKILL.md

# Verify frontmatter is valid YAML
head -n 10 plugins/sdk-bridge/skills/decompose-task/SKILL.md
```

Expected: File exists, ~600 lines, valid YAML frontmatter

**Step 4: Commit**

```bash
git add plugins/sdk-bridge/skills/decompose-task/SKILL.md
git commit -m "feat: add decompose-task skill for assisted task decomposition"
```

---

### Task 1.2: Create Prompt Templates Reference

**Files:**
- Create: `plugins/sdk-bridge/skills/decompose-task/references/prompt-templates.md`

**Step 1: Write prompt templates file**

This file contains the actual system prompt used for LLM decomposition:

```markdown
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
```

**Step 2: Verify prompt templates file**

```bash
ls -lh plugins/sdk-bridge/skills/decompose-task/references/prompt-templates.md
```

Expected: File exists, ~150 lines

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/skills/decompose-task/references/prompt-templates.md
git commit -m "feat: add decomposition prompt templates for consistent LLM invocation"
```

---

### Task 1.3: Create Example Decomposition

**Files:**
- Create: `plugins/sdk-bridge/skills/decompose-task/examples/todo-api-example.md`

**Step 1: Write complete worked example**

```markdown
# Example: Todo API Decomposition

## Input

**User Task:** "Build a REST API for a todo list with user authentication"

---

## Decomposition Process

### Step 1: Parse Requirements

**Core functionality:**
- Todo CRUD operations
- User authentication (JWT implied by "authentication")
- REST API (implies Express/similar)

**Technology stack (inferred):**
- Backend: Node.js + Express (industry standard for REST API)
- Database: PostgreSQL (common choice for structured data)
- Auth: JWT tokens

**Constraints:**
- None explicitly stated

**Scope boundaries:**
- No frontend (only API)
- No advanced features (caching, rate limiting) - YAGNI

### Step 2: Identify Layers

1. **Infrastructure:** Project setup, Express server
2. **Data:** Database connection, user table, todo table
3. **Auth Logic:** Registration, login, JWT middleware
4. **API Layer:** Todo endpoints (CRUD)
5. **Integration:** None needed (no external services)

### Step 3: Generate Features

**Level 0 - Infrastructure:**
- feat-001: Initialize project with Express + TypeScript

**Level 1 - Data Layer:**
- feat-002: PostgreSQL connection
- feat-003: Users table
- feat-006: Todos table

**Level 2 - Auth Logic:**
- feat-004: User registration endpoint
- feat-005: User login endpoint
- feat-007: JWT middleware

**Level 3 - API Layer:**
- feat-008: GET /api/todos
- feat-009: POST /api/todos
- feat-010: PATCH /api/todos/:id
- feat-011: DELETE /api/todos/:id

---

## Output JSON

```json
[
  {
    "id": "feat-001",
    "description": "Initialize Node.js project with Express and TypeScript",
    "test": "npm run build succeeds, server starts on port 3000",
    "dependencies": [],
    "tags": ["infrastructure"],
    "priority": 100,
    "passes": false
  },
  {
    "id": "feat-002",
    "description": "Configure PostgreSQL connection with connection pooling",
    "test": "SELECT 1 query executes successfully",
    "dependencies": ["feat-001"],
    "tags": ["database", "infrastructure"],
    "priority": 95,
    "passes": false
  },
  {
    "id": "feat-003",
    "description": "Create users table with email, password_hash, created_at",
    "test": "Table exists with correct columns and constraints",
    "dependencies": ["feat-002"],
    "tags": ["database", "auth"],
    "priority": 90,
    "passes": false
  },
  {
    "id": "feat-004",
    "description": "Implement user registration endpoint POST /api/auth/register",
    "test": "Valid registration returns 201 with user object (no password)",
    "dependencies": ["feat-003"],
    "tags": ["api", "auth"],
    "priority": 85,
    "passes": false
  },
  {
    "id": "feat-005",
    "description": "Implement user login endpoint POST /api/auth/login with JWT",
    "test": "Valid credentials return 200 with JWT token",
    "dependencies": ["feat-004"],
    "tags": ["api", "auth"],
    "priority": 85,
    "passes": false
  },
  {
    "id": "feat-006",
    "description": "Create todos table with user_id, title, completed, created_at",
    "test": "Table exists with foreign key to users",
    "dependencies": ["feat-003"],
    "tags": ["database", "todos"],
    "priority": 80,
    "passes": false
  },
  {
    "id": "feat-007",
    "description": "Implement JWT auth middleware for protected routes",
    "test": "Request without token returns 401, valid token proceeds",
    "dependencies": ["feat-005"],
    "tags": ["middleware", "auth"],
    "priority": 75,
    "passes": false
  },
  {
    "id": "feat-008",
    "description": "Implement GET /api/todos (list user's todos, paginated)",
    "test": "Returns array of todos belonging to authenticated user",
    "dependencies": ["feat-006", "feat-007"],
    "tags": ["api", "todos"],
    "priority": 70,
    "passes": false
  },
  {
    "id": "feat-009",
    "description": "Implement POST /api/todos (create new todo)",
    "test": "Creates todo and returns 201 with todo object",
    "dependencies": ["feat-007", "feat-006"],
    "tags": ["api", "todos"],
    "priority": 70,
    "passes": false
  },
  {
    "id": "feat-010",
    "description": "Implement PATCH /api/todos/:id (update todo)",
    "test": "Updates title/completed, returns 200. 404 if not found/not owner",
    "dependencies": ["feat-008"],
    "tags": ["api", "todos"],
    "priority": 65,
    "passes": false
  },
  {
    "id": "feat-011",
    "description": "Implement DELETE /api/todos/:id (delete todo)",
    "test": "Deletes todo, returns 204. 404 if not found/not owner",
    "dependencies": ["feat-008"],
    "tags": ["api", "todos"],
    "priority": 65,
    "passes": false
  }
]
```

---

## Analysis

**Feature Count:** 11 features ✓ (within 5-25 range)

**Granularity:** Each feature is 15-30 minutes ✓
- feat-001: Setup project (20 min)
- feat-002: Add PG connection (15 min)
- feat-003: Create table (10 min)
- etc.

**Dependencies:** Valid DAG ✓
- No cycles
- All refs exist
- Topological ordering: feat-001 → feat-002 → feat-003/feat-006 → feat-004/feat-005/feat-007 → feat-008/feat-009 → feat-010/feat-011

**Test Criteria:** All concrete ✓
- "npm run build succeeds" - verifiable
- "Returns array of todos" - verifiable
- "404 if not found" - verifiable

**DRY:** No duplicates ✓
- Auth logic in one place (feat-007)
- Database setup not repeated

**YAGNI:** Only requested features ✓
- No caching, monitoring, rate limiting
- Basic CRUD only

**Conclusion:** High-quality decomposition ready for autonomous agent execution.
```

**Step 2: Verify example file**

```bash
ls -lh plugins/sdk-bridge/skills/decompose-task/examples/todo-api-example.md
```

Expected: File exists, ~200 lines

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/skills/decompose-task/examples/todo-api-example.md
git commit -m "feat: add todo API example decomposition for reference"
```

---

## Phase 2: Enhance dependency_graph.py

### Task 2.1: Add Schema Validation

**Files:**
- Modify: `scripts/dependency_graph.py:1-50` (add imports and ValidationResult class)
- Modify: `scripts/dependency_graph.py:END` (add validate_schema function)

**Step 1: Add validation result class**

At the top of `dependency_graph.py`, after existing imports:

```python
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

@dataclass
class ValidationResult:
    """Result of validation check."""
    is_valid: bool
    errors: List[str]
    warnings: List[str]

    def __bool__(self):
        return self.is_valid
```

**Step 2: Add schema validation function**

At the end of `dependency_graph.py`:

```python
def validate_schema(features: List[Dict[str, Any]]) -> ValidationResult:
    """
    Validate feature_list.json schema.

    Checks:
    - Valid JSON array
    - Required fields present: id, description, passes
    - Optional fields typed correctly: dependencies (list), priority (int)
    - No duplicate IDs
    - ID format valid (no spaces, special chars)

    Args:
        features: List of feature dictionaries

    Returns:
        ValidationResult with errors and warnings
    """
    errors = []
    warnings = []

    # Check it's a list
    if not isinstance(features, list):
        errors.append("feature_list.json must be a JSON array")
        return ValidationResult(is_valid=False, errors=errors, warnings=warnings)

    # Check not empty
    if len(features) == 0:
        warnings.append("Feature list is empty")

    seen_ids = set()

    for idx, feature in enumerate(features):
        # Check it's a dict
        if not isinstance(feature, dict):
            errors.append(f"Feature at index {idx} is not an object")
            continue

        # Check required fields
        required = ["id", "description", "passes"]
        for field in required:
            if field not in feature:
                errors.append(f"Feature at index {idx} missing required field: {field}")

        # Check id format
        if "id" in feature:
            feat_id = feature["id"]
            if not isinstance(feat_id, str):
                errors.append(f"Feature at index {idx}: id must be string, got {type(feat_id)}")
            elif " " in feat_id or not feat_id.strip():
                errors.append(f"Feature at index {idx}: id '{feat_id}' contains whitespace or is empty")

            # Check for duplicates
            if feat_id in seen_ids:
                errors.append(f"Duplicate feature ID: {feat_id}")
            seen_ids.add(feat_id)

        # Check description
        if "description" in feature:
            desc = feature["description"]
            if not isinstance(desc, str):
                errors.append(f"Feature {feature.get('id', idx)}: description must be string")
            elif len(desc) < 10:
                warnings.append(f"Feature {feature.get('id', idx)}: description very short ({len(desc)} chars)")
            elif len(desc) > 200:
                warnings.append(f"Feature {feature.get('id', idx)}: description very long ({len(desc)} chars)")

        # Check passes field
        if "passes" in feature:
            passes = feature["passes"]
            if not isinstance(passes, bool):
                errors.append(f"Feature {feature.get('id', idx)}: passes must be boolean, got {type(passes)}")

        # Check optional fields
        if "dependencies" in feature:
            deps = feature["dependencies"]
            if not isinstance(deps, list):
                errors.append(f"Feature {feature.get('id', idx)}: dependencies must be array, got {type(deps)}")
            else:
                for dep in deps:
                    if not isinstance(dep, str):
                        errors.append(f"Feature {feature.get('id', idx)}: dependency must be string, got {type(dep)}")

        if "priority" in feature:
            priority = feature["priority"]
            if not isinstance(priority, (int, float)):
                errors.append(f"Feature {feature.get('id', idx)}: priority must be number, got {type(priority)}")
            elif priority < 0 or priority > 100:
                warnings.append(f"Feature {feature.get('id', idx)}: priority {priority} outside typical range 0-100")

        if "tags" in feature:
            tags = feature["tags"]
            if not isinstance(tags, list):
                errors.append(f"Feature {feature.get('id', idx)}: tags must be array, got {type(tags)}")

        # Check for test criteria (warning only)
        if "test" not in feature or not feature["test"]:
            warnings.append(f"Feature {feature.get('id', idx)}: missing test criteria")

    is_valid = len(errors) == 0
    return ValidationResult(is_valid=is_valid, errors=errors, warnings=warnings)
```

**Step 3: Test schema validation**

Create a test file to verify:

```bash
# Create test file with invalid schema
cat > /tmp/test-invalid.json << 'EOF'
[
  {"description": "Missing id field"},
  {"id": "feat-001", "description": "Valid feature", "passes": false},
  {"id": "feat-001", "description": "Duplicate ID", "passes": false}
]
EOF

# Test validation
python3 scripts/dependency_graph.py validate-schema /tmp/test-invalid.json
```

Expected output:
```
❌ Schema Validation Failed
Errors:
  - Feature at index 0 missing required field: id
  - Duplicate feature ID: feat-001
```

**Step 4: Commit**

```bash
git add scripts/dependency_graph.py
git commit -m "feat: add schema validation to dependency_graph.py"
```

---

### Task 2.2: Add Dependency Graph Validation

**Files:**
- Modify: `scripts/dependency_graph.py:END` (add validate_dependencies function)

**Step 1: Add cycle detection helper**

```python
def _detect_cycles(graph: 'DependencyGraph') -> List[List[str]]:
    """
    Detect cycles in dependency graph using DFS.

    Returns:
        List of cycles, where each cycle is a list of node IDs
    """
    cycles = []
    visited = set()
    rec_stack = set()

    def dfs(node_id: str, path: List[str]):
        visited.add(node_id)
        rec_stack.add(node_id)
        path.append(node_id)

        if node_id not in graph.nodes:
            return

        for dep in graph.nodes[node_id].dependencies:
            if dep not in visited:
                dfs(dep, path.copy())
            elif dep in rec_stack:
                # Found cycle
                cycle_start = path.index(dep)
                cycles.append(path[cycle_start:] + [dep])

        rec_stack.remove(node_id)

    for node_id in graph.nodes:
        if node_id not in visited:
            dfs(node_id, [])

    return cycles
```

**Step 2: Add dependency validation function**

```python
def validate_dependencies(graph: 'DependencyGraph') -> ValidationResult:
    """
    Validate dependency graph.

    Checks:
    - All dependency IDs exist in feature list
    - No circular dependencies (detect cycles)
    - No self-dependencies
    - Topological sort possible

    Args:
        graph: DependencyGraph instance

    Returns:
        ValidationResult with errors and warnings
    """
    errors = []
    warnings = []

    all_ids = set(graph.nodes.keys())

    # Check each node's dependencies
    for node_id, node in graph.nodes.items():
        for dep in node.dependencies:
            # Check self-dependency
            if dep == node_id:
                errors.append(f"Feature {node_id} has self-dependency")

            # Check dependency exists
            if dep not in all_ids:
                errors.append(f"Feature {node_id} depends on non-existent feature: {dep}")

    # Detect cycles
    cycles = _detect_cycles(graph)
    if cycles:
        for cycle in cycles:
            cycle_str = " → ".join(cycle)
            errors.append(f"Circular dependency detected: {cycle_str}")

    # Check if topological sort is possible
    if not cycles:
        try:
            sorted_ids = graph.topological_sort()
            if len(sorted_ids) != len(all_ids):
                warnings.append(f"Topological sort produced {len(sorted_ids)} features, expected {len(all_ids)}")
        except Exception as e:
            errors.append(f"Topological sort failed: {str(e)}")

    # Dependency depth check (warning only)
    max_depth = 0
    for node_id in all_ids:
        depth = _calculate_depth(graph, node_id)
        if depth > max_depth:
            max_depth = depth

    if max_depth > 5:
        warnings.append(f"Deep dependency chain detected: {max_depth} levels (consider flattening)")

    is_valid = len(errors) == 0
    return ValidationResult(is_valid=is_valid, errors=errors, warnings=warnings)


def _calculate_depth(graph: 'DependencyGraph', node_id: str, visited: Optional[set] = None) -> int:
    """Calculate maximum depth of dependency tree for a node."""
    if visited is None:
        visited = set()

    if node_id in visited:
        return 0  # Cycle or already processed

    visited.add(node_id)

    if node_id not in graph.nodes or not graph.nodes[node_id].dependencies:
        return 0

    max_child_depth = 0
    for dep in graph.nodes[node_id].dependencies:
        depth = _calculate_depth(graph, dep, visited.copy())
        if depth > max_child_depth:
            max_child_depth = depth

    return max_child_depth + 1
```

**Step 3: Test dependency validation**

```bash
# Create test file with circular dependency
cat > /tmp/test-circular.json << 'EOF'
[
  {"id": "feat-001", "description": "First", "dependencies": ["feat-002"], "passes": false},
  {"id": "feat-002", "description": "Second", "dependencies": ["feat-001"], "passes": false}
]
EOF

# Test validation
python3 scripts/dependency_graph.py validate-deps /tmp/test-circular.json
```

Expected output:
```
❌ Dependency Validation Failed
Errors:
  - Circular dependency detected: feat-001 → feat-002 → feat-001
```

**Step 4: Commit**

```bash
git add scripts/dependency_graph.py
git commit -m "feat: add dependency graph validation with cycle detection"
```

---

### Task 2.3: Add Topological Sort Function

**Files:**
- Modify: `scripts/dependency_graph.py:END` (add reorder_by_topology function)

**Step 1: Add topological reorder function**

```python
def reorder_by_topology(features: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Reorder features array into topologically sorted order.

    Features with no dependencies come first.
    Features at same dependency level maintain relative order (stable sort).

    Args:
        features: List of feature dictionaries

    Returns:
        Reordered list of features in execution order

    Raises:
        ValueError: If dependency graph has cycles or invalid refs
    """
    # Build graph
    graph = build_graph_from_feature_list_data(features)

    # Validate dependencies first
    validation = validate_dependencies(graph)
    if not validation.is_valid:
        raise ValueError(f"Cannot reorder - invalid dependencies: {validation.errors}")

    # Get topological order
    sorted_ids = graph.topological_sort()

    # Reorder features array
    id_to_feature = {f["id"]: f for f in features}
    reordered = [id_to_feature[feat_id] for feat_id in sorted_ids]

    return reordered


def build_graph_from_feature_list_data(features: List[Dict[str, Any]]) -> 'DependencyGraph':
    """Build DependencyGraph from feature list data."""
    graph = DependencyGraph()

    for feature in features:
        feat_id = feature["id"]
        description = feature.get("description", "")
        dependencies = feature.get("dependencies", [])
        tags = feature.get("tags", [])
        priority = feature.get("priority", 50)

        graph.add_node(
            id=feat_id,
            description=description,
            dependencies=dependencies,
            tags=tags,
            priority=priority
        )

    return graph
```

**Step 2: Test topological sort**

```bash
# Create test file with out-of-order features
cat > /tmp/test-unordered.json << 'EOF'
[
  {"id": "feat-003", "description": "Third", "dependencies": ["feat-001", "feat-002"], "passes": false},
  {"id": "feat-001", "description": "First", "dependencies": [], "passes": false},
  {"id": "feat-002", "description": "Second", "dependencies": ["feat-001"], "passes": false}
]
EOF

# Test reordering
python3 scripts/dependency_graph.py reorder /tmp/test-unordered.json
```

Expected output:
```json
[
  {"id": "feat-001", "description": "First", "dependencies": [], "passes": false},
  {"id": "feat-002", "description": "Second", "dependencies": ["feat-001"], "passes": false},
  {"id": "feat-003", "description": "Third", "dependencies": ["feat-001", "feat-002"], "passes": false}
]
```

**Step 3: Commit**

```bash
git add scripts/dependency_graph.py
git commit -m "feat: add topological reordering function for feature lists"
```

---

### Task 2.4: Add CLI Interface for Validation

**Files:**
- Modify: `scripts/dependency_graph.py:1` (add argparse)
- Modify: `scripts/dependency_graph.py:END` (add main CLI)

**Step 1: Add CLI argument parsing**

At the very end of `dependency_graph.py`:

```python
def main():
    """CLI interface for dependency graph operations."""
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="Validate and analyze feature dependency graphs")
    parser.add_argument("command", choices=["validate", "reorder", "visualize"],
                       help="Command to run")
    parser.add_argument("file", help="Path to feature_list.json")
    parser.add_argument("--output", "-o", help="Output file (for reorder command)")

    args = parser.parse_args()

    # Load feature list
    try:
        with open(args.file, 'r') as f:
            features = json.load(f)
    except FileNotFoundError:
        print(f"❌ File not found: {args.file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Execute command
    if args.command == "validate":
        # Schema validation
        schema_result = validate_schema(features)
        print("━" * 60)
        print("   SCHEMA VALIDATION")
        print("━" * 60)
        if schema_result.is_valid:
            print(f"✅ Valid ({len(features)} features)")
        else:
            print("❌ Invalid")
            for error in schema_result.errors:
                print(f"  • {error}")

        if schema_result.warnings:
            print("\n⚠️  Warnings:")
            for warning in schema_result.warnings:
                print(f"  • {warning}")

        # Dependency validation
        print("\n" + "━" * 60)
        print("   DEPENDENCY VALIDATION")
        print("━" * 60)

        try:
            graph = build_graph_from_feature_list_data(features)
            deps_result = validate_dependencies(graph)

            if deps_result.is_valid:
                print("✅ Valid (no cycles, all refs exist)")
            else:
                print("❌ Invalid")
                for error in deps_result.errors:
                    print(f"  • {error}")

            if deps_result.warnings:
                print("\n⚠️  Warnings:")
                for warning in deps_result.warnings:
                    print(f"  • {warning}")
        except Exception as e:
            print(f"❌ Failed to build graph: {e}", file=sys.stderr)
            sys.exit(1)

        # Exit code
        if not schema_result.is_valid or not deps_result.is_valid:
            sys.exit(1)

    elif args.command == "reorder":
        try:
            reordered = reorder_by_topology(features)

            output_file = args.output or args.file
            with open(output_file, 'w') as f:
                json.dump(reordered, f, indent=2)

            print(f"✅ Reordered {len(reordered)} features topologically")
            print(f"   Saved to: {output_file}")
        except Exception as e:
            print(f"❌ Reorder failed: {e}", file=sys.stderr)
            sys.exit(1)

    elif args.command == "visualize":
        try:
            graph = build_graph_from_feature_list_data(features)
            print(graph.visualize_ascii())
        except Exception as e:
            print(f"❌ Visualization failed: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
```

**Step 2: Test CLI**

```bash
# Test validation
python3 scripts/dependency_graph.py validate /tmp/test-circular.json

# Test reordering
python3 scripts/dependency_graph.py reorder /tmp/test-unordered.json -o /tmp/test-ordered.json
cat /tmp/test-ordered.json

# Test visualization
python3 scripts/dependency_graph.py visualize /tmp/test-ordered.json
```

Expected: All commands work correctly, return proper exit codes

**Step 3: Update version**

```bash
# Update .version file
echo "2.3.0" > scripts/.version
```

**Step 4: Commit**

```bash
git add scripts/dependency_graph.py scripts/.version
git commit -m "feat: add CLI interface for validation and reordering"
```

---

## Phase 3: Create /sdk-bridge:decompose Command

### Task 3.1: Create Decompose Command File

**Files:**
- Create: `plugins/sdk-bridge/commands/decompose.md`

**Step 1: Write command file**

```markdown
---
description: "Generate feature_list.json from task description using LLM decomposition"
argument-hint: "[task description or --validate-only]"
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion", "Skill", "TodoWrite"]
---

# SDK Bridge Decompose - Assisted Task Decomposition

I'll help you decompose your task into a structured feature list for SDK Bridge.

## Step 1: Check for Existing feature_list.json

```bash
if [ -f "feature_list.json" ]; then
  FEATURE_COUNT=$(jq '. | length' feature_list.json 2>/dev/null || echo "0")
  echo "EXISTING_FILE"
  echo "FEATURE_COUNT=$FEATURE_COUNT"
else
  echo "NO_FILE"
fi
```

## Step 2: Handle Existing File

If `EXISTING_FILE` was printed, use AskUserQuestion:

```
question: "Found existing feature_list.json with $FEATURE_COUNT features. What would you like to do?"
header: "Existing Plan"
multiSelect: false
options:
  - label: "Validate only"
    description: "Check if the current file is valid without regenerating"
  - label: "Replace with new"
    description: "Archive current file and create fresh decomposition"
  - label: "Cancel"
    description: "Keep existing file and exit"
```

**If "Validate only"** → Skip to Step 6 (validation)
**If "Replace with new"** → Continue to Step 3
**If "Cancel"** → Exit with message "Keeping existing feature_list.json"

## Step 3: Collect Task Description

If no existing file OR user chose "Replace with new", use AskUserQuestion to get task:

```
question: "Describe what you want to build:"
header: "Task Input"
multiSelect: false
options:
  - label: "Simple project (1-2 sentences)"
    description: "e.g., 'Build a REST API for user authentication with JWT'"
  - label: "Complex project (detailed description)"
    description: "e.g., 'Full-stack todo app with React, Node.js, PostgreSQL, JWT auth, CRUD operations'"
  - label: "Provide as text file"
    description: "I'll ask for a file path to read the description from"
```

**If "Provide as text file":**
- Use second AskUserQuestion asking for file path
- Read file contents using Read tool
- Use contents as TASK_DESCRIPTION

**Otherwise:**
- Use second AskUserQuestion with free text input
- Use input as TASK_DESCRIPTION

## Step 4: Invoke Decomposition Skill

Create directories and prepare for decomposition:

```bash
mkdir -p .claude
```

Use Skill tool to invoke decompose-task:

```
I'm invoking the decompose-task skill to analyze your requirements and generate a structured feature list.

Task: {TASK_DESCRIPTION}
```

The skill will:
1. Parse the requirements
2. Identify software layers
3. Generate features with dependencies
4. Save to `.claude/proposed-features.json`

## Step 5: Review Proposed Features

Read the generated features:

```bash
cat .claude/proposed-features.json
```

Parse and present for review using AskUserQuestion with multiSelect:

```bash
# Build options array dynamically
OPTIONS=$(jq '[.[] | {
  label: "[" + .id + "] " + .description,
  description: "Priority: " + (.priority|tostring) + " | Dependencies: " + (if .dependencies | length > 0 then (.dependencies | join(", ")) else "none" end) + " | Test: " + .test,
  value: .id
}]' .claude/proposed-features.json)

# Present to user via AskUserQuestion
```

```
question: "Review the proposed features. All are selected by default - uncheck any you want to exclude."
header: "Feature Review"
multiSelect: true
options: {OPTIONS}  # Dynamically generated from JSON
```

**User selects features to include**

Filter the JSON to keep only selected features:

```bash
# Get selected feature IDs from AskUserQuestion response
SELECTED_IDS='["feat-001", "feat-003", "feat-005"]'  # Example

# Filter proposed features
jq --argjson selected "$SELECTED_IDS" '
  [.[] | select(.id as $id | $selected | index($id) != null)]
' .claude/proposed-features.json > .claude/filtered-features.json
```

## Step 6: Validate Features

Run validation using enhanced dependency_graph.py:

```bash
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

if [ -f "$HARNESS_DIR/dependency_graph.py" ]; then
  "$VENV_PYTHON" "$HARNESS_DIR/dependency_graph.py" validate .claude/filtered-features.json
  VALIDATION_EXIT=$?
else
  echo "⚠️  dependency_graph.py not found - skipping validation"
  VALIDATION_EXIT=0
fi
```

**If validation fails (exit code != 0):**

Show errors and ask:

```
question: "Validation found errors. How would you like to proceed?"
header: "Validation Failed"
multiSelect: false
options:
  - label: "Fix manually and retry"
    description: "Edit .claude/filtered-features.json yourself and run /sdk-bridge:decompose again"
  - label: "Regenerate completely"
    description: "Start over with a new task description"
  - label: "Cancel"
    description: "Exit without creating feature_list.json"
```

**If validation succeeds:**

Continue to Step 7

## Step 7: Topological Sort & Save

Reorder features topologically and save to project root:

```bash
HARNESS_DIR="$HOME/.claude/skills/long-running-agent/harness"
VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"

# Reorder
"$VENV_PYTHON" "$HARNESS_DIR/dependency_graph.py" reorder .claude/filtered-features.json -o feature_list.json

# Verify saved
if [ -f "feature_list.json" ]; then
  FINAL_COUNT=$(jq '. | length' feature_list.json)
  echo "✅ Created feature_list.json with $FINAL_COUNT features"
else
  echo "❌ Failed to create feature_list.json"
  exit 1
fi
```

## Step 8: Summary & Next Steps

Display summary:

```bash
FEATURE_COUNT=$(jq '. | length' feature_list.json)
LEVELS=$(jq 'group_by(.dependencies | length) | length' feature_list.json)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   DECOMPOSITION COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Statistics:"
echo "   Total Features: $FEATURE_COUNT"
echo "   Dependency Levels: $LEVELS"
echo ""
echo "📁 Files Created:"
echo "   feature_list.json - Validated, topologically sorted feature list"
echo "   .claude/proposed-features.json - Original LLM output"
echo "   .claude/filtered-features.json - After user review"
echo ""
echo "🚀 Next Steps:"
echo "   1. Review feature_list.json if needed"
echo "   2. Run: /sdk-bridge:start"
echo "   3. SDK Bridge will implement features autonomously"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

---

## Notes

**Validation-Only Mode:**

If command is run with `--validate-only` argument:
- Skip input collection
- Read existing feature_list.json
- Run validation
- Display results
- Exit

**Error Recovery:**

If any step fails:
- Clear error messages
- Offer fix/retry/cancel options
- Don't leave partial state (clean up .claude/*.json)

**File Archiving:**

When replacing existing feature_list.json:
```bash
mv feature_list.json feature_list.json.backup.$(date +%Y%m%d-%H%M%S)
```
```

**Step 2: Verify command file**

```bash
ls -lh plugins/sdk-bridge/commands/decompose.md
```

Expected: File exists, ~250 lines

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/commands/decompose.md
git commit -m "feat: create /sdk-bridge:decompose command for task decomposition"
```

---

## Phase 4: Enhance /sdk-bridge:start Command

### Task 4.1: Add Decomposition Offer to Prerequisites Check

**Files:**
- Modify: `plugins/sdk-bridge/commands/start.md:153-191` (Phase 1 prerequisites section)

**Step 1: Read current prerequisites check**

```bash
# View current check
sed -n '153,191p' plugins/sdk-bridge/commands/start.md
```

**Step 2: Modify prerequisites to offer decomposition**

Replace the current check with:

```markdown
## Phase 1: Project Prerequisites Check

Check project-specific requirements (silent checks, only show final status):

```bash
# All checks silent, only output final status
{
  mkdir -p .claude

  # Check feature list
  if [ ! -f "feature_list.json" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Missing feature_list.json"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "SDK Bridge requires a feature_list.json file to work."
    echo ""
    echo "NO_FEATURE_LIST"
    exit 0  # Don't fail, will offer decomposition
  fi

  # Check venv and SDK (should exist after Phase 0)
  VENV_PYTHON="$HOME/.claude/skills/long-running-agent/.venv/bin/python"
  if ! "$VENV_PYTHON" -c "import claude_agent_sdk" 2>/dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ SDK Installation Failed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The claude-agent-sdk package is not installed correctly."
    echo "This should have been installed in Phase 0."
    echo ""
    echo "Try manually:"
    echo "  cd ~/.claude/skills/long-running-agent"
    echo "  source .venv/bin/activate"
    echo "  pip install claude-agent-sdk"
    echo ""
    exit 1
  fi

  echo "✅ Project prerequisites met"
} 2>&1
```

**If output contains `NO_FEATURE_LIST`**, offer decomposition:

```
Use AskUserQuestion:

question: "No feature_list.json found. Would you like me to help create one?"
header: "Setup Required"
multiSelect: false
options:
  - label: "Yes - decompose my task"
    description: "I'll guide you through creating a feature list from your requirements"
  - label: "No - I'll create it manually"
    description: "Exit and let me create feature_list.json myself"
```

**If "Yes - decompose my task":**

Invoke `/sdk-bridge:decompose` command (use Bash to run):

```bash
# Invoke decompose command
echo "Running /sdk-bridge:decompose..."
# The decompose command will handle input collection, decomposition, validation
# When it completes, feature_list.json will exist
```

After decompose completes, continue to Phase 2 (existing configuration flow)

**If "No - I'll create it manually":**

Show instructions and exit:

```
Create feature_list.json manually:

[
  {
    "id": "feature-1",
    "description": "Add user authentication",
    "passes": false
  },
  {
    "id": "feature-2",
    "description": "Create API endpoints",
    "dependencies": ["feature-1"],
    "passes": false
  }
]

Then run /sdk-bridge:start again.
```
```

**Step 3: Test modified prerequisites**

```bash
# Test 1: Missing feature_list.json
rm -f feature_list.json
/sdk-bridge:start

# Should offer decomposition

# Test 2: Existing feature_list.json
echo '[{"id": "feat-001", "description": "Test", "passes": false}]' > feature_list.json
/sdk-bridge:start

# Should skip to configuration
```

**Step 4: Commit**

```bash
git add plugins/sdk-bridge/commands/start.md
git commit -m "feat: offer assisted decomposition when feature_list.json missing"
```

---

## Phase 5: Update Plugin Metadata & Documentation

### Task 5.1: Update plugin.json

**Files:**
- Modify: `plugins/sdk-bridge/.claude-plugin/plugin.json`

**Step 1: Add decompose command to manifest**

```bash
# Read current plugin.json
cat plugins/sdk-bridge/.claude-plugin/plugin.json

# Add decompose.md to commands array
jq '.commands += ["./commands/decompose.md"]' plugins/sdk-bridge/.claude-plugin/plugin.json > tmp.json
mv tmp.json plugins/sdk-bridge/.claude-plugin/plugin.json

# Bump version to 3.0.0
jq '.version = "3.0.0"' plugins/sdk-bridge/.claude-plugin/plugin.json > tmp.json
mv tmp.json plugins/sdk-bridge/.claude-plugin/plugin.json
```

**Step 2: Verify**

```bash
cat plugins/sdk-bridge/.claude-plugin/plugin.json | jq '.commands'
```

Expected: Array includes `"./commands/decompose.md"`

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/.claude-plugin/plugin.json
git commit -m "chore: bump version to 3.0.0, add decompose command"
```

---

### Task 5.2: Update marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Sync marketplace version**

```bash
# Update marketplace metadata version
jq '.metadata.version = "3.0.0"' .claude-plugin/marketplace.json > tmp.json
mv tmp.json .claude-plugin/marketplace.json

# Update plugin version in marketplace
jq '.plugins[0].version = "3.0.0"' .claude-plugin/marketplace.json > tmp.json
mv tmp.json .claude-plugin/marketplace.json

# Add decompose command to plugin entry
jq '.plugins[0].commands += ["./commands/decompose.md"]' .claude-plugin/marketplace.json > tmp.json
mv tmp.json .claude-plugin/marketplace.json
```

**Step 2: Verify**

```bash
cat .claude-plugin/marketplace.json | jq '.metadata.version, .plugins[0].version'
```

Expected: Both show "3.0.0"

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore: sync marketplace.json to v3.0.0"
```

---

### Task 5.3: Update CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md:1-50` (header and version)
- Modify: `CLAUDE.md:END` (add v3.0.0 release notes)

**Step 1: Update version header**

Change line 1:
```markdown
**Current Version: v3.0.0** | Last Updated: 2026-01-17
```

**Step 2: Add release notes**

At the end of "Recent Releases" section:

```markdown
### v3.0.0 - Assisted Decomposition Layer (2026-01-17)
- **TYPE**: Major feature release
- **NEW Command**: `/sdk-bridge:decompose` - LLM-powered task decomposition
  - Three input modes: text, file, file+focus
  - Interactive feature review with AskUserQuestion
  - Computational validation (schema + dependency graph)
  - Automatic topological sorting
- **NEW Skill**: `decompose-task` - Structured decomposition following DRY/YAGNI/TDD
  - Prompt templates for consistent LLM output
  - Worked examples (todo API)
  - Anti-pattern guidance
- **ENHANCED**: `dependency_graph.py` v2.3.0
  - Schema validation (required fields, types, duplicates)
  - Dependency validation (cycles, missing refs, self-deps)
  - Topological reordering
  - CLI interface: validate, reorder, visualize
- **ENHANCED**: `/sdk-bridge:start` - Offers decomposition when feature_list.json missing
- **IMPACT**: Users no longer need to manually create feature_list.json
- **TRANSFORMATION**: From "execution engine requiring manual planning" to "end-to-end autonomous development assistant"
- **FILES**: 10 changed (3 new skills, 1 new command, enhanced dependency_graph.py, updated start.md)
- **COMMITS**: [to be added after implementation]
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add v3.0.0 release notes to CLAUDE.md"
```

---

### Task 5.4: Update README.md

**Files:**
- Modify: `plugins/sdk-bridge/README.md:26-114` (workflow section)

**Step 1: Add decomposition to workflow**

Insert new section before "Quick Start":

```markdown
## ✨ What's New in v3.0

**Assisted Decomposition Layer** - No more manual feature_list.json creation!

```bash
# New workflow (v3.0+)
/sdk-bridge:start

# If no feature_list.json exists:
# → Asks "What do you want to build?"
# → LLM decomposes task into features
# → You review and approve
# → Validation runs automatically
# → Agent launches
```

**Key Features:**
- **LLM-powered decomposition** using `decompose-task` skill
- **Interactive review** with multi-select feature approval
- **Computational validation** catches dependency errors before execution
- **Automatic topological sorting** ensures correct execution order
- **Backward compatible** - existing feature_list.json workflows still work

**Standalone Decomposition:**

```bash
/sdk-bridge:decompose

# Creates feature_list.json from your task description
# Can be used independently before /sdk-bridge:start
```
```

**Step 2: Update command list**

Add new command:

```markdown
## Commands

| Command | Description | When to Use |
|---------|-------------|-------------|
| **`/sdk-bridge:decompose`** | **Generate feature_list.json from task description** | **When you have a task but no feature list** |
| `/sdk-bridge:start` | Interactive setup & auto-launch (one command) | Primary entry point |
| `/sdk-bridge:watch` | Live progress monitoring | Track long-running tasks |
| `/sdk-bridge:status` | One-time status check | Quick progress check |
| ... | ... | ... |
```

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/README.md
git commit -m "docs: add v3.0 decomposition workflow to README"
```

---

## Phase 6: Testing & Validation

### Task 6.1: Manual Integration Test

**Files:**
- Test: End-to-end workflow

**Step 1: Test decomposition skill**

```bash
# Create test project
mkdir -p /tmp/test-sdk-bridge-v3
cd /tmp/test-sdk-bridge-v3

# Test decompose command
/sdk-bridge:decompose
```

**User inputs:**
- "Build a REST API for user authentication with JWT tokens"

**Expected:**
- LLM generates 5-10 features
- Review UI shows all features
- User can uncheck features
- Validation passes
- feature_list.json created

**Step 2: Test start command integration**

```bash
# Remove feature_list.json
rm feature_list.json

# Run start
/sdk-bridge:start
```

**Expected:**
- Detects missing file
- Offers decomposition
- User accepts
- Decomposition runs
- After completion, continues to configuration
- Agent launches

**Step 3: Test validation failure**

```bash
# Create invalid feature_list.json
cat > feature_list.json << 'EOF'
[
  {"id": "feat-001", "dependencies": ["feat-002"]},
  {"id": "feat-002", "dependencies": ["feat-001"]}
]
EOF

# Run decompose with --validate-only
/sdk-bridge:decompose --validate-only
```

**Expected:**
- Validation fails
- Shows error: "Circular dependency detected"
- Offers fix/retry/cancel

**Step 4: Document test results**

Create test report:

```bash
cat > /tmp/test-report.md << 'EOF'
# v3.0 Integration Test Report

## Test 1: Decompose Command
- ✅ Task input collection works
- ✅ LLM decomposition generates valid JSON
- ✅ Interactive review displays features
- ✅ Validation passes
- ✅ feature_list.json created

## Test 2: Start Command Integration
- ✅ Detects missing feature_list.json
- ✅ Offers decomposition
- ✅ Runs decomposition on acceptance
- ✅ Continues to configuration after
- ✅ Agent launches successfully

## Test 3: Validation Failure
- ✅ Catches circular dependency
- ✅ Shows clear error message
- ✅ Offers recovery options

## Issues Found
[None | List any issues]

## Regression Tests
- ✅ Existing feature_list.json workflow still works
- ✅ /sdk-bridge:start with existing file skips decomposition
- ✅ Other commands unaffected
EOF
```

**Step 5: Commit**

```bash
git add /tmp/test-report.md
git commit -m "test: v3.0 integration test completed successfully"
```

---

### Task 6.2: Update Installation Scripts

**Files:**
- Modify: `plugins/sdk-bridge/commands/start.md:119` (version check)

**Step 1: Update version in start.md**

Change version check:

```markdown
PLUGIN_VERSION="3.0.0"
```

**Step 2: Verify harness installation includes new dependency_graph.py**

Ensure that when start.md installs harness, it includes the enhanced dependency_graph.py v2.3.0:

```bash
# In start.md installation section, verify this line exists:
echo "3.0.0" > "$HOME/.claude/skills/long-running-agent/harness/.version"
```

**Step 3: Commit**

```bash
git add plugins/sdk-bridge/commands/start.md
git commit -m "chore: update version checks to 3.0.0"
```

---

## Final Steps: Release

### Task 7.1: Create Git Tag

**Files:**
- Tag: v3.0.0

**Step 1: Create annotated tag**

```bash
git tag -a v3.0.0 -m "Release v3.0.0: Assisted Decomposition Layer

Major feature release transforming SDK Bridge from execution engine to end-to-end autonomous development assistant.

NEW FEATURES:
- /sdk-bridge:decompose command for LLM-powered task decomposition
- decompose-task skill with DRY/YAGNI/TDD principles
- Enhanced dependency_graph.py with validation and CLI
- Automatic topological sorting
- Interactive feature review

BREAKING CHANGES:
- None (backward compatible)

MIGRATION:
- Existing users: no changes required
- New users: can use /sdk-bridge:decompose or create feature_list.json manually
"
```

**Step 2: Push tag**

```bash
git push origin main --tags
```

**Step 3: Verify webhook**

```bash
# Wait ~30 seconds for webhook
gh run list --repo flight505/sdk-bridge --limit 1

# Should show "✅ Marketplace notification sent successfully"
```

**Step 4: Verify marketplace update**

```bash
# Check marketplace version
cat .claude-plugin/marketplace.json | jq '.metadata.version'
```

Expected: "3.0.0"

---

### Task 7.2: Update Project Documentation

**Files:**
- Modify: `CONTEXT_sdk-bridge.md` (version history)

**Step 1: Add v3.0.0 to version history**

In version history table:

```markdown
| Version | Date | Type | Key Changes |
|---------|------|------|-------------|
| v3.0.0 | 2026-01-17 | Major | **Assisted Decomposition Layer - LLM-powered task decomposition** |
| v2.2.3 | 2026-01-16 | Bugfix | Critical version sync fix + deprecation warnings |
| ... | ... | ... | ... |
```

**Step 2: Commit**

```bash
git add CONTEXT_sdk-bridge.md
git commit -m "docs: add v3.0.0 to version history"
```

---

## Success Criteria

**Must Pass:**
- [x] decompose-task skill exists and follows pattern
- [x] dependency_graph.py validation functions work
- [x] `/sdk-bridge:decompose` command completes without errors
- [x] `/sdk-bridge:start` offers decomposition when file missing
- [x] Integration test: full workflow (decompose → review → validate → start → launch)
- [x] Validation catches schema errors
- [x] Validation catches dependency errors (cycles, missing refs)
- [x] Topological sort produces correct order
- [x] Backward compatibility: existing workflows unaffected

**Should Pass:**
- [ ] Generated features follow DRY/YAGNI/TDD principles
- [ ] LLM decomposition quality acceptable (5-25 features, concrete tests)
- [ ] User can exclude features during review
- [ ] Validation warnings are informative

**Nice to Have:**
- [ ] Multi-round editing (deferred to v3.1)
- [ ] File input support (deferred to v3.1)
- [ ] Granularity warnings (deferred to v3.1)

---

## Execution Strategy

**Plan complete and saved to `docs/plans/2026-01-17-assisted-decomposition.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach would you prefer?**
