# Rally System - Development Plan

> Agent-First Planning, Skill Orchestration, and Component Reuse for Gas Town

## 1. Project Overview

Rally is a planning, design, and reuse layer that extends Gas Town's Mayor with
structured project planning, skill-based execution, component resolution, and
continuous feedback. It transforms the idea-to-code pipeline from ad-hoc prompting
into a deterministic, artifact-driven workflow.

### What Rally Adds to Gas Town

| Gas Town Today | Rally Extension |
|----------------|-----------------|
| Mayor orchestrates ad-hoc | Mayor follows structured build cards |
| No planning phase | Planning Mode produces deterministic artifacts |
| No component reuse | Component registry with capability matching |
| No architecture review | Architecture critique before code |
| No security analysis | Threat modeling during planning |
| No abstraction enforcement | Auditor checks before merge |
| No build feedback | Receipts drive continuous improvement |

### Integration Points

```
                    ┌─────────────┐
                    │  Overseer   │  (human intent)
                    └──────┬──────┘
                           │ idea / project-profile.yaml
                    ┌──────▼──────┐
                    │   Rally     │  Planning Mode
                    │  ┌────────┐ │
                    │  │ Skills │ │  PM, Architect, UX, Security...
                    │  └────────┘ │
                    │  ┌────────┐ │
                    │  │Compnts │ │  Resolution Engine
                    │  └────────┘ │
                    └──────┬──────┘
                           │ build-card.yaml + tasks
                    ┌──────▼──────┐
                    │   Mayor     │  Orchestration (existing)
                    │  Convoys    │
                    └──────┬──────┘
                           │ beads → polecats
                    ┌──────▼──────┐
                    │   Rigs      │  Execution (existing)
                    │  Polecats   │
                    └──────┬──────┘
                           │ code + tests
                    ┌──────▼──────┐
                    │  Feedback   │  build_receipt.yaml
                    └─────────────┘
```

### Key Artifacts

| Artifact | Purpose | When Created |
|----------|---------|--------------|
| `project-profile.yaml` | Project facets, needs, constraints | Project init |
| `build-card.yaml` | Planning output (scope, risks, plan) | Planning Mode |
| `component manifest.yaml` | Reusable module metadata | Component authoring |
| `build_receipt.yaml` | Build feedback and metrics | After each build |

---

## 2. Tech Stack Decisions

### Primary: Shell Scripts + YAML

Rally follows Gas Town's existing pattern: bash scripts with YAML artifacts,
stored in git. No server, no database beyond git and Dolt (for beads).

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| CLI commands | Bash scripts | Matches `gt`/`bd` pattern, 44 scripts already in `scripts/` |
| Artifact format | YAML | Machine-readable, git-friendly, matches existing schemas |
| Issue tracking | Beads (Dolt) | Already integrated, prefix-based routing |
| Component registry | YAML manifests in git | Local-first, version-controlled, searchable |
| Skill definitions | YAML + embedded prompts | Deterministic, auditable, composable |
| Validation | `yq` + bash | Lightweight schema validation |

### Why Not a Database for Components?

- **MVP scope**: Local-first, single-town. Git search is sufficient for <100 components.
- **Future**: If federation requires cross-town component sharing, add a Dolt table
  or SQLite index. The manifest schema won't change.

### Directory Layout (within Rally Tavern)

```
rally_tavern/
├── scripts/
│   ├── rally.sh            # Main entry point: `rally <command>`
│   ├── rally-plan.sh       # Planning Mode orchestrator
│   ├── rally-skill.sh      # Skill runner
│   ├── rally-resolve.sh    # Component resolution
│   ├── rally-receipt.sh    # Build receipt generator
│   └── rally-audit.sh      # Abstraction + security audit
├── skills/
│   ├── product-manager.yaml
│   ├── architect.yaml
│   ├── ux-designer.yaml
│   ├── librarian.yaml
│   ├── test-engineer.yaml
│   ├── oss-researcher.yaml
│   ├── security-auditor.yaml
│   └── abstraction-auditor.yaml
├── components/
│   ├── registry.yaml       # Index of all components
│   └── <component-name>/
│       ├── manifest.yaml
│       ├── template/
│       ├── tests/
│       └── integration_instructions.yaml
├── templates/
│   ├── project-profile.yaml
│   ├── build-card.yaml
│   └── build-receipt.yaml
├── defaults/
│   ├── stacks/
│   │   ├── python-web.yaml
│   │   ├── ios-swiftui.yaml
│   │   └── typescript-node.yaml
│   └── security-controls.yaml
└── docs/
    └── RALLY.md            # User-facing documentation
```

---

## 3. Feature List

### 00 - Project Profile Schema

Define the `project-profile.yaml` schema and initialization command.

**Delivers:**
- YAML schema for project facets, needs, and constraints
- `rally init` command that creates `project-profile.yaml` interactively
- Validation script for profile completeness
- Default facet vocabulary (platform, language, framework, auth, db, etc.)

**Complexity:** 2/5

---

### 01 - Skill Framework

Core infrastructure for defining and executing skills.

**Delivers:**
- Skill definition schema (YAML with structured prompts and output schemas)
- `rally skill run <skill-name> --profile <path>` command
- Skill output validation (ensures structured data, not narrative)
- Skill chaining (output of one feeds input of next)
- Skill registry and discovery (`rally skill list`)

**Complexity:** 3/5

---

### 02 - Product Manager Skill

First skill implementation. Defines MVP scope from project profile.

**Delivers:**
- `product-manager.yaml` skill definition
- Outputs: problem statement, success metrics, non-goals, acceptance criteria
- Reads project-profile.yaml as input
- Produces structured YAML section for build card

**Complexity:** 2/5

---

### 03 - Architect Skill

Architecture analysis and risk identification.

**Delivers:**
- `architect.yaml` skill definition
- Outputs: architecture risks, mitigation strategies, entity model, integration map
- Identifies abstraction boundaries
- Recommends component structure

**Complexity:** 3/5

---

### 04 - UX Designer Skill

Screen and interaction planning.

**Delivers:**
- `ux-designer.yaml` skill definition
- Outputs: screen inventory, user flows, brand profile (tone, audience, style)
- Maps screens to entities and capabilities

**Complexity:** 2/5

---

### 05 - OSS Researcher Skill

Open-source evaluation before building.

**Delivers:**
- `oss-researcher.yaml` skill definition
- Outputs: candidate packages, license analysis, maturity scores, recommendations
- Evaluates candidates against project facets
- Produces `oss_analysis` section for build card

**Complexity:** 2/5

---

### 06 - Security Auditor Skill

Threat modeling during planning.

**Delivers:**
- `security-auditor.yaml` skill definition
- Outputs: attack vectors, required controls, OWASP alignment
- Maps threats to architecture components
- Produces `security_review` section for build card

**Complexity:** 3/5

---

### 07 - Abstraction Auditor Skill

Enforces abstraction boundaries in code.

**Delivers:**
- `abstraction-auditor.yaml` skill definition
- Outputs: boundary violations, refactor recommendations
- Checks: external APIs isolated, DB behind repository, business logic separated
- Can run pre-merge as a gate

**Complexity:** 2/5

---

### 08 - Test Engineer Skill

Test strategy and generation guidance.

**Delivers:**
- `test-engineer.yaml` skill definition
- Outputs: test strategy, coverage targets, test categories (unit/integration/edge)
- Maps test requirements to entities and capabilities

**Complexity:** 2/5

---

### 09 - Component Librarian Skill

Manages component discovery and recommendations.

**Delivers:**
- `librarian.yaml` skill definition
- Outputs: component recommendations, compatibility scores, integration notes
- Queries component registry against project facets
- Produces `recommended_components` section for build card

**Complexity:** 2/5

---

### 10 - Build Card Generation (Planning Mode)

The orchestrator that chains skills into a complete build card.

**Delivers:**
- `rally plan <project-path>` command
- Runs skills in defined order: PM → OSS → Architecture → Security → Brand → Architect → Librarian
- Assembles outputs into `build-card.yaml`
- Validates completeness of build card
- Planning Mode must NOT modify code (read-only analysis)

**Complexity:** 4/5

---

### 11 - Component Manifest Schema

Define the component manifest format and validation.

**Delivers:**
- `manifest.yaml` schema (name, version, provides, compatibility, entrypoints)
- Component directory structure convention
- `rally component validate <path>` command
- Template for new components

**Complexity:** 2/5

---

### 12 - Component Resolution Engine

Capability-based component matching.

**Delivers:**
- `rally resolve <capability> --profile <path>` command
- Resolution scoring algorithm:
  1. Required facet compatibility (hard filter)
  2. Optional facet compatibility (weighted score)
  3. Stability score (version maturity)
  4. Reuse count (usage frequency)
  5. Trust tier (verified, community, experimental)
- Returns ranked list of compatible components
- Handles "no match" → marks as build candidate

**Complexity:** 3/5

---

### 13 - Component Registry

Searchable index of available components.

**Delivers:**
- `registry.yaml` central index
- `rally component add <path>` to register new components
- `rally component search <query>` for text search
- `rally component list --capability <cap>` for capability filter
- Initial seed: 3 starter components (auth, CRUD API, test harness)

**Complexity:** 3/5

---

### 14 - Opinionated Stack Defaults

Pre-configured stack recommendations by platform.

**Delivers:**
- Stack definition files in `defaults/stacks/`
- Python web: FastAPI + Postgres + Alembic + Pytest + Ruff
- iOS: SwiftUI + MVVM + Service layer + Repository protocol
- TypeScript Node: Express/Fastify + Prisma + Vitest
- `rally defaults <platform>` command to view/apply
- Extensible: users can add custom stack definitions

**Complexity:** 1/5

---

### 15 - Build Receipt System

Post-build feedback capture.

**Delivers:**
- `build_receipt.yaml` schema
- `rally receipt generate` command (auto-collects metrics from git/build)
- Tracks: tokens used, files changed, components used, abstraction score, test pass rate
- Receipt storage in project directory
- Receipt history for trend analysis

**Complexity:** 2/5

---

### 16 - Feedback Loop Engine

Continuous improvement from build receipts.

**Delivers:**
- `rally feedback analyze` command
- Identifies: frequently reinvented patterns, common architecture risks, reusable logic candidates
- Suggests: new components to extract, skill refinements, default updates
- Aggregates receipt data across builds
- Outputs improvement recommendations as YAML

**Complexity:** 3/5

---

### 17 - Mayor Integration (Convoy Bridge)

Connect Rally planning output to Mayor's convoy system.

**Delivers:**
- `rally dispatch <build-card>` command
- Converts build card execution plan into Gas Town beads
- Groups beads into convoys (PM → UX → Architect → Test → Dev)
- Respects convoy ordering and dependencies
- Links beads back to build card for traceability

**Complexity:** 4/5

---

### 18 - Execution Task Generation

Generate structured tasks from build card.

**Delivers:**
- `rally tasks generate <build-card>` command
- Produces `tasks.yaml` with categorized work items
- Task categories: PM, UX, Architecture, Test, Implementation
- Each task has: description, acceptance criteria, dependencies, estimated complexity
- Tasks are bead-compatible for direct dispatch

**Complexity:** 3/5

---

## 4. Dependency Graph

```
00 Project Profile Schema
 │
 ├──► 01 Skill Framework
 │     │
 │     ├──► 02 PM Skill ──────────────────┐
 │     ├──► 03 Architect Skill ───────────┤
 │     ├──► 04 UX Designer Skill ─────────┤
 │     ├──► 05 OSS Researcher Skill ──────┤
 │     ├──► 06 Security Auditor Skill ────┤
 │     ├──► 07 Abstraction Auditor Skill ─┤
 │     ├──► 08 Test Engineer Skill ───────┤
 │     └──► 09 Librarian Skill ───────────┤
 │                                        │
 ├──► 11 Component Manifest Schema        │
 │     │                                  │
 │     ├──► 12 Resolution Engine          │
 │     │     │                            │
 │     │     └──► 13 Component Registry   │
 │     │                                  │
 │     └──────────────────────────────────┤
 │                                        │
 └──► 14 Stack Defaults                   │
                                          │
                              ┌───────────▼──────────┐
                              │ 10 Build Card / Plan │
                              └───────────┬──────────┘
                                          │
                              ┌───────────▼──────────┐
                              │ 18 Task Generation   │
                              └───────────┬──────────┘
                                          │
                              ┌───────────▼──────────┐
                              │ 17 Mayor Integration │
                              └───────────┬──────────┘
                                          │
                              ┌───────────▼──────────┐
                              │ 15 Build Receipts    │
                              └───────────┬──────────┘
                                          │
                              ┌───────────▼──────────┐
                              │ 16 Feedback Loop     │
                              └──────────────────────┘
```

### Dependency Table

| Feature | Depends On |
|---------|-----------|
| 00 Project Profile | (none) |
| 01 Skill Framework | 00 |
| 02 PM Skill | 01 |
| 03 Architect Skill | 01 |
| 04 UX Designer Skill | 01 |
| 05 OSS Researcher Skill | 01 |
| 06 Security Auditor Skill | 01 |
| 07 Abstraction Auditor Skill | 01 |
| 08 Test Engineer Skill | 01 |
| 09 Librarian Skill | 01, 12 |
| 10 Build Card Generation | 02, 03, 04, 05, 06, 09 |
| 11 Component Manifest | 00 |
| 12 Resolution Engine | 11 |
| 13 Component Registry | 12 |
| 14 Stack Defaults | 00 |
| 15 Build Receipts | 17 |
| 16 Feedback Loop | 15 |
| 17 Mayor Integration | 10, 18 |
| 18 Task Generation | 10 |

---

## 5. Complexity Scores

| Feature | Score | Rationale |
|---------|-------|-----------|
| 00 Project Profile | 2/5 | YAML schema + simple init script |
| 01 Skill Framework | 3/5 | Schema design, runner, chaining, validation |
| 02 PM Skill | 2/5 | Single skill definition, clear output schema |
| 03 Architect Skill | 3/5 | Complex analysis, multiple output sections |
| 04 UX Skill | 2/5 | Structured output, moderate domain knowledge |
| 05 OSS Researcher | 2/5 | Web search integration, scoring |
| 06 Security Auditor | 3/5 | OWASP mapping, threat modeling structure |
| 07 Abstraction Auditor | 2/5 | Pattern matching against code structure |
| 08 Test Engineer | 2/5 | Test strategy templating |
| 09 Librarian | 2/5 | Registry query, compatibility scoring |
| 10 Build Card | 4/5 | Orchestrates all skills, validates completeness |
| 11 Component Manifest | 2/5 | YAML schema + validation |
| 12 Resolution Engine | 3/5 | Multi-factor scoring algorithm |
| 13 Component Registry | 3/5 | Index management, search, seed components |
| 14 Stack Defaults | 1/5 | Static YAML files |
| 15 Build Receipts | 2/5 | Metric collection, schema |
| 16 Feedback Loop | 3/5 | Aggregation, pattern detection, recommendations |
| 17 Mayor Integration | 4/5 | Convoy bridge, bead generation, dependency ordering |
| 18 Task Generation | 3/5 | Build card → tasks decomposition |

**Overall project complexity: 3/5** — Individually simple features, complexity
emerges from orchestration and integration.

---

## 6. Recommended Implementation Order

### Phase 1: Foundation (Features 00, 01, 14)

Build the schema and framework that everything else depends on.

1. **00 - Project Profile Schema** — The input to everything
2. **01 - Skill Framework** — The execution engine for skills
3. **14 - Stack Defaults** — Low-effort, high-value defaults

### Phase 2: Core Skills (Features 02, 03, 05, 06)

Implement the skills needed for a minimal build card.

4. **02 - PM Skill** — Defines scope (first skill, validates framework)
5. **05 - OSS Researcher** — Reuse-before-build philosophy
6. **03 - Architect Skill** — Architecture risks and structure
7. **06 - Security Auditor** — Threat modeling

### Phase 3: Component System (Features 11, 12, 13)

Stand up component infrastructure in parallel with remaining skills.

8. **11 - Component Manifest Schema** — Component format
9. **12 - Resolution Engine** — Capability matching
10. **13 - Component Registry** — Searchable index + 3 seed components

### Phase 4: Remaining Skills (Features 04, 07, 08, 09)

Complete the skill roster.

11. **04 - UX Designer** — Screen planning
12. **09 - Librarian** — Component recommendations (needs 12)
13. **07 - Abstraction Auditor** — Pre-merge gate
14. **08 - Test Engineer** — Test strategy

### Phase 5: Orchestration (Features 10, 18, 17)

Wire everything together into the planning pipeline.

15. **10 - Build Card Generation** — The main `rally plan` command
16. **18 - Task Generation** — Build card → tasks
17. **17 - Mayor Integration** — Tasks → convoys → polecats

### Phase 6: Feedback (Features 15, 16)

Close the loop.

18. **15 - Build Receipts** — Capture build metrics
19. **16 - Feedback Loop** — Aggregate and recommend improvements

---

## MVP Boundary

**MVP = Phases 1-3 + Feature 10** (Features 00, 01, 02, 03, 05, 06, 10, 11, 12, 13, 14)

This delivers:
- Project initialization with profiles
- Core skill execution (PM, Architect, OSS, Security)
- Build card generation from skills
- Component manifest + resolution + registry
- Opinionated stack defaults

**Not in MVP:** UX skill, abstraction auditor, test engineer, librarian,
mayor integration, task generation, build receipts, feedback loop.
These are valuable but the system is useful without them.

---

## Design Decisions & Rationale

### Characters

Rally Tavern has two named characters rooted in its Revolutionary War namesake:

**🍺 Barkeep** — the `rally_tavern` Mayor persona
The Barkeep tends the knowledge base. When agents interact with rally_tavern (searching,
contributing, approving), they are interacting with the Barkeep. The rally_tavern Mayor
adopts this identity. Gives the repo personality — you're asking the Barkeep, not querying
a database.

**📜 Historian** — the knowledge approval role
When a rig Mayor nominates a knowledge artifact (two-stage approval flow), the Historian
evaluates it before it enters the permanent record. The Historian is the rally_tavern Mayor
acting in review mode. Named for the Revolutionary War role of preserving ideas for
posterity — the Barkeep served the revolutionaries; the Historian made sure their work
survived.

These characters appear in:
- CLI output from `rally` scripts (`The Historian has reviewed...`)
- The rally_tavern Mayor's CLAUDE.md identity
- README and docs
- Approval/rejection messages in the two-stage workflow

---

### Human Clarification Answers (PRD Gate — 2026-03-11)

| Question | Decision |
|----------|----------|
| rally_tavern location | `$GT_ROOT/rally_tavern/` — conventional path, graceful degradation if absent |
| `rally` CLI language | Bash + grep/yq — matches existing 44 scripts, zero new dependencies |
| Search scope (v1) | Knowledge only (practices, solutions, postmortems, learned) — artifact search stays separate |
| AFTER phase trigger | Agent self-nominates at `gt done` — polecat marks bead knowledge-worthy at completion |
| Approval routing | Two-stage: rig Mayor nominates → rally_tavern Mayor accepts |
| CLI form | `rally search` (bolt-on), NOT `gt rally search` (would require Gas Town source changes) |

---

### Architectural Constraints

**Bolt-on only — no Gas Town source changes**
Rally must not require modifications to Gas Town (`gt`) or Beads (`bd`) source code.
All Gas Town interaction is via public CLI commands only (`gt sling`, `gt convoy`, `bd create`, etc.).
Rally is deployed by dropping its repo alongside a Gas Town workspace.
If a feature requires a Gas Town change, it is out of scope until a formal partnership exists.

**Wasteland compatibility — complement, don't compete**
The Wasteland (Yegge, March 2026) federates Gas Towns via a global Wanted Board, passbook
reputation, and Dolt-backed trust ledger. Rally must not duplicate these:

- **No global reputation system** — Rally's "Tavern Ranks" are local/fun only. Wasteland owns
  portable reputation. Rally ranks must not be positioned as a competing credential.
- **Bounty board = local triage scope** — Rally bounties are a local/team queue. The Wasteland
  Wanted Board is global work distribution. Rally's bounty board should include a future
  `rally wasteland publish` hook but must not claim to be a global board.
- **Build receipts include optional Wasteland attribution** — When a Wanted item is completed
  via Rally, the `build_receipt.yaml` can carry the Wasteland task ID for traceability.
- **Component manifests use open format** — Manifest schema must not use GT-internal types.
  Design for eventual DoltHub/Wasteland registry federation without schema changes.

**Skills ≠ Gas Town Formulas**
Gas Town already has formulas (e.g., `mol-idea-to-plan`). Rally skills are structured
planning prompts with validated output schemas — not execution orchestrators. The distinction
must be clear in docs and naming: skills analyse and produce artifacts; formulas execute
multi-step pipelines. Rally skills feed *into* Gas Town formulas, not replace them.

### Why YAML over JSON?
- Human-readable, git-diff-friendly, supports comments
- Matches existing Rally Tavern conventions (bounties, knowledge, templates)
- `yq` provides fast CLI processing

### Why shell scripts over Python/Go?
- Gas Town is shell-native (`gt`, `bd` are bash)
- Zero dependency footprint
- Rally Tavern already has 44 bash scripts
- Skills are YAML definitions executed by the Mayor (an LLM), not code
- If complexity warrants it later, individual scripts can be rewritten

### Why local-first component registry?
- Matches Gas Town's local-first philosophy
- Git provides versioning, search, and distribution for free
- Federation (cross-town sharing) is a future enhancement
- Avoids premature infrastructure

### Why not Dolt (now)?
Rally Tavern is git-native YAML. Dolt was considered and deferred:

**For:**
- Wasteland uses Dolt — native Dolt would make federation trivial
- Already running Dolt for beads (zero new infrastructure)
- SQL queries beat grep-through-YAML at scale
- Concurrent multi-Mayor writes → row-level merge (no git conflicts)
- DoltHub as community hub with data PRs

**Against:**
- "No server required" is the current Rally pitch — Dolt breaks it for new adopters
- GitHub rendering disappears; contributor friction increases
- Wasteland's actual data schema is not yet published (March 2026 — two days old)
- Converting 500 entries after the Wasteland schema is known is a one-day migration

**Decision:** Keep YAML now. Design the YAML schema so every field maps 1:1 to a Dolt
table column. Add `rally dolt sync` as a post-MVP Phase 6 feature (after Wasteland
schema is public). This preserves the simple fork-and-go story while leaving the
federation door open.

### How do skills actually run?
Skills are YAML definitions containing structured prompts and output schemas.
The skill runner (`rally-skill.sh`) feeds the skill definition + project profile
to the Mayor (Claude), validates the output matches the schema, and saves it.
The Mayor IS the execution engine — Rally just structures what it asks for
and validates what it gets back.
