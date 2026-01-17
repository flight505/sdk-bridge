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
