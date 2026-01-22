# Phase 1: Design Decisions Analysis & Recommendations

**Date:** 2026-01-22
**Branch:** feat/sdk-bridge-resilience
**Purpose:** Analyze 6 critical design decisions before implementing SDK Bridge resilience features

---

## Decision #1: Iteration Timeout Strategy

### Problem Analysis

**Current State:**
- Claude iterations can run indefinitely
- Test case: US-007 hung for 32+ minutes
- No mechanism to detect or terminate stuck iterations
- Main loop waits forever for Claude CLI to complete

**Impact:**
- Blocks entire SDK Bridge execution
- Wastes computational resources
- Poor user experience (no feedback that something is wrong)
- Prevents progress on remaining stories

**Requirements:**
- Must prevent indefinite hangs
- Should allow different stories varying time to complete
- Must preserve work done before timeout
- Should provide clear feedback to user

### Recommendation Options

#### Option A: Fixed 10-Minute Timeout (Simple & Predictable)

**Implementation:**
```bash
timeout 600 claude -p "..." || handle_timeout
```

**Pros:**
- Simple to implement and understand
- Predictable behavior for all iterations
- 10 minutes generous for most tasks (test showed 6 stories in ~20 min = ~3 min avg)
- Industry standard for CI/CD tasks

**Cons:**
- May cut off legitimately complex stories
- No flexibility for different story types
- Might need adjustment after real-world usage

**Best for:** MVP/initial implementation, most projects

---

#### Option B: Configurable Timeout in .claude/sdk-bridge.local.md

**Implementation:**
```yaml
---
iteration_timeout: 600  # seconds
max_iterations: 10
---
```

**Pros:**
- Users can adjust based on project complexity
- Can be tuned after observing patterns
- Different projects can have different limits
- User maintains control

**Cons:**
- More complex to implement
- Users need to understand appropriate values
- May lead to "timeout creep" (users keep increasing it)
- Still doesn't handle story-specific variation

**Best for:** Power users, projects with known slow operations

---

#### Option C: Adaptive Timeout Based on Story Priority/Complexity

**Implementation:**
```json
{
  "id": "US-001",
  "priority": 1,
  "estimated_duration": "high",  // high=15min, medium=10min, low=5min
  "timeout_multiplier": 1.5
}
```

**Pros:**
- Intelligent allocation of time
- Complex stories get more time
- Simple stories fail fast
- Matches real-world variance

**Cons:**
- Requires estimation metadata in PRD
- More complex logic
- PRD generator must estimate complexity
- Risk of poor estimates

**Best for:** Large projects with varied story complexity

---

#### Option D: Progressive Timeout with Warnings

**Implementation:**
```bash
# Soft warning at 5 min, hard timeout at 10 min
timeout 300 check_progress || warn_user
timeout 600 claude -p "..." || hard_timeout
```

**Pros:**
- User awareness before termination
- Opportunity to intervene
- Helps identify slow stories
- Better debugging

**Cons:**
- Complex implementation
- Requires progress detection mechanism
- May interrupt user flow
- Not suitable for background mode

**Best for:** Interactive use, debugging scenarios

---

### My Recommendation: **Option B (Configurable) with Option A as Default**

**Reasoning:**
1. Start with simple 10-minute default (Option A)
2. Allow override via config (Option B flexibility)
3. Provides escape hatch for edge cases
4. Can evolve to Option C later based on data

**Suggested Implementation:**
```yaml
# .claude/sdk-bridge.local.md (optional override)
---
iteration_timeout: 600  # default: 10 minutes
---

# In sdk-bridge.sh:
TIMEOUT=${ITERATION_TIMEOUT:-600}  # Read from config or use 600
timeout $TIMEOUT claude -p "..."
```

**Question for User:** Which option do you prefer? Or should we go with my hybrid recommendation?

---

## Decision #2: "Already Implemented" Detection Method

### Problem Analysis

**Current State:**
- Agents don't check if work is already done
- Can't distinguish "need to implement" vs "already exists"
- Test case: US-007 all criteria met by US-005, agent got confused
- Led to 32+ minute analysis loop

**Root Causes:**
1. Granular PRD decomposition (split features by layer)
2. Agents naturally implement more than minimum requirements
3. No code-aware validation mechanism
4. Unclear when "done" means "skip this story"

**Requirements:**
- Must detect when acceptance criteria already satisfied
- Should be fast (not slow down normal iterations)
- Must minimize false positives (claiming done when it's not)
- Should provide clear documentation of findings

### Recommendation Options

#### Option A: Prompt-Based Manual Verification (Lightweight)

**Implementation:**
Add to `scripts/prompt.md`:
```markdown
## CRITICAL: Check Before Implementing

Before writing ANY code for this story:

1. **Search for existing implementation:**
   - Use Grep to search for relevant functions/endpoints
   - Use Read to check files mentioned in acceptance criteria
   - Look for similar functionality in codebase

2. **Verify each acceptance criterion:**
   - Check if each criterion is already satisfied
   - Document WHERE it's implemented (file:line)

3. **If ALL criteria already met:**
   ```json
   // Update prd.json
   {
     "passes": true,
     "notes": "Already implemented in US-XXX. Verified:
       - Criterion 1: implemented at api.py:53
       - Criterion 2: implemented at aggregation_service.py:62
       - All tests passing"
   }
   ```
   - Skip to next story
   - DO NOT refactor working code

4. **If partially implemented:**
   - Document what exists
   - Implement only missing pieces
```

**Pros:**
- No code changes to SDK Bridge itself
- Leverages agent's existing capabilities (Grep, Read)
- Flexible - agents can use judgment
- Clear instructions reduce confusion

**Cons:**
- Relies on agent compliance (not guaranteed)
- May still cause confusion in ambiguous cases
- No automated enforcement
- Quality depends on agent's analysis

**Best for:** Quick MVP, testing if this solves the problem

---

#### Option B: Pre-Flight Validation Script

**Implementation:**
```python
# scripts/validate-story.py
def check_already_implemented(story_id, acceptance_criteria):
    """
    Scan codebase for evidence criteria are met.
    Returns: {"implemented": bool, "evidence": [...], "confidence": 0-100}
    """
    for criterion in acceptance_criteria:
        # Parse criterion for checkable elements
        # Example: "Accept cabin_class parameter in search endpoint"
        # -> Check if cabin_class in api.py function signatures

        if matches_found:
            evidence.append({
                "criterion": criterion,
                "found_in": "api.py:53",
                "code_snippet": "cabin_class = data.get('cabin_class')"
            })

    return analysis
```

Call before each iteration:
```bash
# If validation says >=80% implemented, skip or ask user
python scripts/validate-story.py US-007
```

**Pros:**
- Automated, consistent checking
- Reduces agent confusion
- Fast (runs before spawning Claude)
- Can be improved over time

**Cons:**
- Complex to implement well
- May have false positives/negatives
- Requires maintenance as codebase evolves
- Language-specific (harder for multi-language projects)

**Best for:** Large projects, repeated runs, mature codebase

---

#### Option C: Hybrid: Prompt Guidance + Post-Iteration Validation

**Implementation:**
1. Use Option A prompt guidance
2. After iteration completes, validate:
   ```python
   # Check if agent claimed "already implemented"
   if story.passes and "Already implemented" in story.notes:
       # Run validation to confirm
       validation = validate_story(story.id)
       if not validation.confirmed:
           # Mark for human review
           flag_for_review(story.id, validation.issues)
   ```

**Pros:**
- Catches agent mistakes
- Prompt guides agent, validation catches errors
- Best of both worlds
- Builds confidence in system

**Cons:**
- Most complex option
- Two mechanisms to maintain
- Slower (runs after iteration)
- May create confusing feedback loops

**Best for:** High-stakes projects, quality-critical work

---

#### Option D: Dependency-Aware PRD Generation

**Implementation:**
Prevent duplicate stories during PRD generation:
```python
# In prd-generator skill
def generate_stories(requirements):
    stories = []
    implemented_features = set()

    for req in requirements:
        # Check if feature already covered by previous story
        if is_duplicate(req, implemented_features):
            # Either skip or merge into existing story
            continue

        story = create_story(req)
        implemented_features.add(story.feature_area)
        stories.append(story)

    return deduplicated_stories
```

**Pros:**
- Prevents problem at source
- Cleaner PRDs, no duplicate work
- Simpler execution (no detection needed)
- Better user experience

**Cons:**
- Requires smarter PRD generation
- May miss legitimate decomposition
- Harder to implement (AI reasoning)
- Doesn't help with existing PRDs

**Best for:** Long-term solution, prevents future issues

---

### My Recommendation: **Start with Option A, Plan for Option D**

**Reasoning:**
1. **Immediate fix:** Option A solves the problem quickly with prompt improvements
2. **Validate effectiveness:** If agents comply, problem solved with minimal code
3. **Long-term:** Improve PRD generation (Option D) to prevent duplicates
4. **Future enhancement:** Add Option B validation if false positives become an issue

**Suggested Implementation:**
```markdown
Phase 1: Update prompt.md with clear "check before implementing" instructions
Phase 2: Monitor agent behavior - do they skip appropriately?
Phase 3: If issues persist, add validation script (Option B)
Phase 4: Enhance PRD generator to prevent duplicates (Option D)
```

**Question for User:** Does this phased approach make sense? Or prefer a different option?

---

## Decision #3: Acceptance Criteria Specificity Standards

### Problem Analysis

**Current State:**
- Acceptance criteria often vague
  - ❌ "Accept cabin_class parameter in search endpoint"
  - ❌ "Filter aggregated results before returning to frontend"
- Hard for agents to determine completion
- Ambiguity leads to over-implementation or analysis paralysis

**Requirements:**
- Criteria must be unambiguous
- Should be verifiable (testable)
- Must be specific enough for agent clarity
- Should remain readable for humans

### Recommendation Options

#### Option A: File/Function References Required

**Format:**
```markdown
- Add `cabin_class` parameter to `search_flights()` in `flight_marketplace/api.py`
- Update `FlightAggregationService.search_flights()` to accept `cabin_class` parameter
- Modify line 67 in `api.py` to pass `cabin_class` to aggregation service
```

**Pros:**
- Extremely specific
- Easy to verify (check exact file:line)
- No ambiguity
- Agents know exactly what to change

**Cons:**
- Brittle (line numbers change)
- Over-constrains implementation
- Hard to write during PRD generation (codebase may not exist yet)
- Limits agent creativity

**Best for:** Bug fixes, refactoring tasks, existing codebases

---

#### Option B: Verification Commands Included

**Format:**
```markdown
- Accept cabin_class parameter in search endpoint
  **Verify:** `curl -X POST http://localhost:8000/api/flights/search -d '{"cabin_class": "economy"}' | jq '.metadata.cabin_class_filter'`
  **Expected:** `"economy"`

- Filter results by cabin class
  **Verify:** `pytest tests/test_cabin_filter.py::test_economy_filter_only`
  **Expected:** All tests pass
```

**Pros:**
- Specific and verifiable
- Provides automated testing approach
- Language/framework agnostic
- Encourages test-driven development

**Cons:**
- Requires test infrastructure
- Longer to write
- May not cover all acceptance aspects
- Assumes testability

**Best for:** API work, backend services, TDD projects

---

#### Option C: Given/When/Then (BDD) Format

**Format:**
```markdown
**Given** a flight search API endpoint exists
**When** I send a POST request with `cabin_class: "economy"`
**Then** the response only contains economy class flights
**And** the metadata shows `cabin_class_filter: "economy"`
```

**Pros:**
- Industry standard (BDD)
- Clear behavior specification
- Human-readable
- Focuses on outcomes, not implementation

**Cons:**
- Can still be ambiguous
- Requires BDD knowledge
- May be too abstract for agents
- Doesn't specify WHERE to implement

**Best for:** User-facing features, product-driven teams

---

#### Option D: Minimum Programmatic Verification (Hybrid)

**Format:**
```markdown
- Accept cabin_class parameter in search endpoint
  - Endpoint: `POST /api/flights/search`
  - Parameter: `cabin_class` (optional string: 'economy'|'business'|'first'|'all')
  - **Must verify:** Response includes `metadata.cabin_class_filter` field

- Filter aggregated results by cabin class
  - **Must verify:** Typecheck passes (pyright --project .)
  - **Must verify:** `pytest tests/test_api.py -k cabin` passes
```

**Pros:**
- Balances specificity with flexibility
- Includes at least one verifiable check per criterion
- Not over-constrained
- Practical for agents

**Cons:**
- Requires some test infrastructure
- Slightly more work to write
- May still have edge cases
- Quality depends on verification quality

**Best for:** Most projects, balanced approach

---

### My Recommendation: **Option D (Hybrid) as Standard**

**Reasoning:**
1. **Specificity:** Enough detail to prevent ambiguity
2. **Flexibility:** Doesn't over-constrain implementation
3. **Verifiable:** Each criterion has at least one programmatic check
4. **Practical:** Agents can determine "done" with confidence
5. **Evolves well:** Can tighten (Option A) or loosen (Option C) as needed

**Suggested Template:**
```markdown
## Acceptance Criteria Template

### Criterion: [What needs to be true]
- **Implementation hint:** [Where/how - optional]
- **Must verify:** [Command to run or condition to check]
- **Expected:** [What success looks like]

### Example:
- Accept cabin_class parameter in search endpoint
  - **Implementation hint:** Modify POST /api/flights/search to accept optional cabin_class
  - **Must verify:** `curl -X POST .../search -d '{"cabin_class": "economy"}' && echo $?`
  - **Expected:** HTTP 200, response includes filtered flights
```

**PRD Generator Enforcement:**
```python
# In prd-generator skill
def validate_acceptance_criteria(criteria):
    for criterion in criteria:
        if "Must verify:" not in criterion:
            warn("Missing verification method")
        if too_vague(criterion):
            suggest_refinement(criterion)
```

**Question for User:** Acceptable standard? Or prefer different option?

---

## Decision #4: Task Dependency Metadata Design

### Problem Analysis

**Current State:**
- Stories may depend on each other but no explicit tracking
- Agents don't know to check for previously completed dependencies
- Example: US-007 depended on US-005 but no metadata indicated this

**Requirements:**
- Track which stories depend on which
- Inform agents of dependencies
- Enable dependency validation
- Support both explicit and inferred dependencies

### Recommendation Options

#### Option A: Explicit depends_on Field

**Schema:**
```json
{
  "id": "US-007",
  "title": "Backend cabin class filtering",
  "depends_on": ["US-002", "US-005"],
  "implementation_hint": "US-005 may have already implemented this. Verify cabin_class parameter exists before coding."
}
```

**Usage:**
```python
# Before implementing US-007
for dep_id in story.depends_on:
    dep_story = get_story(dep_id)
    if not dep_story.passes:
        error("Dependency {dep_id} not complete. Skip US-007.")
```

**Pros:**
- Simple and explicit
- Easy to validate
- Agents have clear guidance
- Prevents out-of-order execution

**Cons:**
- Manual effort to specify dependencies
- May miss implicit dependencies
- Requires PRD generator intelligence
- Can be over-specified

**Best for:** Clear, linear dependencies

---

#### Option B: Automatic Dependency Detection

**Implementation:**
```python
def infer_dependencies(story, existing_stories):
    """
    Infer dependencies based on:
    - Shared files/modules
    - Similar acceptance criteria
    - Sequential priorities
    - Feature area overlap
    """
    dependencies = []

    for existing in existing_stories:
        if shares_files(story, existing):
            dependencies.append(existing.id)
        if similar_criteria(story, existing):
            dependencies.append(existing.id)

    return dependencies
```

**Pros:**
- No manual work
- Catches non-obvious dependencies
- Evolves with codebase
- Reduces PRD writing burden

**Cons:**
- May infer incorrect dependencies
- Complex to implement well
- Hard to debug when wrong
- May be too aggressive (false positives)

**Best for:** Large PRDs, complex projects

---

#### Option C: Hybrid: Explicit + Inferred with Hints

**Schema:**
```json
{
  "id": "US-007",
  "depends_on": ["US-005"],  // Explicit required dependency
  "related_stories": ["US-002", "US-006"],  // Inferred related work
  "implementation_hint": "US-005 implemented cabin_class parameter. Check if filtering already done.",
  "check_before_implementing": [
    "Search api.py for cabin_class parameter",
    "Search aggregation_service.py for cabin_class filtering"
  ]
}
```

**Pros:**
- Best of both worlds
- Explicit for critical dependencies
- Inferred for awareness
- Clear guidance for agents

**Cons:**
- More complex schema
- Two systems to maintain
- May be redundant
- Requires good PRD generator

**Best for:** Medium to large projects

---

#### Option D: Dependency Graph Validation

**Implementation:**
```python
# Before execution starts
dependency_graph = build_graph(all_stories)

# Validate graph
if has_cycles(dependency_graph):
    error("Circular dependency detected: US-007 -> US-012 -> US-007")

if has_missing(dependency_graph):
    warn("US-007 depends on US-999 which doesn't exist")

# Execution order
execution_order = topological_sort(dependency_graph)
```

**Pros:**
- Catches issues before execution
- Optimal execution order
- Prevents circular dependencies
- Clear error messages

**Cons:**
- Complex to implement
- May over-constrain execution
- Requires all dependencies specified upfront
- Less flexible for parallel execution

**Best for:** Large, complex PRDs with many dependencies

---

### My Recommendation: **Option C (Hybrid) with Optional Graph Validation**

**Reasoning:**
1. **Explicit dependencies:** For critical "must complete first" relationships
2. **Related stories:** For awareness and "check if already done"
3. **Implementation hints:** Guide agents where to look
4. **Optional validation:** Can add graph checks later if needed

**Suggested Schema:**
```json
{
  "id": "US-007",
  "title": "Backend cabin class filtering",
  "depends_on": ["US-005"],  // Must be done first
  "related_to": ["US-002", "US-006"],  // Check these for related work
  "implementation_hint": "US-005 may have implemented this. Verify before coding.",
  "check_before_implementing": [
    "grep -n 'cabin_class' flight_marketplace/api.py",
    "grep -n 'cabin_class' flight_marketplace/aggregation_service.py"
  ]
}
```

**PRD Generator Behavior:**
```python
# When creating US-007 (Backend cabin class)
# Look for US-006 (UI cabin class) - mark as related
# Look for US-005 (API endpoint) - mark as dependency
# Add hint about checking existing implementation
```

**Question for User:** Does this hybrid approach work? Or prefer simpler Option A?

---

## Decision #5: Task Decomposition Strategy

### Problem Analysis

**Current State:**
- PRDs split features by layer (UI/Backend)
- Agents naturally implement full-stack features
- Led to US-007 being already done when agent reached it

**Real-World Observation:**
- US-006: "Cabin class filter UI"
- US-007: "Backend cabin class filtering"
- But agent implementing US-005 (API endpoint) already did both!

**Trade-offs:**
- **Too granular:** Duplicate work, agent confusion
- **Too coarse:** Large stories take many iterations, hard to checkpoint
- **Just right:** One story = one logical unit of work

### Recommendation Options

#### Option A: Feature-Complete Stories (Full-Stack)

**Approach:**
```markdown
US-006: Complete Cabin Class Filtering Feature
- Add UI selector (dropdown/button group)
- Add backend parameter acceptance
- Implement filtering logic
- Add tests for UI and backend
- Verify end-to-end in browser
```

**Pros:**
- No duplicate work
- Natural agent workflow
- Complete features faster
- Better checkpointing (whole feature done)

**Cons:**
- Larger stories (may exceed iteration timeout)
- Harder to parallelize (if we add that later)
- May mix concerns (UI + backend in one commit)
- Could be too much for simple agents

**Best for:** Small to medium features, autonomous execution

---

#### Option B: Layer-Specific with Explicit Dependencies

**Approach:**
```markdown
US-006: Cabin Class Filter UI (Frontend)
- Add UI selector
- Update query parameters
- Send cabin_class to backend
- Depends on: None
- Related to: US-007

US-007: Backend Cabin Class Filtering (Backend)
- Accept cabin_class parameter (if not present)
- Implement filtering in aggregation service (if not present)
- Update response metadata
- Depends on: US-006 (or verify UI sends parameter)
- Implementation hint: Check if US-005 already did this
```

**Pros:**
- Clear separation of concerns
- Easier to reason about
- Specialists can work on their layer
- Better git history (frontend/backend separate commits)

**Cons:**
- Requires good dependency metadata
- Risk of duplication (as we saw)
- More complex coordination
- Agents may still over-implement

**Best for:** Large teams, clear layer separation

---

#### Option C: Hybrid: Simple Features Full-Stack, Complex Features Layered

**Decision Rules:**
```python
def decompose_feature(feature):
    if estimate_complexity(feature) < THRESHOLD:
        # Simple feature - do full stack
        return create_single_story(feature)
    else:
        # Complex feature - split by layer with dependencies
        return [
            create_ui_story(feature),
            create_backend_story(feature, depends_on=ui_story),
            create_integration_story(feature, depends_on=[ui, backend])
        ]
```

**Example:**
```markdown
# Simple feature (< 100 LOC estimated)
US-006: Complete Cabin Class Filtering
- Full stack implementation

# Complex feature (> 100 LOC estimated)
US-010: Advanced Search with Filters
  US-010a: Search UI Components
  US-010b: Backend Search Service
  US-010c: Database Indexing
  US-010d: Integration & Testing
```

**Pros:**
- Adapts to feature complexity
- Best of both approaches
- Reduces over-implementation for simple tasks
- Manageable chunks for complex tasks

**Cons:**
- Requires complexity estimation
- More complex PRD generation logic
- Inconsistent story patterns
- Users need to understand the rules

**Best for:** Mixed complexity projects

---

#### Option D: Size-Bounded Stories (Max LOC Target)

**Approach:**
```python
def create_stories(feature):
    """
    Split feature into stories targeting ~50-150 LOC each.
    Use natural boundaries (components, services, endpoints).
    """
    stories = []
    current_size = 0

    for component in feature.components:
        if current_size + component.size > MAX_STORY_SIZE:
            stories.append(current_story)
            current_story = new_story()

        current_story.add(component)
        current_size += component.size

    return stories
```

**Pros:**
- Consistent story sizes
- Predictable iteration times
- Good for timeout management
- Clear progress tracking

**Cons:**
- May split illogical places
- Hard to estimate before implementation
- May create artificial boundaries
- Overhead of size estimation

**Best for:** Large projects, predictable execution

---

### My Recommendation: **Option C (Hybrid) with Simple Rules**

**Reasoning:**
1. **90% of stories are simple:** Do them full-stack (Option A)
2. **10% are complex:** Split by layer with dependencies (Option B)
3. **Clear threshold:** Use acceptance criteria count as proxy
   - ≤ 5 criteria = simple = full-stack
   - \> 5 criteria = complex = split with dependencies

**Suggested Implementation:**
```python
# In PRD generator
def decompose_feature(feature_description):
    criteria = generate_acceptance_criteria(feature_description)

    if len(criteria) <= 5:
        # Simple feature - one story
        return Story(
            title=f"Complete {feature_description}",
            criteria=criteria,
            type="full-stack"
        )
    else:
        # Complex feature - split by layer
        ui_criteria = [c for c in criteria if is_ui(c)]
        backend_criteria = [c for c in criteria if is_backend(c)]

        return [
            Story(title=f"{feature_description} - UI", criteria=ui_criteria),
            Story(title=f"{feature_description} - Backend",
                  criteria=backend_criteria,
                  depends_on=[ui_story.id],
                  hint="Check if API story already implemented this")
        ]
```

**Question for User:** Does this 5-criteria threshold make sense? Prefer different threshold or approach?

---

## Decision #6: Hung Iteration Recovery Strategy

### Problem Analysis

**Current State:**
- When iteration times out, loop just continues
- No indication to user what happened
- Partial work may or may not be committed
- No way to skip problematic stories

**Requirements:**
- Clear indication that timeout occurred
- Preserve any committed work
- Option to skip story and continue
- User awareness and control

### Recommendation Options

#### Option A: Skip Story, Mark Failed, Continue

**Behavior:**
```bash
# Iteration times out
echo "⚠️  Iteration $i timed out on US-007 after 10 minutes"

# Update prd.json
jq '.stories[] | select(.id=="US-007") | .status = "timeout"' prd.json

# Append to progress.txt
echo "## Iteration $i - TIMEOUT
Story: US-007 Backend cabin class filtering
Duration: 10:00 (timeout)
Status: Skipped - exceeded time limit
Note: May need manual implementation or PRD revision
---" >> progress.txt

# Continue to next story
```

**Pros:**
- Simple and autonomous
- Doesn't block progress
- Clear record of what happened
- User can revisit later

**Cons:**
- May skip important stories
- Dependent stories might fail
- No retry opportunity
- Loss of momentum

**Best for:** Background execution, autonomous mode

---

#### Option B: Retry Once with Extended Timeout

**Behavior:**
```bash
# First timeout at 10 min
echo "⚠️  Iteration $i timed out. Retrying with 15-minute timeout..."

# Retry with 1.5x timeout
timeout 900 claude -p "..." || {
    # Second timeout - give up
    echo "❌ Iteration $i failed after retry"
    mark_story_failed()
}
```

**Pros:**
- Gives story second chance
- May succeed on retry (transient issues)
- Only costs 5 extra minutes
- Feels less arbitrary

**Cons:**
- Delays progress by up to 15 min
- May timeout again anyway
- Wastes time if fundamental issue
- Could compound delays

**Best for:** Flaky environments, network issues

---

#### Option C: Interactive Prompt (Foreground Mode Only)

**Behavior:**
```bash
# Iteration times out
echo ""
echo "⚠️  Iteration $i timed out on US-007 after 10 minutes"
echo ""
echo "Options:"
echo "  1. Skip story and continue to US-008"
echo "  2. Retry with extended timeout (15 min)"
echo "  3. Abort SDK Bridge execution"
echo "  4. Mark story complete and continue (if work looks done)"
echo ""
read -p "Choice (1-4): " choice

case $choice in
    1) skip_story ;;
    2) retry_with_extended_timeout ;;
    3) exit 1 ;;
    4) mark_complete_and_continue ;;
esac
```

**Pros:**
- User control
- Informed decisions
- Can salvage partial work
- Flexible

**Cons:**
- Breaks autonomous execution
- Not suitable for background mode
- Requires user present
- Interrupts workflow

**Best for:** Interactive development, debugging

---

#### Option D: Simplified Story Retry (AI-Assisted)

**Behavior:**
```bash
# Iteration times out
echo "⚠️  Story US-007 timed out. Attempting simplified version..."

# Create simplified prompt
simplified_prompt="
Story US-007 timed out during full implementation.

SIMPLIFIED TASK:
- Verify if acceptance criteria already met
- If not, implement ONLY the minimum viable solution
- Skip comprehensive testing, focus on core functionality
- Time limit: 5 minutes
"

timeout 300 claude -p "$simplified_prompt" || {
    echo "❌ Simplified version also timed out. Skipping US-007."
}
```

**Pros:**
- Autonomous recovery
- May succeed with simpler approach
- Faster than full retry
- Learns from timeout

**Cons:**
- Complex to implement
- May produce lower quality code
- Requires intelligent simplification
- Could create technical debt

**Best for:** Large PRDs, resilient execution

---

### My Recommendation: **Option A (Skip) for Background, Option C (Interactive) for Foreground**

**Reasoning:**
1. **Background mode:** Can't wait for user input → Skip and log (Option A)
2. **Foreground mode:** User is present → Ask for guidance (Option C)
3. **Best of both worlds:** Appropriate for each mode
4. **Can add retry later:** If we see many transient timeouts, add Option B

**Suggested Implementation:**
```bash
handle_timeout() {
    local story_id=$1
    local iteration=$2

    if [ "$EXECUTION_MODE" = "foreground" ]; then
        # Interactive prompt (Option C)
        prompt_user_for_action "$story_id"
    else
        # Background mode - skip and log (Option A)
        echo "⚠️  Iteration $iteration timed out on $story_id" >&2
        mark_story_timeout "$story_id"
        log_timeout_to_progress "$story_id" "$iteration"
        # Continue to next iteration
    fi
}
```

**Question for User:** Does mode-based behavior make sense? Or prefer single strategy for both modes?

---

## Summary of Recommendations

| # | Decision | Recommended Option | Rationale |
|---|----------|-------------------|-----------|
| 1 | Iteration Timeout | **Option B (Configurable) with A as default** | 10-min default, allow override for edge cases |
| 2 | Already Implemented Detection | **Option A (Prompt-based), plan for D** | Quick fix now, prevent at source later |
| 3 | Acceptance Criteria Specificity | **Option D (Hybrid verification)** | Balance of specificity and flexibility |
| 4 | Task Dependency Metadata | **Option C (Hybrid: explicit + hints)** | Clear dependencies, helpful hints for agents |
| 5 | Task Decomposition | **Option C (Hybrid: simple=full-stack, complex=layered)** | ≤5 criteria = one story, >5 = split with deps |
| 6 | Hung Iteration Recovery | **Option A for background, Option C for foreground** | Mode-appropriate recovery strategies |

---

## Next Steps

**Please review each recommendation and provide feedback:**

1. **Iteration Timeout:** Configurable with 10-min default OK? Different default?
2. **Already Implemented:** Start with prompt instructions acceptable?
3. **Acceptance Criteria:** Hybrid format with verification commands OK?
4. **Dependencies:** Explicit + hints approach acceptable?
5. **Decomposition:** 5-criteria threshold OK? Different number?
6. **Recovery:** Different strategies per mode OK? Prefer unified?

**After your approval, I'll proceed to Phase 2 implementation!**
