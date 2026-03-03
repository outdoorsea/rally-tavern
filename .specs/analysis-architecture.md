# Architecture & Integration Analysis

> Analysis of `.specs/plan.md` — Rally System architecture review
>
> Bead: rt-06gx | Analyst: polecat/rust | Date: 2026-03-03

---

## 1. Gas Town Integration Points

### 1.1 Current Integration Surface

Rally must integrate with four existing Gas Town subsystems:

| Subsystem | Integration Type | Mechanism | Risk |
|-----------|-----------------|-----------|------|
| **Mayor** | Skill execution | Mayor receives YAML prompts, returns structured output | Medium — prompt/schema coupling |
| **Beads (Dolt)** | Task tracking | `bd create` generates beads from build card tasks | Low — stable CLI interface |
| **Convoy system** | Batch dispatch | `gt convoy stage` + `gt convoy launch` from task DAG | High — convoy semantics must match Rally's dependency model |
| **Polecat lifecycle** | Work execution | Standard `gt sling` → polecat workflow | Low — no changes needed |

### 1.2 Integration Architecture

```
Rally CLI Layer              Gas Town Layer
─────────────────           ──────────────────

rally init                  (standalone — no GT dependency)
rally plan                  → Mayor (Claude) executes skills
  rally-skill.sh            → Mayor reads YAML prompt, returns structured output
  rally-resolve.sh          → Local YAML search (no GT dependency)
rally dispatch              → bd create (beads)
                            → gt convoy stage (convoy creation)
                            → gt convoy launch (wave dispatch)
rally receipt               → git log, build artifacts (no GT dependency)
rally feedback              → Local analysis (no GT dependency)
```

**Key insight:** Only three Rally commands touch Gas Town:
1. `rally-skill.sh` — needs the Mayor (Claude) as execution engine
2. `rally dispatch` — needs `bd` CLI for bead creation
3. `rally dispatch` — needs `gt convoy` for batch orchestration

Everything else is local YAML processing. This is a good separation.

### 1.3 Integration Risks

**Risk 1: Skill → Mayor coupling.** The plan says "The Mayor IS the execution
engine — Rally just structures what it asks for and validates what it gets back."
This means skill execution depends on Claude's availability and output quality.
If Claude's response doesn't match the expected YAML schema, the pipeline stalls.

**Mitigation:** The plan includes "Skill output validation (ensures structured
data, not narrative)" in Feature 01. This is necessary but insufficient — Rally
should also handle partial/malformed output gracefully (retry with feedback,
not hard fail).

**Risk 2: Convoy dependency model mismatch.** Rally's dependency graph (Feature 04
§4) uses a clean tree: PM → Architect → UX → etc. But Gas Town's convoy system
uses `blocks`, `conditional-blocks`, and `waits-for` relationships with specific
filtering rules (only slingable types dispatch: task, bug, feature, chore — not
epics or decisions). Rally must generate beads with the correct `issue_type` and
dependency relationships, or convoy feeding will skip them.

**Mitigation:** Feature 17 (Mayor Integration) must understand Gas Town's convoy
feeding logic, particularly:
- `feedNextReadyIssue()` — event-driven dispatch on bead close
- `feedFirstReady()` — stranded scan for ready but unassigned work
- Type filtering — only `task`, `bug`, `feature`, `chore` are slingable

**Risk 3: Dolt fragility.** Rally generates beads via `bd create`, which writes
to Dolt. The CLAUDE.md warns that Dolt "is fragile" and can hang. A `rally dispatch`
that creates 20+ beads in rapid succession could stress the Dolt server.

**Mitigation:** Batch bead creation with brief pauses, or use `bd` in a
transactional mode if available. Consider creating all beads in a single Dolt
transaction rather than individual `bd create` calls.

### 1.4 Interface Contracts

Rally should define explicit contracts at each integration boundary:

| Boundary | Contract | Format |
|----------|----------|--------|
| Skill → Mayor | Prompt template + output schema | YAML in/out |
| Dispatch → Beads | Bead creation fields | `bd create` CLI args |
| Dispatch → Convoy | Convoy staging input | `gt convoy stage <epic>` |
| Receipt → Git | Commit log, file stats | `git log` output parsing |

---

## 2. Skill Execution Architecture

### 2.1 Design Analysis

The plan describes a clean execution model:

```
skill.yaml (definition)
    + project-profile.yaml (input)
    → rally-skill.sh (runner)
        → Mayor/Claude (execution engine)
            → structured YAML output
                → schema validation
                    → saved artifact
```

**Strengths:**
- Skills are declarative (YAML), not imperative (code). This makes them
  auditable, version-controlled, and composable.
- The Mayor (Claude) is the only execution engine — no custom runtime.
- Output validation ensures deterministic structure even from non-deterministic
  LLM output.

**Weaknesses:**
- **No skill versioning scheme.** Skills will evolve. The plan doesn't describe
  how to handle version incompatibilities between skill definitions and existing
  build cards generated by older versions.
- **No error taxonomy.** When a skill fails, what happens? The plan mentions
  validation but not retry, fallback, or partial-success handling.
- **Chaining semantics are underspecified.** "Skill chaining (output of one feeds
  input of next)" — but what if an upstream skill produces output that the
  downstream skill can't consume? The plan needs explicit chaining contracts.

### 2.2 Skill Schema Requirements

Based on the plan's implicit requirements, each skill YAML needs:

```yaml
# Minimum viable skill schema
name: product-manager
version: 1.0.0
description: "Defines MVP scope from project profile"

input:
  required:
    - project-profile     # Path to project-profile.yaml
  optional:
    - previous-analysis   # Output from upstream skill (for chaining)

prompt:
  system: |
    You are a product manager analyzing a project profile...
  user: |
    Given this project profile:
    {{project-profile}}

    Produce the following structured output...

output:
  format: yaml
  schema:
    problem_statement: string
    success_metrics: list[string]
    non_goals: list[string]
    acceptance_criteria: list[object]

  validation:
    required_fields: [problem_statement, success_metrics]
    max_narrative_ratio: 0.3   # At most 30% free text
```

### 2.3 Skill Chaining Model

The plan specifies this execution order for `rally plan`:
```
PM → OSS → Architecture → Security → Brand → Architect → Librarian
```

Each skill's output must be available to downstream skills. Two approaches:

**Option A: File-based pipeline** (recommended — matches bash/YAML pattern)
```
rally-skill.sh pm → /tmp/rally-build/01-pm.yaml
rally-skill.sh oss --context /tmp/rally-build/ → /tmp/rally-build/02-oss.yaml
rally-skill.sh architect --context /tmp/rally-build/ → /tmp/rally-build/03-arch.yaml
...
rally-plan.sh assembles all → build-card.yaml
```

**Option B: In-memory piping** (not recommended — loses intermediate state)
```
rally-skill.sh pm | rally-skill.sh oss | rally-skill.sh architect
```

Option A is better because:
- Intermediate artifacts are inspectable for debugging
- A failed skill doesn't lose upstream work
- Skills can be re-run individually
- Matches the plan's "artifact-driven workflow" philosophy

### 2.4 Skill ↔ Mayor Communication

The plan says skills are "YAML definitions containing structured prompts and
output schemas" fed to "the Mayor (Claude)." But the plan doesn't specify the
actual mechanism:

**Question:** Does `rally-skill.sh` invoke Claude directly (via API or
`claude` CLI), or does it go through the Gas Town Mayor agent?

**Analysis:** Given that:
- Rally Tavern is a rig with its own Mayor instance
- The Mayor already has a tmux session and lifecycle
- Skills need Claude's LLM capabilities but NOT the Mayor's orchestration

**Recommendation:** `rally-skill.sh` should invoke Claude directly (via the
`claude` CLI or API), NOT through the Mayor. The Mayor's role is orchestration
(dispatch, convoy management). Skill execution is a pure LLM call with structured
I/O — routing it through the Mayor adds unnecessary indirection and coupling.

If the Mayor needs to invoke skills during planning, it calls `rally-skill.sh`
as a subprocess — the skill runner is a tool, not a peer.

---

## 3. Component Resolution Algorithm

### 3.1 Algorithm Design

The plan defines a 5-factor scoring algorithm (Feature 12):

```
Score = f(
  1. Required facet compatibility    → hard filter (pass/fail)
  2. Optional facet compatibility    → weighted score (0-1)
  3. Stability score                 → version maturity (0-1)
  4. Reuse count                     → usage frequency (0-1)
  5. Trust tier                      → verified/community/experimental (0-1)
)
```

### 3.2 Detailed Algorithm Specification

**Phase 1: Hard Filter (Required Facets)**

```
for each component C in registry:
  for each required facet F in project-profile:
    if C.provides does not include F:
      EXCLUDE C
    if C.compatibility excludes F:
      EXCLUDE C
```

Example: Project requires `platform: ios` and `language: swift`. A component
with `compatibility: [python, javascript]` is excluded regardless of score.

**Phase 2: Weighted Scoring (Optional Facets)**

```
optional_score(C) = sum(
  weight[f] * match(C, f)
  for f in optional_facets
) / sum(weight[f] for f in optional_facets)
```

Where `match(C, f)` returns 1.0 for exact match, 0.5 for partial match
(e.g., compatible but not primary), 0.0 for no match.

**Phase 3: Stability Score**

```
stability(C) = normalize(
  version_major * 0.6 +
  age_months * 0.2 +
  has_tests * 0.2
)
```

Components at v1.0+ with tests and >3 months age score highest.

**Phase 4: Reuse Count**

```
reuse(C) = min(C.usage_count / 10, 1.0)
```

Caps at 10 uses. Prevents popular components from dominating over
better-fit alternatives.

**Phase 5: Trust Tier**

```
trust(C) = {
  verified:     1.0,    # Team-reviewed, production-tested
  community:    0.6,    # Contributed, used by others
  experimental: 0.3     # New, unvalidated
}
```

**Final Score:**

```
score(C) = (
  optional_score * 0.35 +
  stability      * 0.25 +
  reuse          * 0.15 +
  trust          * 0.25
)
```

### 3.3 Scalability Considerations

The plan notes: "Git search is sufficient for <100 components." This is correct
for MVP. The resolution algorithm operates on `registry.yaml` (a flat YAML index)
loaded into memory, with per-component `manifest.yaml` read on demand.

**Performance model:**
- Registry load: O(n) where n = component count
- Hard filter: O(n × f) where f = required facets
- Scoring: O(k × g) where k = surviving components, g = all facets
- Sort: O(k log k)

For n < 100, this completes in milliseconds via `yq` + bash. No optimization
needed at MVP scale.

**Future scaling path:** If component count exceeds 100, migrate the registry
to a Dolt table with indexed facet columns. The manifest schema remains the
same — only the query layer changes.

### 3.4 "No Match" Handling

The plan says: "Handles 'no match' → marks as build candidate." This is
important — when no component satisfies a capability need, Rally should:

1. Record the unmet need in the build card as a `build_candidate`
2. Include the capability description and facet requirements
3. After implementation, prompt the developer to register the new code as a
   component (closing the feedback loop)

---

## 4. Mayor Bridge Design (Feature 17)

### 4.1 Convoy Bridge Architecture

Feature 17 converts Rally's build card into Gas Town's dispatch primitives:

```
build-card.yaml
    → rally dispatch
        → Parse execution plan
        → Generate bead graph
            → bd create (per task)
            → bd dep add (dependency wiring)
        → Stage convoy
            → gt convoy stage <epic>
        → Launch
            → gt convoy launch <convoy-id>
```

### 4.2 Build Card → Bead Mapping

Each task in the build card becomes a bead. The mapping:

| Build Card Field | Bead Field | Notes |
|-----------------|------------|-------|
| task.title | bead.title | Direct map |
| task.description | bead.description | Include acceptance criteria |
| task.category | bead.issue_type | Must be slingable: task, bug, feature, chore |
| task.complexity | bead.priority | 1-5 inverse mapping |
| task.dependencies | bead.deps (blocks) | Use `bd dep add` |
| task.acceptance_criteria | bead.notes | Structured in description |

**Critical constraint:** The convoy system only dispatches slingable types
(`task`, `bug`, `feature`, `chore`). Rally must NOT generate beads with
`issue_type: epic` or `issue_type: decision` for executable work items —
these will be silently skipped by convoy feeding.

### 4.3 Dependency Graph → Convoy Waves

Rally's dependency graph must translate to convoy waves. The convoy system
already handles this via `gt convoy stage`:

```
gt convoy stage <epic-bead>
```

This command:
1. Walks the dependency DAG from the epic
2. Computes waves (topological sort by dependency depth)
3. Creates a staged convoy with wave metadata
4. Validates no circular dependencies

Rally should create a root epic bead, then create task beads with
dependencies pointing to it and each other. Then `gt convoy stage` handles
wave computation automatically.

**Wave computation example from Rally's plan:**
```
Wave 1: PM task (no deps)
Wave 2: OSS + Architecture tasks (depend on PM)
Wave 3: Security + UX tasks (depend on Architecture)
Wave 4: Implementation tasks (depend on all above)
```

### 4.4 Traceability

The plan says: "Links beads back to build card for traceability." Implementation:

Each generated bead should include in its description:
```yaml
# Auto-generated by rally dispatch
source_build_card: path/to/build-card.yaml
source_task_id: task-03
generated_at: 2026-03-03T12:00:00Z
```

This enables:
- Auditing which build card produced which beads
- Debugging failed dispatches
- Receipt generation (Feature 15) can correlate bead outcomes to plan

### 4.5 Convoy Bridge Risks

**Risk 1: Bead explosion.** A complex build card could generate 30+ beads.
This creates convoy management overhead and Dolt write pressure.

**Mitigation:** Rally should aggregate related tasks into composite beads
where appropriate. A single bead can contain multiple acceptance criteria.
Aim for 8-15 beads per convoy, not 30+.

**Risk 2: Dependency cycles.** If the build card's dependency graph has
cycles (e.g., due to skill output errors), `gt convoy stage` will reject it.

**Mitigation:** `rally dispatch` should validate the DAG is acyclic before
calling `gt convoy stage`. Fail fast with a clear error.

**Risk 3: Partial dispatch failure.** If `bd create` succeeds for 10 beads
but fails on bead 11 (Dolt issue), the convoy has incomplete state.

**Mitigation:** Create all beads first, verify all IDs, then stage the
convoy. If any creation fails, clean up created beads before reporting
error. Consider a two-phase approach: create → verify → stage.

---

## 5. Cross-Cutting Concerns

### 5.1 Error Recovery

The plan lacks a unified error recovery strategy. Rally needs:

| Failure Point | Recovery Strategy |
|--------------|-------------------|
| Skill execution (Claude unavailable) | Retry with backoff, then skip skill with warning |
| Skill output validation failure | Retry with corrective feedback in prompt |
| Component resolution (no match) | Mark as build candidate, continue planning |
| Bead creation failure (Dolt) | Retry once, then abort dispatch with cleanup |
| Convoy staging failure | Report error, leave beads for manual dispatch |

### 5.2 Idempotency

`rally plan` should be idempotent — running it twice on the same project
should produce the same build card (modulo LLM non-determinism). This means:
- Overwrite existing build card, don't append
- Use deterministic skill ordering
- Cache skill outputs for same-session reruns

`rally dispatch` should NOT be idempotent — running it twice creates duplicate
beads. Add a guard: check if a convoy already exists for this build card.

### 5.3 Existing Codebase Integration

Rally must coexist with the existing 44 scripts in `scripts/`. The `lib/common.sh`
library provides shared utilities (logging, YAML parsing, ID generation, timestamps)
that Rally scripts should reuse. New Rally scripts should:
- Source `lib/common.sh` for consistency
- Use `log_info`, `log_success`, `log_warn`, `log_error` for output
- Use `require_file`, `yaml_get`, `generate_id`, `timestamp` utilities
- Follow the same `set -euo pipefail` strict mode

### 5.4 Testing Strategy

The plan doesn't address testing for Rally itself. Recommendations:
- Unit tests for component resolution scoring (bash test functions)
- Integration tests for skill → validation pipeline (mock Claude responses)
- End-to-end test for `rally plan` with a sample project profile
- Validate generated YAML against schemas with `yq`

---

## 6. Summary of Recommendations

### Must-Have for MVP

1. **Explicit skill schema** with versioning, input/output contracts, and
   validation rules (Section 2.2)
2. **File-based skill pipeline** with inspectable intermediate artifacts (Section 2.3)
3. **Direct Claude invocation** from `rally-skill.sh`, not through Mayor (Section 2.4)
4. **Slingable type constraint** enforcement in bead generation (Section 4.2)
5. **Two-phase dispatch** (create → verify → stage) for robustness (Section 4.5)
6. **Reuse `lib/common.sh`** for all new Rally scripts (Section 5.3)

### Should-Have for MVP

7. **DAG validation** before convoy staging (Section 4.5)
8. **Bead aggregation** to limit convoy size to 8-15 beads (Section 4.5)
9. **Idempotency guard** on `rally dispatch` (Section 5.2)
10. **Error taxonomy** for skill execution failures (Section 2.1)

### Nice-to-Have (Post-MVP)

11. **Skill versioning** with backward compatibility (Section 2.1)
12. **Dolt-backed component registry** for >100 components (Section 3.4)
13. **Build receipt → component promotion** feedback loop (Section 3.4)
14. **Retry with corrective feedback** for skill validation failures (Section 5.1)
