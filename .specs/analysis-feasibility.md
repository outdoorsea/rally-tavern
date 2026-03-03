# Rally System — Feasibility & MVP Scope Review

> Analysis of `.specs/plan.md` for Rally Tavern
> Reviewer: polecat/chrome (rt-3ih3)
> Date: 2026-03-03

---

## 1. MVP Boundary Validity

### What the plan proposes

MVP = Phases 1–3 + Feature 10 (11 features):
00 Project Profile, 01 Skill Framework, 02 PM Skill, 03 Architect Skill,
05 OSS Researcher, 06 Security Auditor, 10 Build Card Generation,
11 Component Manifest, 12 Resolution Engine, 13 Component Registry, 14 Stack Defaults.

### Assessment: MVP is too wide

**The component system (11, 12, 13) should not be in MVP.** Rationale:

1. **No consumer yet.** Build Card Generation (10) does not depend on
   the component system. The Librarian Skill (09) — which queries
   components — is explicitly *outside* MVP. So the component registry
   would ship with zero callers.

2. **The plan acknowledges <100 components.** At MVP there will be zero
   components. Building resolution scoring (multi-factor weighted
   algorithm, trust tiers, reuse counts) for an empty registry is
   premature infrastructure.

3. **Seed components are speculative.** The plan proposes 3 seed
   components (auth, CRUD API, test harness) but doesn't specify which
   stacks they target. Creating them before any project has used Rally
   means guessing at what reusable components look like.

**Recommended MVP (8 features instead of 11):**

| In MVP | Feature | Rationale |
|--------|---------|-----------|
| Yes | 00 Project Profile | Input to everything |
| Yes | 01 Skill Framework | Execution engine |
| Yes | 02 PM Skill | Validates framework |
| Yes | 03 Architect Skill | Core analysis |
| Yes | 05 OSS Researcher | Reuse-before-build |
| Yes | 06 Security Auditor | Threat modeling |
| Yes | 10 Build Card Generation | The deliverable |
| Yes | 14 Stack Defaults | Low effort, high value |
| **Defer** | 11 Component Manifest | No consumer in MVP |
| **Defer** | 12 Resolution Engine | Empty registry |
| **Defer** | 13 Component Registry | Premature |

This tighter MVP validates the core value proposition — structured
planning via skills producing a build card — without building
infrastructure that has no users yet. Features 11-13 can ship as a
single "Component System" phase after the first build card has been
used in production and real reuse patterns emerge.

---

## 2. Dependency Ordering

### Issues Found

**A. Feature 09 (Librarian) dependency is understated.**
The plan says Librarian depends on 01 and 12. But it also needs 13
(Component Registry) to have populated data. The dependency table
should list `09 → {01, 12, 13}`.

**B. Feature 10 (Build Card) dependency list is fragile.**
Build Card depends on {02, 03, 04, 05, 06, 09}. But 04 (UX) and 09
(Librarian) are in Phase 4 — *after* the phase where Build Card ships
(Phase 5). This means Build Card Generation must handle missing skills
gracefully (skip UX/Librarian sections if those skills aren't
installed). The plan doesn't specify this — it just lists them as
dependencies.

**Recommendation:** Make Build Card Generation tolerant of missing
skills. Run whatever skills are available, mark missing sections as
`status: not_available`. This decouples Build Card from the full
skill roster and lets it ship in MVP with only PM + Architect + OSS +
Security.

**C. The linear phase ordering hides parallelism.**
Phase 2 (Skills 02, 03, 05, 06) and Phase 3 (Components 11, 12, 13)
have no mutual dependencies. They could be built in parallel by
different polecats. The plan presents them as sequential phases, which
may cause unnecessary serialization during dispatch.

**D. Feature 15 (Build Receipts) depending on 17 (Mayor Integration)
is questionable.** Receipts capture post-build metrics. They could work
standalone (reading git logs, build output) without Mayor Integration.
The dependency seems artificial — receipts don't need convoy dispatch
to collect metrics from a completed build.

### Corrected Dependency Table

| Feature | Plan Says | Should Be |
|---------|-----------|-----------|
| 09 Librarian | 01, 12 | 01, 12, 13 |
| 10 Build Card | 02, 03, 04, 05, 06, 09 | 02, 03, 05, 06 (hard); 04, 09 (optional) |
| 15 Build Receipts | 17 | (none) — can work standalone |

---

## 3. Shell Script Complexity Risks

### Current codebase context

The repo has 42 bash scripts averaging ~50 lines each. They follow a
consistent pattern: `source lib/common.sh`, use `case` dispatch,
simple YAML via `grep`/`sed`. The `common.sh` library provides colors,
logging, basic YAML extraction (`yaml_get` via grep), and ID
generation.

### Where shell will struggle

**A. Skill Framework (Feature 01) — YAML schema validation.**

The plan proposes `yq + bash` for validation. This works for flat
key-value YAML but breaks down for:
- Nested structures (skill definitions have output schemas with types)
- Array validation (checking each element matches a schema)
- Cross-field constraints ("if platform is ios, framework must be
  swiftui")

The existing `yaml_get()` in `common.sh` uses `grep "^key:"` — it
cannot parse nested YAML at all. Even `yq` requires careful quoting
and error handling that becomes verbose in bash.

**Risk level: MEDIUM.** Mitigation: Keep validation shallow in MVP.
Validate top-level required keys exist. Don't try to validate nested
output schemas in bash — let the LLM's structured output handle
schema conformance. Add deep validation later if needed (possibly in
Python).

**B. Build Card Generation (Feature 10) — Skill chaining.**

Orchestrating 4-6 skills sequentially, passing outputs between them,
assembling a combined YAML document, and validating completeness is the
most complex bash script in the plan (rated 4/5). Comparable complexity
in the existing codebase is `board.sh` (~80 lines) and `postmortem.sh`
(~100 lines), neither of which does multi-stage YAML assembly.

**Risk level: MEDIUM-HIGH.** This script will likely reach 200-300
lines. Bash can handle it but it will be the most complex script in
the repo by 3x. Consider whether `rally-plan.sh` should delegate
YAML assembly to a helper (Python one-liner, or `yq eval-all`).

**C. Component Resolution (Feature 12) — Multi-factor scoring.**

The plan describes a 5-factor scoring algorithm (required facets,
optional facets, stability, reuse count, trust tier). Implementing
weighted scoring with floating-point math in bash requires `bc` or
`awk`. The result will be fragile and hard to test.

**Risk level: HIGH (if in MVP).** Since we recommend deferring this,
the risk is mitigated. If built later, consider Python for the scoring
logic.

**D. General concern: YAML assembly without a proper library.**

Multiple features need to *construct* YAML, not just read it. The
existing scripts write YAML via `echo "key: value" >> file`, which
works for flat structures. Build cards and skill outputs have nested
maps and arrays. Generating valid nested YAML from bash is error-prone
(indentation bugs, quoting issues, special characters).

**Recommendation:** Create a small `yaml_emit()` helper in
`common.sh` that handles indentation and quoting. Or accept that
YAML construction will use `yq` exclusively. Either way, establish
the pattern before Feature 01 ships.

### Summary of shell risks

| Feature | Risk | Mitigation |
|---------|------|------------|
| 01 Skill Framework | Medium | Shallow validation only in MVP |
| 10 Build Card | Medium-High | Consider Python/yq for YAML assembly |
| 12 Resolution Engine | High | Defer from MVP |
| General YAML construction | Medium | Establish `yaml_emit` pattern early |

---

## 4. YAML Schema Design

### What the plan defines

Four key YAML artifacts: `project-profile.yaml`, `build-card.yaml`,
`component manifest.yaml`, `build_receipt.yaml`. Plus skill definitions
and stack defaults.

### Issues Found

**A. No schema validation strategy.**

The plan says "yq + bash" for validation but doesn't specify:
- Where schema definitions live (inline in scripts? Separate schema files?)
- What validation tool to use (`yq` can check structure but isn't a
  schema validator; `ajv` works for JSON Schema; there's no standard
  YAML schema tool in the bash ecosystem)
- Whether to validate on read, write, or both

**Recommendation:** Use a convention-based approach:
1. Each schema has a `templates/<artifact>.yaml` file with comments
   marking required fields (already established pattern — see
   `templates/bounty.yaml`)
2. Validation scripts check for required top-level keys via `grep`
   (matches existing `validate.sh` pattern)
3. Don't attempt deep schema validation in bash — it's not worth the
   complexity for an LLM-driven workflow where the Mayor produces
   structured output

**B. Skill definition schema is underspecified.**

The plan mentions "YAML with structured prompts and output schemas" but
doesn't define what a skill YAML looks like. Key questions:

- How are prompts structured? (instructions + task prompt? template
  variables?)
- How are output schemas defined? (JSON Schema subset? Required keys
  list? Example output?)
- How does skill chaining work? (does output of skill A become input
  to skill B? What's the interface contract?)

This is the most important schema in the system and it needs to be
defined before Feature 01 can be implemented.

**Recommendation:** Define a concrete skill schema in the plan. Example:

```yaml
# skills/product-manager.yaml
name: product-manager
version: 1
description: Defines MVP scope from project profile

input:
  required:
    - project-profile    # References project-profile.yaml
  optional:
    - previous-build-card

prompt:
  instructions: |
    Act as a product manager analyzing a project profile...
  task: |
    Analyze this project profile and produce...

output:
  format: yaml
  required_keys:
    - problem_statement
    - success_metrics
    - mvp_scope
    - non_goals
    - acceptance_criteria

  # Each key's expected structure (for documentation, not deep validation)
  structure:
    problem_statement: string
    success_metrics: list[string]
    mvp_scope: list[{feature: string, rationale: string}]
```

**C. Build card schema composition is unclear.**

The build card assembles outputs from multiple skills. But the plan
doesn't specify:
- Whether skill outputs are embedded directly or referenced
- How conflicts between skills are resolved (e.g., architect says "use
  microservices" but PM says "keep it simple")
- Whether the build card has its own validation beyond "all sections
  present"

**Recommendation:** Build card should be a simple concatenation of
skill outputs under namespaced keys:

```yaml
# build-card.yaml
project: my-project
generated_at: 2026-03-03T12:00:00Z
skills_run: [product-manager, architect, oss-researcher, security-auditor]

product_manager:
  problem_statement: ...
  success_metrics: ...

architect:
  risks: ...
  entity_model: ...

oss_researcher:
  candidates: ...

security_auditor:
  threats: ...
```

No conflict resolution — that's the human/overseer's job when
reviewing the build card.

**D. Naming inconsistency.**

The plan uses `component manifest.yaml` (space in filename) in the
artifacts table but `manifest.yaml` in the directory layout. Filenames
should never contain spaces. Use `manifest.yaml`.

---

## 5. Additional Observations

### A. Skill execution model is sound

The insight that "the Mayor IS the execution engine" is correct and
elegant. Skills as structured prompts + output schemas is the right
abstraction for an LLM-driven system. The skill runner just needs to:
1. Load the skill YAML
2. Load the project profile
3. Compose a prompt
4. Call the Mayor (Claude)
5. Validate the output has required keys
6. Save to disk

This is ~50-80 lines of bash — well within the repo's comfort zone.

### B. OSS Researcher needs web access

Feature 05 (OSS Researcher) "evaluates candidates against project
facets" and does "web search integration." But the skill execution
model feeds everything through the Mayor (Claude). Claude can do web
search, so this works — but the skill definition should explicitly
note that this skill requires web search capability. Skills that work
offline vs. those requiring network access should be tagged.

### C. Stack Defaults (Feature 14) is pure data

This is the easiest feature — just YAML files with no code. It could
be built first and used as test data for the profile schema. Good
candidate for a polecat's first task.

### D. Testing strategy is absent

The plan has 19 features but no testing strategy. The existing repo has
`tests/test_bounties.sh` (a bash test). Rally scripts should have:
- Unit tests for `yaml_get`/`yaml_emit` helpers
- Integration tests for skill execution (mock the LLM call, verify
  output validation)
- End-to-end test for `rally plan` with a sample project profile

This should be called out in the plan, even if testing details are
deferred.

---

## 6. Summary of Recommendations

| # | Recommendation | Priority |
|---|----------------|----------|
| 1 | Narrow MVP to 8 features (drop 11, 12, 13) | High |
| 2 | Make Build Card tolerant of missing skills | High |
| 3 | Define concrete skill YAML schema before Feature 01 | High |
| 4 | Establish YAML construction pattern (yaml_emit or yq) | Medium |
| 5 | Fix Librarian dependency: add 13 | Medium |
| 6 | Decouple Build Receipts from Mayor Integration | Medium |
| 7 | Tag skills requiring network access | Low |
| 8 | Add testing strategy section to plan | Low |
| 9 | Fix naming: "component manifest.yaml" → "manifest.yaml" | Low |
| 10 | Allow parallel execution of Phases 2 and 3 | Low |
