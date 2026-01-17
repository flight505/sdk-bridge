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
