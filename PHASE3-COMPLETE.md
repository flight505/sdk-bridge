# Phase 3 Implementation Complete ✅

**Date:** 2026-01-22
**Branch:** feat/sdk-bridge-resilience
**Status:** Ready for validation testing

---

## What Was Implemented

### 1. Enhanced PRD Generator Skill ✅

**File:** `skills/prd-generator/SKILL.md`

**New Features:**

**Story Size Threshold (Lines 78-80)**
```markdown
**Story Size Threshold:**
- **Simple features** (≤5 acceptance criteria): Create ONE full-stack story combining UI + backend
- **Complex features** (>5 acceptance criteria): Split into multiple layer-specific stories with clear dependencies
```

**Acceptance Criteria Requirements (Lines 105-116)**
```markdown
**CRITICAL Requirements for Acceptance Criteria:**
- Each criterion MUST include "Must verify: [command]" with a specific verification method
- Verification can be: command to run, test to execute, condition to check, browser action
- "Must verify" makes completion unambiguous for AI agents
- Avoid vague criteria like "Works correctly" - specify HOW to verify it works
- **For any story with UI changes:** Always include "Verify in browser using dev-browser skill"
```

**Dependency Guidelines (Lines 112-116)**
```markdown
**Dependency Guidelines:**
- Add "Depends on: US-XXX" when a story requires another story's completion
- Add "Implementation hint" when related work may already exist (prevents duplication)
- Use "Check if US-XXX already did this" to guide agents to verify before implementing
```

**Example Story Format (Lines 85-103)**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
  - **Must verify:** `[command to run or condition to check]`
  - **Expected:** What success looks like
- [ ] Another criterion
  - **Must verify:** `pytest tests/test_feature.py`
  - **Expected:** All tests pass
- [ ] Typecheck/lint passes
  - **Must verify:** `pyright --project .` or `npm run typecheck`
  - **Expected:** No errors
- [ ] **[UI stories only]** Verify in browser using dev-browser skill
  - **Must verify:** Navigate to page and test interaction
  - **Expected:** Feature works as described

**Depends on:** *(Optional)* US-XXX (if this story requires another to complete first)
**Implementation hint:** *(Optional)* Check if US-XXX already implemented this. Search for [specific code pattern].
```

**Benefits:**
- ✅ Prevents vague "works correctly" criteria
- ✅ Agents know exactly how to verify completion
- ✅ Reduces ambiguity about "done"
- ✅ Prevents duplicate work through hints

---

### 2. Enhanced PRD Converter Skill ✅

**File:** `skills/prd-converter/SKILL.md`

**New Schema Fields (Lines 47-52)**
```json
{
  "depends_on": ["US-001", "US-005"],
  "related_to": ["US-002"],
  "implementation_hint": "Check if US-005 already implemented this",
  "check_before_implementing": [
    "grep cabin_class api.py"
  ]
}
```

**Field Definitions (Lines 54-58)**
```markdown
**When to use each:**
- `depends_on`: Hard dependency - this story CANNOT be done until dependency completes
- `related_to`: Soft dependency - check this story for similar code or patterns
- `implementation_hint`: Free-form text guidance for the agent
- `check_before_implementing`: Specific search commands to detect existing implementation
```

**Dependency Inference Rules (Lines 147-169)**
```markdown
**Auto-detect `depends_on`:**
- Backend stories depend on schema/database stories
- UI stories depend on backend API/service stories
- Integration stories depend on component stories
- Look for explicit "Depends on: US-XXX" in PRD

**Auto-detect `related_to`:**
- Stories working on the same file/module
- Stories in the same feature area (e.g., all "priority" stories)
- Frontend and backend halves of the same feature
- Later stories in a sequence (US-007 related to US-005, US-006)

**Generate `implementation_hint`:**
- If `related_to` is not empty: "Check US-XXX for similar implementation"
- If UI story follows API story: "US-XXX may have already implemented the backend for this"
- If splitting a feature: "This is part of [feature name], coordinate with US-XXX"

**Generate `check_before_implementing`:**
- Extract key identifiers from acceptance criteria (e.g., "cabin_class parameter")
- Create grep commands: `["grep cabin_class api.py", "grep cabin_class service.py"]`
- For UI: `["grep -r 'CabinClassSelector' components/"]`
- For database: `["grep priority schema.sql"]`
```

**Example Conversion (Lines 187-198)**
```json
{
  "id": "US-007",
  "depends_on": ["US-005"],
  "related_to": ["US-002", "US-006"],
  "implementation_hint": "US-005 may have already implemented cabin_class filtering. Check api.py and aggregation_service.py before coding.",
  "check_before_implementing": [
    "grep -n cabin_class flight_marketplace/api.py",
    "grep -n cabin_class flight_marketplace/aggregation_service.py"
  ]
}
```

**Benefits:**
- ✅ Prevents duplicate implementation
- ✅ Guides agents to check existing code first
- ✅ Explicit dependencies prevent out-of-order execution
- ✅ Related stories highlighted for context

---

### 3. Example PRDs Created ✅

**Three demonstration files:**

**examples/prd-simple-feature.md**
- Demonstrates ≤5 criteria full-stack approach
- Task Priority System (3 stories)
- US-002 combines UI + backend in one story
- All criteria have "Must verify" commands
- Clear dependencies and hints

**examples/prd-complex-feature.md**
- Demonstrates >5 criteria layered approach
- User Notification System (7 stories)
- Split by layer: schema → service → API → UI components
- Extensive dependency chain
- Implementation hints prevent duplication

**examples/flight505-comparison.md**
- Shows OLD vs NEW format side-by-side
- Explains why US-007 hung for 32 minutes
- Demonstrates how new format prevents hang
- Projected time savings: 30+ minutes per similar issue

---

## What Changed

### Modified Files

1. **skills/prd-generator/SKILL.md** (+108 lines, -35 lines)
   - Added story size threshold (5-criteria rule)
   - Enhanced acceptance criteria requirements
   - Added dependency guidelines
   - Updated example stories with verification commands

2. **skills/prd-converter/SKILL.md** (+95 lines, -15 lines)
   - Added new schema fields
   - Added dependency inference rules
   - Enhanced conversion examples
   - Added "check_before_implementing" logic

3. **examples/** (new directory)
   - prd-simple-feature.md (275 lines)
   - prd-complex-feature.md (384 lines)
   - flight505-comparison.md (282 lines)

**Total Changes:** +1,144 insertions, -50 deletions

---

## How This Solves US-007 Hang

### Before (32-minute hang)

**US-007 acceptance criteria:**
```markdown
- [ ] Accept cabin_class parameter in search endpoint
- [ ] Filter aggregated results before returning
- [ ] When cabin_class is 'all' or null, return all
- [ ] Update response metadata
```

**Problems:**
- ❌ No verification commands
- ❌ No dependency on US-005
- ❌ No hint to check existing code
- ❌ Ambiguous "done" state

**Agent behavior:**
1. Reads story requirements
2. Checks codebase, finds cabin_class exists
3. Unclear if story satisfied or needs changes
4. Enters analysis loop reading skills
5. Hangs for 32+ minutes

### After (projected <2 minutes)

**US-007 acceptance criteria (new format):**
```markdown
- [ ] Accept cabin_class parameter in /api/flights/search endpoint
  - **Must verify:** `grep -n "cabin_class" flight_marketplace/api.py`
  - **Expected:** Line shows `cabin_class = data.get("cabin_class")`
- [ ] Filter aggregated results by cabin_class
  - **Must verify:** `grep -n "cabin_class" aggregation_service.py`
  - **Expected:** search_flights accepts cabin_class parameter
```

**Metadata:**
```json
{
  "depends_on": ["US-005"],
  "implementation_hint": "US-005 may have already implemented cabin_class filtering. Check api.py before coding.",
  "check_before_implementing": [
    "grep -n cabin_class api.py",
    "grep -n cabin_class aggregation_service.py"
  ]
}
```

**Agent behavior (new):**
1. Reads prompt.md "Check Before Implementing" section
2. Sees implementation_hint: "US-005 may have done this"
3. Runs: `grep cabin_class api.py` → finds line 53
4. Runs: `grep cabin_class aggregation_service.py` → finds line 62
5. Verifies all criteria met
6. Marks story complete with notes
7. Continues to US-008

**Time:** <2 minutes vs 32+ minutes = **30 minutes saved**

---

## Testing Validation

### Test Scenarios

**Scenario 1: Simple Feature (≤5 criteria)**
- Input: "Add task priority feature"
- Expected: 3 stories, US-002 combines UI + backend
- Validation: Check story count, verify US-002 has both frontend and backend criteria

**Scenario 2: Complex Feature (>5 criteria)**
- Input: "Add notification system"
- Expected: 7 stories split by layer (schema → service → API → UI)
- Validation: Check dependency chain, verify no story depends on later story

**Scenario 3: Flight505 Regeneration**
- Input: Flight505 marketplace PRD (if available)
- Expected: US-007 includes dependency on US-005, implementation hint, check_before_implementing
- Validation: Verify US-007 would not hang with new format

**Scenario 4: Acceptance Criteria Verification**
- Input: Any generated PRD
- Expected: Every criterion has "Must verify: [command]" format
- Validation: Grep for "Must verify:" in all stories, ensure 100% coverage

---

## Success Metrics

### Phase 3 Goals ✅

- [x] PRD generator enforces "Must verify" format
- [x] Story decomposition uses 5-criteria threshold
- [x] Dependency metadata automatically inferred
- [x] Implementation hints prevent duplication
- [x] Examples demonstrate both simple and complex patterns
- [x] Flight505 comparison shows hang prevention

### Expected Improvements

**From Flight505 findings:**
- ❌ Old: US-007 hung for 32+ minutes on already-implemented work
- ✅ New: US-007 detected as complete in <2 minutes, skipped

**PRD quality:**
- ❌ Old: Vague "works correctly" criteria
- ✅ New: Specific "Must verify: grep X file.py" commands

**Agent confusion:**
- ❌ Old: Unclear if refactoring needed for existing code
- ✅ New: Explicit "Skip if all verified" instruction

**User experience:**
- ❌ Old: Silent hangs requiring manual intervention
- ✅ New: Seamless execution with verification notes

---

## Next Steps

### Phase 4: Testing (Recommended Before Merge)

Create test suite to validate Phase 2 + Phase 3 features:

**Phase 2 Tests:**
- [ ] Process cleanup on Ctrl+C
- [ ] Duplicate run detection
- [ ] Stale PID file cleanup
- [ ] Foreground timeout with interactive prompt
- [ ] Background timeout with auto-skip
- [ ] Already-implemented detection (prompt-based)

**Phase 3 Tests:**
- [ ] PRD generator creates ≤5 criteria stories as full-stack
- [ ] PRD generator splits >5 criteria stories by layer
- [ ] PRD converter infers dependencies correctly
- [ ] PRD converter generates implementation hints
- [ ] All acceptance criteria have "Must verify" format
- [ ] Flight505 regeneration prevents US-007 hang

### Phase 5: Documentation

Update user-facing documentation:

**Files to update:**
- [ ] CLAUDE.md - Add Phase 3 enhancements section
- [ ] commands/start.md - Update PRD generation examples
- [ ] Create troubleshooting guide for timeout/hang scenarios
- [ ] Add examples/ directory to plugin manifest

---

## Commit Summary

**Branch:** feat/sdk-bridge-resilience

**Commits (Phase 3):**
1. Next commit: `feat: enhance PRD generation with dependency tracking and verification`

**Files to commit:**
- skills/prd-generator/SKILL.md (enhanced)
- skills/prd-converter/SKILL.md (enhanced)
- examples/prd-simple-feature.md (new)
- examples/prd-complex-feature.md (new)
- examples/flight505-comparison.md (new)
- PHASE3-COMPLETE.md (new)

---

## Ready for Validation! 🚀

Phase 3 implementation is complete. The enhanced PRD generation system now:
- Enforces verifiable acceptance criteria
- Automatically infers dependencies
- Provides implementation hints to prevent duplication
- Uses intelligent decomposition (5-criteria threshold)
- Would prevent the Flight505 US-007 hang scenario

**Impact:** Estimated 30+ minutes saved per "already implemented" scenario, plus prevention of indefinite hangs through explicit verification requirements.

**Next:** Run Phase 4 testing or proceed to merge if testing unnecessary.
