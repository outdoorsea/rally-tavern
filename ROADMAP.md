# Rally Tavern Roadmap

> From coordination hub to agent-first planning and reuse platform.

## Where We Are

Rally Tavern started as a git-native coordination hub — bounty boards, knowledge
sharing, multi-overseer coordination, security scanning. That's working: 42
scripts, templates, structured knowledge directories, all git-native.

The next evolution is **Rally**: a planning, skill orchestration, and component
reuse layer that extends Gas Town's Mayor with structured project intelligence.

**Current state (March 2026):**
- Development plan written (`.specs/plan.md`)
- Project profile schema created (`templates/tavern-profile.yaml`)
- Three real profiles written (gastown, rally-tavern, beads)
- Artifact system (TCEP) being built by polecats — manifest schema and directory
  structure are the critical-path blockers
- `mol-idea-to-plan` formula exists in Gas Town — the planning pipeline Rally
  enhances

---

## Vision

```
Idea → Tavern Profile → Planning Mode → Build Card → Mayor Convoys → Code → Feedback
```

Rally turns ad-hoc prompting into a deterministic, artifact-driven pipeline:

| Today | With Rally |
|-------|-----------|
| Mayor orchestrates ad-hoc | Mayor follows structured build cards |
| Every session rediscovers project context | Tavern profiles persist context |
| No component reuse | Artifact registry with capability matching |
| No architecture review before code | Skills critique architecture during planning |
| No security analysis in planning | Threat modeling before coding starts |
| No build feedback | Receipts drive continuous improvement |

---

## Phase 0: Foundation (In Progress)

Establish the schemas and infrastructure everything depends on.

### Tavern Profiles — DONE

| Item | Status |
|------|--------|
| Profile schema template | Done |
| gastown profile | Done |
| rally-tavern profile | Done |
| beads profile | Done |

**Next:** Wire profiles into `mol-idea-to-plan` as `--profile` context so agents
consume them automatically.

### Artifact System (TCEP) — In Progress

The component system from the original plan has evolved into TCEP (Tavern
Component Exchange Protocol), a richer artifact format with trust levels,
fingerprinting, and token-savings scoring.

| Bead | What | Priority | Status |
|------|------|----------|--------|
| rt-rrk9 | Artifact manifest schema | P1 | Open (blocks 8) |
| rt-bb7n | `artifacts/` directory structure | P1 | Open (blocks 2) |
| rt-h13q | `artifact.sh` management script | P1 | Blocked by above |
| rt-04mx | `artifacts-search.sh` ranked discovery | P1 | Blocked by rt-rrk9 |
| rt-fghg | `artifacts-json.sh` agent endpoint | P1 | Blocked by rt-rrk9 |

**Artifact types:** starter-template, module, skill, mcp-server, playbook.

**TCEP vs original plan:** The original plan had separate "Component Manifest"
(Feature 11), "Resolution Engine" (Feature 12), and "Component Registry"
(Feature 13). TCEP consolidates these into a single artifact system with richer
metadata (trust tiers, fingerprinting, token-savings estimates, provenance
tracking). The resolution engine becomes artifact search with ranked scoring.

### Stack Defaults

Static YAML files defining opinionated stack recommendations. Lowest complexity
in the entire plan (1/5). Can be done anytime.

| Stack | Tech |
|-------|------|
| Python web | FastAPI + Postgres + Alembic + Pytest + Ruff |
| iOS | SwiftUI + MVVM + Service layer + Repository protocol |
| TypeScript Node | Express/Fastify + Prisma + Vitest |
| Go CLI | Cobra + Dolt/SQLite + go-test + golangci-lint |

---

## Phase 1: Skill System

Skills are structured YAML definitions containing prompts and output schemas.
The skill runner feeds a skill definition + tavern profile to the Mayor,
validates the output, and saves it. The Mayor IS the execution engine — Rally
structures what it asks for and validates what it gets back.

### Skill Framework

| Deliverable | Description |
|-------------|-------------|
| Skill definition schema | YAML with structured prompts, input requirements, output schemas |
| `rally skill run` | Execute a skill against a tavern profile |
| Output validation | Ensure structured YAML output, not narrative |
| Skill chaining | Output of one skill feeds input of next |
| `rally skill list` | Discovery and registry |

### Core Skills (MVP)

| Skill | Purpose | Output Section |
|-------|---------|---------------|
| Product Manager | Define MVP scope, success metrics, non-goals | `mvp_scope` |
| Architect | Architecture risks, entity model, integration map | `architecture_risks` |
| OSS Researcher | Evaluate packages before building | `oss_analysis` |
| Security Auditor | Threat modeling, OWASP alignment | `security_review` |

### Additional Skills (Post-MVP)

| Skill | Purpose | Output Section |
|-------|---------|---------------|
| UX Designer | Screen inventory, user flows, brand profile | `screens`, `brand_profile` |
| Test Engineer | Test strategy, coverage targets | `test_strategy` |
| Librarian | Artifact recommendations from registry | `recommended_components` |
| Abstraction Auditor | Boundary violation checks (pre-merge gate) | `abstraction_score` |

### Integration with mol-idea-to-plan

The existing `mol-idea-to-plan` formula already runs a 7-step pipeline (intake →
PRD review → clarify → plan → plan review → approve → create beads). Rally
skills can enhance this pipeline by:

1. Feeding tavern profiles as structured context at the intake step
2. Replacing ad-hoc review legs with skill-based analysis
3. Producing build cards as intermediate artifacts

This is an evolution of the existing formula, not a replacement.

---

## Phase 2: Build Cards and Planning Mode

The orchestrator that chains skills into a complete build card.

### Build Card Schema

```yaml
mvp_scope:
  problem_statement:
  success_metrics:
  non_goals:
  acceptance_criteria:

oss_analysis:
  candidates:
  recommendations:

architecture_risks:
  issues:
  mitigations:

security_review:
  attack_vectors:
  required_controls:

abstraction_boundaries:
  - name:
    type:
    reason:

entities:
screens:
external_integrations:
recommended_components:

execution_plan:
  - phase: PM
  - phase: UX
  - phase: Architect
  - phase: Test
  - phase: Dev
```

### `rally plan`

- Runs skills in defined order: PM → OSS → Architecture → Security → Librarian
- Assembles skill outputs into `build-card.yaml`
- Validates build card completeness
- Planning Mode is read-only — must NOT modify code
- Takes `--profile` to load project context

---

## Phase 3: Execution Bridge

Connect Rally planning output to Mayor's convoy system.

### Task Generation

- `rally tasks generate <build-card>` → produces `tasks.yaml`
- Task categories: PM, UX, Architecture, Test, Implementation
- Each task has: description, acceptance criteria, dependencies, complexity
- Tasks are bead-compatible for direct dispatch

### Mayor Integration

- `rally dispatch <build-card>` → converts tasks to beads + convoys
- Groups beads into ordered convoys (PM → UX → Architect → Test → Dev)
- Respects convoy ordering and dependencies
- Links beads back to build card for traceability

---

## Phase 4: Feedback Loop

Close the loop so the system improves from its own output.

### Build Receipts

- `build_receipt.yaml` captured after each build
- Tracks: tokens used, files changed, artifacts used, test pass rate
- Stored in project directory with history for trend analysis

### Feedback Engine

- `rally feedback analyze` — aggregate receipt data
- Identifies: frequently reinvented patterns, common risks, reusable candidates
- Suggests: new artifacts to extract, skill refinements, default updates

---

## Phase 5: Ecosystem

### Artifact Trust and Security (P2 beads exist)

| Bead | What |
|------|------|
| rt-nstq | Integrate artifact trust with security scanner |
| rt-gfzx | Artifact fingerprinting for deduplication |
| rt-gzvx | Token-savings scoring and telemetry |
| rt-ktde | Extend bounty schema with artifact linkage |

### Example Artifacts (P2)

| Bead | What |
|------|------|
| rt-ylmd | Python FastAPI SSO + iOS Swift starters |

### MCP Server (P3)

| Bead | What |
|------|------|
| rt-mlst | `rally-tavern-mcp` server exposing tavern operations to any MCP host |

Tools: `tavern.searchArtifacts`, `tavern.getArtifact`,
`tavern.instantiateArtifact`, `tavern.listBounties`, `tavern.claimBounty`,
`tavern.submitReview`.

### Federation (P3)

| Bead | What |
|------|------|
| rt-6ovc | Cross-tavern artifact sharing with trust policies |

---

## Dependency Graph

```
Phase 0                      Phase 1                Phase 2
─────────                    ───────                ───────
Tavern Profiles (DONE)──┐
                         ├──► Skill Framework──┐
Stack Defaults           │    │                │
                         │    ├──► PM Skill ───┤
Artifact Manifest ───────┤    ├──► Architect ──┤
  (rt-rrk9, polecats)   │    ├──► OSS ────────┼──► Build Card ──┐
                         │    └──► Security ───┘    Generation   │
Artifacts Directory ─────┤                                       │
  (rt-bb7n, polecats)   │                                       │
         │               │                          Phase 3      │
         ▼               │                          ───────      │
Artifact CLI ────────────┤               Task Generation ◄──────┘
  (rt-h13q)             │                     │
         │               │               Mayor Integration
         ▼               │                     │
Search + JSON endpoints  │               Phase 4
                         │               ───────
                         │          Build Receipts
                         │                │
                         │          Feedback Loop
                         │
                         │          Phase 5
                         │          ───────
                         └──────► MCP Server
                                  Federation
                                  Trust/Security
                                  Example Artifacts
```

---

## Dogfooding Plan

Rally should be used on real Gas Town work as soon as possible.

### Immediate (no tooling needed)

- [x] Tavern profile schema and template
- [x] Tavern profiles for gastown, rally-tavern, beads (in `profiles/`)
- [ ] Copy profiles to each rig's own repo as `tavern-profile.yaml`
- [ ] Reference profiles from rig CLAUDE.md files so agents always have context
- [ ] Pass profiles as `--context` to `mol-idea-to-plan` runs

### Short-term (light tooling)

- [ ] Stack defaults YAML files (trivial to create)
- [ ] Skill YAML definitions — usable as structured prompts even without the
  skill runner
- [ ] `--profile` flag on `mol-idea-to-plan` formula for automatic profile loading

### Medium-term (needs artifact system)

- [ ] Publish first artifacts once TCEP manifest lands (rt-rrk9)
- [ ] Test artifact instantiation on a real project
- [ ] Validate search/ranking against real agent workflows

### Validation criteria

After 30 days of dogfooding, measure:
- Reduced architecture churn in agent-built code
- Faster planning (less rediscovery per session)
- Artifact reuse rate (are agents actually using published artifacts?)
- Fewer security oversights caught post-merge
- Consistent project structure across rigs

---

## Profile Sharing: Collective Intelligence

Tavern profiles live in each project's own repo (`tavern-profile.yaml` at the
root). This means agents always find them locally. But the real value comes when
profiles are shared — so others can learn from your stack choices, discover
existing solutions, and avoid reinventing the wheel.

### How It Works

```
Your Repo                          Rally Tavern
──────────                         ────────────
tavern-profile.yaml  ──publish──►  profiles/
  (canonical, in your repo)          yourproject.tavern-profile.yaml
                                     (searchable copy)
                     ◄──discover──
                                   Other developers search:
                                   "Who's using FastAPI + Postgres?"
                                   "Any project doing SSO with Google?"
                                   "What Go CLI tools use Cobra + Dolt?"
```

**Canonical copy** lives in your repo. You own it, you update it.

**Published copy** lives in Rally Tavern's `profiles/` directory. This is the
searchable index. Think of it like a package registry — you don't move your
source code there, you publish metadata about it.

### What Sharing Enables

| Use Case | How Profiles Help |
|----------|------------------|
| **Stack discovery** | "Show me projects using FastAPI + Alembic" → find proven patterns |
| **Avoid reinvention** | "Anyone already built SSO auth?" → find existing solutions in `needs` |
| **Architecture reference** | "How did project X structure their components?" → learn from `architecture.components` |
| **Constraint learning** | "Why did they avoid MongoDB?" → read `constraints.must_avoid` + `context` |
| **Onboarding** | New contributor reads the profile instead of exploring for 30 minutes |
| **Cross-pollination** | Agents working on project A discover relevant patterns from project B |

### Publishing Flow

```bash
# In your project repo:
# 1. Create or update your profile
cp rally-tavern/templates/tavern-profile.yaml ./tavern-profile.yaml
# ... fill it in ...

# 2. Publish to Rally Tavern (future: rally publish-profile)
# For now: copy to Rally Tavern's profiles/ directory
cp tavern-profile.yaml rally-tavern/profiles/myproject.tavern-profile.yaml

# 3. Others can discover it
./scripts/knowledge.sh search "fastapi postgres"  # future: rally search-profiles
```

### Search and Discovery (Planned)

```bash
# Search profiles by facet
rally profile search --language python --framework fastapi

# Search by need
rally profile search --need "user authentication"

# Search by tag
rally profile search --tag multi-agent

# List all published profiles
rally profile list
```

Search indexes on: `facets.*`, `needs`, `tags`, `constraints.*`,
`architecture.data_stores`, `architecture.protocols`.

### Privacy and Scope

Profiles contain metadata, not source code. They describe *what* a project uses,
not *how* it implements things. Users choose what to share:

- **Public taverns** — profiles visible to anyone who clones the tavern
- **Private taverns** — profiles shared only within an organization
- **Federation** — cross-tavern profile sharing follows the same trust model as
  artifact federation (Phase 5)

Profiles should never contain secrets, credentials, or internal URLs. The schema
is designed to hold architectural decisions, not implementation details.

### Integration with Artifacts

Profiles and artifacts form a virtuous cycle:

1. **Profile reveals a need** → "project X needs SSO authentication"
2. **Artifact search matches** → "python-fastapi-sso-starter exists"
3. **Instantiate artifact** → agent uses the starter in project X
4. **Profile updates** → project X's profile now shows SSO as solved
5. **Others discover** → project Y sees X solved SSO, uses same artifact

This is the knowledge loop from Rally Tavern's philosophy: *search before
building, share after solving.*

---

## Design Principles

**Agent-first.** Artifacts are structured and machine-readable. Skills output
YAML, not prose.

**Deterministic planning.** Planning produces structured build cards, not
narrative guidance.

**Reuse before reinvention.** Evaluate existing artifacts and open-source
packages before building new functionality.

**Replaceability.** Systems encourage abstraction boundaries so components can
be swapped without cascading changes.

**Security by design.** Threat modeling happens during planning, not after code
is written.

**Continuous learning.** Each build generates feedback that improves skills,
artifacts, and defaults.

**Local-first.** No server, no cloud, no external dependencies beyond git and
Dolt. Federation is opt-in.

---

## Reference Documents

| Document | Purpose |
|----------|---------|
| `.specs/plan.md` | Original 19-feature development plan with dependency graph |
| `templates/tavern-profile.yaml` | Profile schema template |
| `profiles/*.tavern-profile.yaml` | Tavern profiles for Gas Town rigs |
| `.ref/RALLY_ROADMAP.md` | Earlier roadmap draft (reference only) |
| `.ref/AGENT_EXECUTION_GUIDE.md` | Earlier agent execution guide (reference only) |

---

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| CLI commands | Bash scripts | Matches `gt`/`bd` pattern |
| Artifact format | YAML | Machine-readable, git-friendly |
| Issue tracking | Beads (Dolt) | Already integrated |
| Artifact registry | YAML manifests in git | Local-first, version-controlled |
| Skill definitions | YAML + structured prompts | Deterministic, auditable |
| Validation | `yq` + bash | Lightweight schema validation |

---

*"Design for replaceability. Replaceability enables reuse. Reuse reduces
entropy. Reduced entropy compounds intelligence."*
