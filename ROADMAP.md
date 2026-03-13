# Rally Tavern Roadmap

> From coordination hub to agent-first planning and reuse platform.

## Where We Are

Rally Tavern started as a git-native coordination hub — knowledge sharing,
multi-overseer coordination, security scanning. It has grown into a full
planning, skill orchestration, and component reuse platform: 61 scripts,
9 rig profiles, 5 artifacts, 8 planning skills, 4 stack defaults, federated
search across rigs, an MCP server, and a Claude Code plugin.

**Current state (March 2026):**
- Rally CLI (`rally` command) fully operational with 12 subcommands
- 9 tavern profiles published (gastown, rally-tavern, beads, vitalitek,
  theoutlived, meety-me, gt-model-eval, lilypad-chat, wandering-river)
- Artifact system (TCEP) live — 5 artifacts registered, federated search working
- 8 planning skills shipped as Claude Code plugin (`plugins/rally-skills/`)
- 4 stack defaults (python-web, ios-swiftui, typescript-node, go-cli)
- Federation deployed to spoke rigs (vitalitek, theoutlived, meety_me)
- MCP server implemented (`mcp-server/src/index.ts`)
- Build receipt capture, feedback analysis, and task generation working
- Knowledge base growing: 10 practices, 2 solutions, 2 postmortems

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

## Phase 0: Foundation — DONE

All foundational schemas and infrastructure are in place.

### Tavern Profiles — DONE

| Item | Status |
|------|--------|
| Profile schema template | Done |
| gastown profile | Done |
| rally-tavern profile | Done |
| beads profile | Done |
| vitalitek profile | Done |
| theoutlived profile | Done |
| meety-me profile | Done |
| gt-model-eval profile | Done |
| lilypad-chat profile | Done |
| wandering-river profile | Done |

### Artifact System (TCEP) — DONE

TCEP (Tavern Component Exchange Protocol) is live with trust levels,
fingerprinting, token-savings scoring, and federated search.

| Bead | What | Status |
|------|------|--------|
| rt-rrk9 | Artifact manifest schema | Done |
| rt-bb7n | `artifacts/` directory structure | Done |
| rt-h13q | `artifact.sh` management script | Done |
| rt-04mx | `artifacts-search.sh` ranked discovery | Done |
| rt-fghg | `artifacts-json.sh` agent endpoint | Done |

**5 artifacts registered:** python-fastapi-sso-starter, ios-swift-auth-settings-starter,
python-pytest-harness, react-css-showcase, hello-world (example).

### Stack Defaults — DONE

| Stack | Tech | File |
|-------|------|------|
| Python web | FastAPI + Postgres + Alembic + Pytest + Ruff | `defaults/stacks/python-web.yaml` |
| iOS | SwiftUI + MVVM + Service layer + Repository protocol | `defaults/stacks/ios-swiftui.yaml` |
| TypeScript Node | Express/Fastify + Prisma + Vitest | `defaults/stacks/typescript-node.yaml` |
| Go CLI | Cobra + Dolt/SQLite + go-test + golangci-lint | `defaults/stacks/go-cli.yaml` |

---

## Phase 1: Skill System — DONE

All 8 skills are implemented and ship as a Claude Code plugin (`plugins/rally-skills/`).

### Skill Framework — DONE

| Deliverable | Status |
|-------------|--------|
| Skill definition schema (SKILL.md format) | Done |
| `rally skill run` | Done |
| `rally skill list` | Done |
| Claude Code plugin packaging | Done |

### All Skills — DONE

| Skill | Purpose | Output Section |
|-------|---------|---------------|
| Product Manager | Define MVP scope, success metrics, non-goals | `mvp_scope` |
| Architect | Architecture risks, entity model, integration map | `architecture_risks` |
| OSS Researcher | Evaluate packages before building | `oss_analysis` |
| Security Auditor | Threat modeling, OWASP alignment | `security_review` |
| UX Designer | Screen inventory, user flows, brand profile | `screens`, `brand_profile` |
| Test Engineer | Test strategy, coverage targets | `test_strategy` |
| Component Librarian | Artifact recommendations from registry | `recommended_components` |
| Abstraction Auditor | Boundary violation checks (pre-merge gate) | `abstraction_score` |

### Integration with mol-idea-to-plan

The existing `mol-idea-to-plan` formula already runs a 7-step pipeline (intake →
PRD review → clarify → plan → plan review → approve → create beads). Rally
skills enhance this pipeline by:

1. Feeding tavern profiles as structured context at the intake step
2. Replacing ad-hoc review legs with skill-based analysis
3. Producing build cards as intermediate artifacts

This is an evolution of the existing formula, not a replacement.

---

## Phase 2: Build Cards and Planning Mode — DONE

The `rally plan` command chains skills into a complete build card.

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

## Phase 3: Execution Bridge — DONE

Rally planning output connects to Mayor's convoy system.

### Task Generation — DONE

- `rally tasks generate <build-card>` → produces `tasks.yaml`
- Task categories: PM, UX, Architecture, Test, Implementation
- Each task has: description, acceptance criteria, dependencies, complexity
- Tasks are bead-compatible for direct dispatch

### Mayor Integration — DONE

- `rally dispatch <build-card>` → converts tasks to beads + convoys
- Groups beads into ordered convoys (PM → UX → Architect → Test → Dev)
- Respects convoy ordering and dependencies
- Links beads back to build card for traceability

---

## Phase 4: Feedback Loop — DONE

### Build Receipts — DONE

- `rally receipt generate` captures build metrics after each build
- Tracks: tokens used, files changed, artifacts used, test pass rate
- Stored in project directory with history for trend analysis

### Feedback Engine — DONE

- `rally feedback analyze` — aggregates receipt data
- Identifies: frequently reinvented patterns, common risks, reusable candidates
- Suggests: new artifacts to extract, skill refinements, default updates

---

## Phase 5: Ecosystem — Mostly Done

### Artifact Trust and Security — DONE

| Bead | What | Status |
|------|------|--------|
| rt-nstq | Integrate artifact trust with security scanner | Done |
| rt-gfzx | Artifact fingerprinting for deduplication | Done |
| rt-gzvx | Token-savings scoring and telemetry | Done |
| rt-ktde | Extend bounty schema with artifact linkage | Done |

### Example Artifacts — DONE

| Bead | What | Status |
|------|------|--------|
| rt-ylmd | Python FastAPI SSO + iOS Swift starters | Done |

5 artifacts now registered (python-fastapi-sso-starter, ios-swift-auth-settings-starter,
python-pytest-harness, react-css-showcase, hello-world).

### MCP Server — DONE

| Bead | What | Status |
|------|------|--------|
| rt-mlst | `rally-tavern-mcp` server | Done |

Tools: `tavern.searchArtifacts`, `tavern.getArtifact`,
`tavern.instantiateArtifact`, `tavern.listBounties`, `tavern.claimBounty`,
`tavern.submitReview`.

### Federation — DONE

| Bead | What | Status |
|------|------|--------|
| rt-6ovc | Cross-tavern artifact sharing with trust policies | Done |

**Federation infrastructure (March 2026):**
- `ARTIFACT_DIR_OVERRIDE` added to all 3 canonical scripts (artifact.sh, artifacts-search.sh, artifacts-json.sh)
- `artifact-federated-search.sh` — cross-rig ranked search with `source_rig` annotation
- `artifact-federated-index.sh` — aggregates all rig indexes into `federated-index.json`
- Shim scripts deployed to vitalitek, theoutlived, meety_me (delegate to rally_tavern canonical scripts)
- Each rig has its own `artifacts/` directory and namespace
- CLAUDE.md updated in all spoke rigs with artifact system documentation
- `CONTRIBUTING-ARTIFACTS.md` published with naming conventions, trust tiers, and acceptance test requirements

---

## Completion Status

All 5 phases are complete. The full pipeline is operational:

```
Phase 0 ✅    Phase 1 ✅    Phase 2 ✅    Phase 3 ✅    Phase 4 ✅    Phase 5 ✅
──────────    ──────────    ──────────    ──────────    ──────────    ──────────
Profiles      Skills (8)    Build Cards   Task Gen      Receipts      MCP Server
Artifacts     Plugin        rally plan    Dispatch      Feedback      Federation
Stack Defs                                                            Trust/Security
```

---

## Dogfooding Status

### Done

- [x] Tavern profile schema and template
- [x] Tavern profiles for 9 Gas Town rigs
- [x] Stack defaults YAML files (4 stacks)
- [x] Skill YAML definitions (8 skills as Claude Code plugin)
- [x] Artifact system live with 5 registered artifacts
- [x] Federation deployed to spoke rigs
- [x] Cross-rig artifact and knowledge search working
- [x] Build receipt capture and feedback analysis

### In Progress

- [ ] Copy profiles to each rig's own repo as `tavern-profile.yaml`
- [ ] Reference profiles from rig CLAUDE.md files so agents always have context
- [ ] `--profile` flag on `mol-idea-to-plan` formula for automatic profile loading
- [ ] Test artifact instantiation on real projects at scale
- [ ] Promote artifacts from experimental to community tier

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
