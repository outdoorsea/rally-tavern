# Rally System — Consolidated Analysis

> Synthesized from Architecture (rt-06gx) and Feasibility (rt-3ih3) analyses
> Date: 2026-03-03 | Consolidated by: Mayor

---

## 1. Revised MVP Scope (8 features, down from 11)

**Drop Features 11, 12, 13 (Component System) from MVP.**

| Feature | Status | Rationale |
|---------|--------|-----------|
| 00 Project Profile | **MVP** | Input to everything |
| 01 Skill Framework | **MVP** | Execution engine |
| 02 PM Skill | **MVP** | Validates framework |
| 03 Architect Skill | **MVP** | Core analysis |
| 05 OSS Researcher | **MVP** | Reuse-before-build |
| 06 Security Auditor | **MVP** | Threat modeling |
| 10 Build Card Generation | **MVP** | The deliverable |
| 14 Stack Defaults | **MVP** | Low effort, high value (pure data) |
| 11 Component Manifest | **DEFER** | No consumer in MVP |
| 12 Resolution Engine | **DEFER** | Empty registry, high shell complexity |
| 13 Component Registry | **DEFER** | Premature infrastructure |

**Why:** The component system has zero callers in MVP. The Librarian Skill (09)
is the only consumer and it's outside MVP. Building a multi-factor scoring
algorithm for an empty registry is premature.

---

## 2. Critical Prerequisites (Before Feature 01)

### A. Define Concrete Skill YAML Schema

Both analyses flagged this. The plan says "YAML with structured prompts and
output schemas" but doesn't define the actual format. Required:

```yaml
# skills/<name>.yaml — minimum viable schema
name: product-manager
version: 1
description: "Defines MVP scope from project profile"

input:
  required:
    - project-profile     # Path to project-profile.yaml
  optional:
    - previous-analysis   # Output from upstream skill

prompt:
  system: |
    You are a product manager analyzing a project profile...
  user: |
    Given this project profile:
    {{project-profile}}
    Produce the following structured output...

output:
  format: yaml
  required_keys:
    - problem_statement
    - success_metrics
    - mvp_scope
    - non_goals
    - acceptance_criteria
```

### B. Establish YAML Construction Pattern

Multiple features need to *construct* YAML. The existing `yaml_get()` in
`common.sh` uses `grep "^key:"` — only reads flat YAML. Options:
- `yq` for all YAML construction (recommended)
- Small `yaml_emit()` helper in `common.sh`

Decide before Feature 01 ships.

---

## 3. Architecture Decisions (Agreed)

### A. File-Based Skill Pipeline

```
rally-skill.sh pm → /tmp/rally-build/01-pm.yaml
rally-skill.sh oss --context /tmp/rally-build/ → /tmp/rally-build/02-oss.yaml
rally-skill.sh architect --context /tmp/rally-build/ → /tmp/rally-build/03-arch.yaml
...
rally-plan.sh assembles all → build-card.yaml
```

Why: Intermediate artifacts are inspectable, failures don't lose upstream work,
skills can be re-run individually.

### B. Direct Claude Invocation (Not Through Mayor)

`rally-skill.sh` should invoke Claude directly via `claude` CLI or API.
The Mayor's role is orchestration — skill execution is a pure LLM call with
structured I/O. Routing through Mayor adds unnecessary indirection.

### C. Build Card Tolerant of Missing Skills

Build Card Generation (Feature 10) must handle missing skills gracefully:
- Run whatever skills are available
- Mark missing sections as `status: not_available`
- This decouples Build Card from the full skill roster

### D. Reuse `lib/common.sh`

All new Rally scripts should source `lib/common.sh` for logging, YAML parsing,
ID generation, timestamps. Follow existing `set -euo pipefail` strict mode.

---

## 4. Corrected Dependency Table

| Feature | Plan Says | Corrected |
|---------|-----------|-----------|
| 09 Librarian | 01, 12 | 01, 12, **13** |
| 10 Build Card | 02, 03, 04, 05, 06, 09 | 02, 03, 05, 06 (hard); 04, 09 (optional) |
| 15 Build Receipts | 17 | **(none)** — can work standalone |

---

## 5. Integration Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Skill → Claude coupling (output schema mismatch) | Medium | Shallow validation in MVP, retry with feedback later |
| Convoy dependency model mismatch | High | Enforce slingable types (task/bug/feature/chore), validate DAG before staging |
| Dolt fragility under batch bead creation | Medium | Two-phase dispatch: create → verify → stage |
| Shell complexity for Build Card orchestration | Medium-High | Consider Python/yq for YAML assembly if >200 lines |

---

## 6. Shell Complexity Assessment

| Feature | Risk | Mitigation |
|---------|------|------------|
| 01 Skill Framework (validation) | Medium | Shallow validation only in MVP |
| 10 Build Card (skill chaining) | Medium-High | File-based pipeline, consider yq helper |
| 12 Resolution Engine (scoring) | High | **Deferred from MVP** |
| General YAML construction | Medium | Establish pattern early (yq) |

---

## 7. Revised Implementation Order

### Phase 1: Foundation
- **14 Stack Defaults** — Pure data, easiest, good test fixture
- **00 Project Profile Schema** — Input to everything

### Phase 2: Skill Engine
- **01 Skill Framework** — Core execution engine (define schema first!)

### Phase 3: Core Skills (parallelizable)
- **02 PM Skill** — First skill, validates framework
- **03 Architect Skill** — Core analysis
- **05 OSS Researcher** — Reuse-before-build
- **06 Security Auditor** — Threat modeling

### Phase 4: Orchestration
- **10 Build Card Generation** — Chains skills into deliverable

### Post-MVP
- Component System (11, 12, 13)
- Remaining Skills (04, 07, 08, 09)
- Mayor Integration (17, 18)
- Feedback Loop (15, 16)

---

## 8. Testing Strategy (Gap)

The plan lacks testing. Minimum for MVP:
- Unit tests for YAML parsing/construction helpers
- Integration tests for skill execution (mock Claude, verify output validation)
- End-to-end test for `rally plan` with sample project profile
- Validate generated YAML against schemas with `yq`
