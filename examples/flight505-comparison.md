# Flight505 US-007 Hang - Before vs After

## Problem Summary

**What happened:** US-007 hung for 32+ minutes because all acceptance criteria were already implemented in US-005. The agent entered an analysis loop trying to understand what "done" meant.

**Root causes:**
1. Vague acceptance criteria ("Accept cabin_class parameter")
2. No dependency metadata linking US-007 to US-005
3. No implementation hints to check existing code
4. No verification commands to check completion

---

## OLD FORMAT (Caused 32-minute hang)

### US-007: Backend cabin class filtering
**Description:** As a user, I want the backend to filter flight results by cabin class.

**Acceptance Criteria:**
- [ ] Accept cabin_class parameter in search endpoint
- [ ] Filter aggregated results before returning
- [ ] When cabin_class is 'all' or null, return all results
- [ ] Update response metadata to include cabin_class filter

**Priority:** 7
**Passes:** false
**Notes:** ""

### Why This Failed

1. **Ambiguous verification**
   - "Accept cabin_class parameter" - where? how to check?
   - "Filter aggregated results" - already done in US-002?
   - No commands to run, no files to check

2. **Missing context**
   - No indication US-005 might have done this
   - No hint to check api.py or aggregation_service.py
   - No dependency linking to US-005

3. **Agent behavior**
   - Read existing code
   - Found cabin_class already implemented
   - Unclear if story satisfied or needs changes
   - Entered analysis loop reading skills for guidance
   - Hung for 32+ minutes

---

## NEW FORMAT (Prevents hang)

### US-007: Backend cabin class filtering
**Description:** As a user, I want the backend to filter flight results by cabin class.

**Acceptance Criteria:**
- [ ] Accept cabin_class parameter in /api/flights/search endpoint
  - **Must verify:** `grep -n "cabin_class" flight_marketplace/api.py`
  - **Expected:** Line shows `cabin_class = data.get("cabin_class")` or similar
- [ ] Filter aggregated results by cabin_class before returning
  - **Must verify:** `grep -n "cabin_class" flight_marketplace/aggregation_service.py`
  - **Expected:** search_flights method accepts and uses cabin_class parameter
- [ ] When cabin_class is 'all' or null, return all results
  - **Must verify:** `curl -X POST http://localhost:5000/api/flights/search -d '{"cabin_class": "all"}' | jq '.results | length'`
  - **Expected:** Returns results from all cabin classes
- [ ] Update response metadata to include cabin_class filter
  - **Must verify:** `curl -X POST http://localhost:5000/api/flights/search -d '{"cabin_class": "economy"}' | jq '.metadata.cabin_class'`
  - **Expected:** Returns "economy"
- [ ] Typecheck passes
  - **Must verify:** `pyright --project .`
  - **Expected:** No errors

**Priority:** 7
**Passes:** false
**Notes:** ""
**Depends on:** ["US-005"]
**Related to:** ["US-002", "US-006"]
**Implementation hint:** "US-005 may have already implemented cabin_class filtering when adding the search endpoint. Check api.py and aggregation_service.py before coding."
**Check before implementing:**
- `grep -n cabin_class flight_marketplace/api.py`
- `grep -n cabin_class flight_marketplace/aggregation_service.py`
- `grep -n cabin_class flight_marketplace/providers/`

### How This Prevents Hang

1. **Explicit verification commands**
   ```bash
   grep -n "cabin_class" flight_marketplace/api.py
   # Agent runs this FIRST, sees:
   # api.py:53: cabin_class = data.get("cabin_class")
   ```

2. **"Check before implementing" section**
   - Agent sees: "US-005 may have already implemented this"
   - Runs grep commands immediately
   - Finds cabin_class in api.py line 53, aggregation_service.py line 62
   - Recognizes all criteria already satisfied

3. **Clear decision path**
   ```markdown
   ## CRITICAL: Check Before Implementing

   5. **If ALL criteria are already satisfied:**
      ```json
      {
        "passes": true,
        "notes": "Already implemented in US-005. Verified:
          - cabin_class parameter: api.py:53
          - filtering logic: aggregation_service.py:62
          - 'all' handling: api.py:56-58
          - metadata: api.py:93"
      }
      ```
      - **SKIP implementation** - do NOT refactor or rewrite working code
   ```

4. **Agent behavior (new)**
   - Reads prompt.md "Check Before Implementing" section
   - Runs `grep cabin_class api.py` → finds line 53
   - Runs `grep cabin_class aggregation_service.py` → finds line 62
   - Verifies each criterion against existing code
   - Marks story complete with verification notes
   - Continues to US-008 in <2 minutes

---

## Impact on Test Run

**OLD FORMAT:**
- Iteration 7 started: US-007
- 32+ minutes: Still running
- Status: Hung, reading unrelated skills
- Manual intervention required

**NEW FORMAT (projected):**
- Iteration 7 started: US-007
- 1 minute: Check existing code
- 2 minutes: Verify all criteria met
- Story marked complete with notes
- Continues to US-008

---

## Generalizable Patterns

### When to use "check_before_implementing"

**Use when:**
- Story might overlap with previous work
- Related stories exist in same area
- Feature could have been over-implemented
- Multiple stories touch same files

**Example patterns:**
```json
{
  "id": "US-015",
  "title": "Add error handling to API",
  "depends_on": ["US-012"],
  "implementation_hint": "US-012 implemented the API - may have included error handling already.",
  "check_before_implementing": [
    "grep -n 'try:' api.py",
    "grep -n 'except' api.py",
    "grep -n 'HTTPException' api.py"
  ]
}
```

### When to use "Must verify" format

**Always use for:**
- File/code existence checks (`grep`, `ls`)
- API endpoint testing (`curl`, `pytest`)
- Build/typecheck verification (`npm run typecheck`)
- Browser testing ("Navigate to X and verify Y")

**Bad (vague):**
- ❌ "API accepts parameter"
- ❌ "Error handling works"
- ❌ "UI looks correct"

**Good (verifiable):**
- ✅ "Must verify: `grep parameter_name api.py`"
- ✅ "Must verify: `curl -X POST ... | jq .error`"
- ✅ "Must verify: Navigate to /page and confirm button visible"

---

## Conclusion

The new format would have **prevented the 32-minute hang** by:

1. **Forcing verification before coding** - Agent checks existing code first
2. **Providing specific commands** - No ambiguity about "what to check"
3. **Clear completion path** - If all verified, mark done and skip
4. **Implementation hints** - Directs agent to likely locations

**Estimated time saved:** 30 minutes per similar scenario
**User experience:** Seamless execution instead of indefinite hang
