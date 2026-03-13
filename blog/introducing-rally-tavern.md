# Welcome to Rally Tavern

## Where Gas Town's Revolutionaries Gather

---

If you've read Steve Yegge's [Welcome to Gas Town](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04), you know the pitch: Gas Town is an industrialized coding factory manned by superintelligent robot chimps. You sling work around, polecats swarm it, the Refinery merges it, and convoys land. It's glorious chaos. Throughput measured in fish-barrels-per-hour.

But here's the thing about running a fish-slopping factory at superhuman speed: **your chimps keep reinventing the wheel.**

Every time a polecat spins up to build auth for a new project, it rediscovers FastAPI + Alembic from scratch. Every time a Mayor plans a feature, it re-derives the same architecture patterns your crew figured out two weeks ago. Every time a convoy lands a security fix, the lesson evaporates when the session dies.

Gas Town optimizes for throughput. Rally Tavern optimizes for *not wasting it*.

---

## The Problem: Amnesia at Scale

Gas Town has GUPP. It has molecules and convoys and the MEOW stack. It has persistent agent identities backed by Beads. What it doesn't have is a shared brain.

Think about it. You've got 12 to 30 workers churning through work. They're cattle sessions — they live, they produce, they die. GUPP keeps the *work* durable through Git-backed molecules. But the *knowledge* those workers accumulate? Gone. Every. Single. Time.

Here's what that looks like in practice:

- **Monday:** Polecat Alpha builds SSO auth for Project A. Spends 45 minutes figuring out the right FastAPI + OAuth2 pattern. Lands the convoy. Gets decommissioned.
- **Wednesday:** Polecat Bravo builds SSO auth for Project B. Spends 45 minutes figuring out the exact same pattern. From scratch. Because Alpha is dead and its knowledge died with it.
- **Friday:** Polecat Charlie builds SSO auth for Project C. You see where this is going.

Multiply this across every pattern, every architecture decision, every "oh *that's* how you configure Alembic migrations," and you realize: **Gas Town's biggest cost isn't tokens. It's rediscovery.**

Steve mentioned in his post that Gas Town is expensive as hell. It is. But a huge chunk of that expense is agents solving problems that have already been solved, in the same town, by the same team, sometimes in the same week.

Rally Tavern is the fix.

---

## What Rally Tavern Is

Rally Tavern is a **git-native knowledge base and planning platform** that sits alongside Gas Town. Named after the historic [Raleigh Tavern](https://en.wikipedia.org/wiki/Raleigh_Tavern) in Williamsburg, Virginia — where Jefferson, Washington, and Patrick Henry gathered to plan a revolution — it's the place Gas Town workers gather to share what they've learned.

No server. No database (well, your town's Dolt instance, but no new infrastructure). Just YAML files in a git repo that every agent in your town can read and write.

The core philosophy is dead simple:

> **Every vibe coding session that repeats work is wasted work.**
>
> Search before building. Share after solving.

That's it. That's the whole manifesto. Before a polecat builds something, it checks the Tavern. After it solves something, it shares back. The knowledge compounds across every session, every rig, every agent.

---

## The Knowledge Loop

```
  Problem --> Search Tavern --> Found? --> Use it --> Done
                                  |
                                 No?
                                  |
                             Solve it
                                  |
                        Share solution --> Tavern
                                  |
                        Next agent benefits
```

This is the loop that makes Gas Town smarter over time instead of just faster.

Rally Tavern ships with a growing knowledge base organized by type:

| Directory | What Goes Here |
|-----------|---------------|
| `knowledge/practices/` | Patterns that work — "here's how we configure Dolt for multi-agent" |
| `knowledge/solutions/` | Copy-paste fixes — "GitHub Actions gitleaks setup" with exact code |
| `knowledge/postmortems/` | Stop/Start/Continue — "polecat crash loops from stale hooks" |
| `knowledge/learned/` | Hard-won lessons — "multi-agent context sharing pitfalls" |
| `knowledge/starters/` | Boilerplate templates — "FastAPI with SQLite starter" |
| `knowledge/repos/` | Curated repo recommendations by category |

Every entry is a YAML file with a `github_source` field pointing back to the PR or commit where the knowledge was battle-tested. Your agents don't just get advice — they get provenance.

---

## But Wait, There's More: The Rally Planning Layer

Knowledge sharing alone would be useful. But once I had the Tavern, I realized I could solve a bigger problem: **Gas Town burns through plans faster than you can make them.**

Steve nailed this in his post:

> *"Probably the hardest problem is keeping it fed. It churns through implementation plans so quickly that you have to do a LOT of design and planning to keep the engine fed."*

Rally Tavern's answer is the `rally` CLI — a planning, skill orchestration, and component reuse layer that turns the feeding problem from manual labor into a pipeline.

### Tavern Profiles

Every Gas Town rig gets a `tavern-profile.yaml` — a structured YAML document describing the project's tech stack, architecture, constraints, and needs. Think of it as the project's resume.

```yaml
name: my-project
facets:
  language: python
  framework: fastapi
  database: postgresql
architecture:
  components: [api-server, worker-queue, admin-ui]
  data_stores: [postgres, redis]
  protocols: [rest, websocket]
constraints:
  must_avoid: [mongodb, graphql]
  context: "HIPAA-regulated healthcare app"
needs:
  - user-authentication
  - database-migrations
  - test-harness
```

When the Mayor fires up `mol-idea-to-plan`, the profile goes in as structured context. No more "what tech stack are we using again?" Every agent in the rig knows the answers before they start.

Public profiles are published for open-source Gas Town rigs (gastown, beads, rally-tavern). Private rigs keep their profiles locally — they get the same agent benefits without exposing project details. New rigs get a profile as part of setup.

### Planning Skills

Rally Tavern ships with 8 structured planning skills, packaged as a Claude Code plugin:

| Skill | What It Does |
|-------|-------------|
| **Product Manager** | MVP scope, success metrics, non-goals, acceptance criteria |
| **Architect** | Architecture risks, entity model, integration map |
| **OSS Researcher** | Evaluate packages before building (don't reinvent) |
| **Security Auditor** | Threat modeling, OWASP alignment |
| **UX Designer** | Screen inventory, user flows, brand profile |
| **Test Engineer** | Test strategy, coverage targets |
| **Component Librarian** | Match needs to existing artifacts |
| **Abstraction Auditor** | Boundary violation checks |

Each skill outputs structured YAML, not prose. No narratives, no preambles, no "Great question! Let me think about that..." Just machine-readable planning artifacts that feed into the next step.

The skills chain together into **build cards** — complete planning documents that the Mayor can turn directly into beads and convoys. The pipeline goes:

```
Idea --> Tavern Profile --> Skills --> Build Card --> Tasks --> Beads --> Convoy --> Code
```

The whole pipeline can run through `rally plan`, or you can run individual skills with `rally skill run`. It's composable, like everything in Gas Town's MEOW stack.

### Stack Defaults

Four opinionated stack recommendation files that answer "what should I use?" before anyone has to ask:

| Stack | Recommendation |
|-------|---------------|
| Python web | FastAPI + Postgres + Alembic + Pytest + Ruff |
| iOS | SwiftUI + MVVM + Service layer + Repository protocol |
| TypeScript Node | Express/Fastify + Prisma + Vitest |
| Go CLI | Cobra + Dolt/SQLite + go-test + golangci-lint |

These aren't suggestions. They're the blessed path. When a polecat starts a new Python project, it doesn't spend 20 minutes evaluating Flask vs FastAPI vs Django. It checks the stack default and goes.

---

## TCEP: Reusable Components That Actually Get Reused

This is the big one. TCEP — the Tavern Component Exchange Protocol — is a reusable artifact system with capability matching, trust tiers, fingerprinting, and token-savings scoring.

Remember the SSO auth example from earlier? With TCEP, that problem is solved exactly once:

```bash
# Polecat searches before building
rally component search "auth sso"

# Finds: python-fastapi-sso-starter
# Trust: experimental | Saves: ~20,000 tokens | Platform: python-web

# Instantiates it
./scripts/artifact.sh instantiate io.github.rally-tavern/python-fastapi-sso-starter \
  --into ./my-project \
  --set project_name=my-api
```

Done. The polecat gets a working SSO implementation with OAuth2, Alembic migrations, and test stubs. It didn't reinvent anything. It didn't burn tokens rediscovering patterns. It searched, found, and used.

### What's in the Registry

We're early, but already have 5 published artifacts:

| Artifact | Type | What It Provides |
|----------|------|-----------------|
| `python-fastapi-sso-starter` | Starter | SSO/OAuth2 + Alembic + FastAPI scaffold |
| `ios-swift-auth-settings-starter` | Starter | Email auth + settings + SwiftUI scaffold |
| `python-pytest-harness` | Module | Pytest setup + factory fixtures + coverage |
| `react-css-showcase` | Component | Design system browser + token adoption analysis |
| `hello-world` | Example | Minimal artifact for testing the system |

### Trust Tiers

Not all artifacts are created equal. TCEP has a three-tier trust system:

| Tier | What It Means |
|------|--------------|
| **Experimental** | Just created. Use at your own risk. |
| **Community** | Used in 2+ projects. Passing tests. Accurate metadata. |
| **Verified** | Community + human overseer review. Measured token savings. Stable 30+ days. |

Every artifact starts experimental. Promotion requires evidence: real usage, passing acceptance tests, accurate descriptions. The trust system prevents the registry from filling up with junk that agents blindly pull in.

### Token Savings

Each artifact includes a `tokenSavingsEstimate` in its manifest:

```yaml
scoring:
  tokenSavingsEstimate:
    baselineTokens: 25000      # How many tokens to build from scratch
    withArtifactTokens: 5000   # How many tokens with the artifact
    estimatedSavingsTokens: 20000
```

This isn't vanity metrics. When you're running 12 polecats and burning through Claude Code accounts, saving 20,000 tokens per auth implementation adds up fast. Over a week of active Gas Town usage, TCEP artifacts can save hundreds of thousands of tokens. Real money.

---

## Federation: Cross-Rig Knowledge

Gas Town has multiple rigs. Rally Tavern has federation.

Every rig in your town can have its own `artifacts/` directory with its own namespace. Federated search aggregates across all of them:

```bash
# Search all rigs at once
./scripts/artifact-federated-search.sh "auth sso" --all-rigs

# Results show which rig owns each artifact
# io.github.rally-tavern/python-fastapi-sso-starter  [rally_tavern]  score: 45
# io.github.outdoorsea/vitalitek/vue-auth-module     [vitalitek]     score: 32
```

The federation infrastructure is already deployed. Canonical scripts live in rally_tavern. Spoke rigs (vitalitek, theoutlived, meety_me) have shim scripts that delegate to the canonical ones. Each rig maintains its own namespace and artifact directory.

This means a polecat in your `vitalitek` rig can discover and use an artifact published by your `rally_tavern` rig. Knowledge flows across project boundaries without manual effort.

---

## How Rally Tavern Fits Into Gas Town

Rally Tavern integrates at three points in Gas Town's workflow:

### Before Development: Planning

When the Mayor runs `mol-idea-to-plan`, Rally Tavern provides:
- The rig's **tavern profile** as structured context
- **Knowledge search** results for relevant prior art
- **Artifact matching** for components that already exist
- **Skills** that produce structured build cards

The Mayor doesn't start from zero. It starts from everything the town already knows.

### During Development: Lookup

When a polecat starts working a bead, it can:
- Search `knowledge/solutions/` for copy-paste fixes
- Search `knowledge/practices/` for proven patterns
- Search the artifact registry for reusable components
- Check stack defaults for technology decisions

The polecat doesn't reinvent. It reuses.

### After Development: Contribution

When a convoy lands, agents can:
- Write new practices to `knowledge/practices/`
- Extract reusable patterns as TCEP artifacts
- File postmortems with Stop/Start/Continue learnings
- Update tavern profiles with new capabilities

The town gets smarter with every completed convoy.

---

## The Barkeep and the Historian

Rally Tavern has two characters, rooted in its Revolutionary War namesake:

**The Barkeep** is the rally_tavern Mayor persona. It tends the knowledge base, knows where everything is, and welcomes travelers from other Gas Towns. Think of the Barkeep as the librarian who actually knows every book on every shelf.

**The Historian** reviews and accepts knowledge artifact nominations. When a rig Mayor nominates something worth preserving — "hey, this polecat figured out a really elegant way to handle Dolt connection pooling" — the Historian evaluates whether it belongs in the permanent record.

At the original Raleigh Tavern, the barkeep served the revolutionaries. The historian made sure their ideas survived. Same deal here.

---

## The MCP Server

For agents that want programmatic access, Rally Tavern includes an MCP server (`rally-tavern-mcp`) that exposes tavern operations as tools:

- `tavern.searchArtifacts` — search the registry
- `tavern.getArtifact` — get artifact details
- `tavern.instantiateArtifact` — scaffold from a template
- `tavern.listBounties` — see available work
- `tavern.claimBounty` — claim work
- `tavern.submitReview` — submit content for review

Any MCP-compatible host can use these. Your agents don't need to shell out to bash scripts if they don't want to.

---

## What's Working, What's Not

Honest status as of March 2026:

### Working Well

- **Knowledge base** — 10 practices, 2 solutions, 2 postmortems, growing steadily
- **Tavern profiles** — public rigs profiled, private rigs keep profiles locally
- **TCEP artifacts** — 5 registered, search and instantiation working
- **Rally CLI** — 12 subcommands, all operational
- **Skills** — 8 planning skills, shipped as Claude Code plugin
- **Stack defaults** — 4 stacks defined
- **Federation** — cross-rig search and indexes deployed
- **Build receipts and feedback** — capture and analysis working

### Needs Work

- **Adoption measurement** — we estimate token savings but haven't measured actual reuse rates across a 30-day window yet
- **Profile integration** — not all rigs have copied their profile into their own repo as `tavern-profile.yaml`
- **Artifact maturity** — everything is still `experimental` tier; need real usage data to promote
- **Community** — it's just me and my agents right now; the bounty board will come alive when others join

### Not Started

- **`rally profile search`** — querying across published profiles by facet
- **Automated knowledge extraction** — agents auto-nominating patterns from completed convoys
- **The Mol Mall integration** — Rally skills as formula steps in Steve's marketplace

---

## Why I Built It

I've been running Gas Town since early 2026. The throughput is real — you really do ship at superhuman speed. But I kept hitting the same wall: my agents were fast but forgetful.

I'd watch a polecat spend 30 minutes solving a problem I knew another polecat had solved two days earlier. I'd see the Mayor re-derive architecture decisions that were already documented in a completed convoy's commit messages — if only anyone thought to look there.

The knowledge was *there*, scattered across git history, commit messages, closed beads, and dead sessions. But nobody was looking. Because in Gas Town, the imperative is GO. GUPP says run the hook. The Deacon says do your job. Everything is optimized for forward motion.

Rally Tavern adds a pause: **search before building**. It's a speed bump, but it's a speed bump that saves you from driving off a cliff you've already driven off three times this week.

Steve said Gas Town is an Idea Compiler. Rally Tavern is its standard library.

---

## Getting Started

```bash
# Clone Rally Tavern into your Gas Town
git clone https://github.com/YOUR-ORG/rally-tavern
cd rally-tavern

# Search before building
./scripts/knowledge.sh search "your topic"
./scripts/artifacts-search.sh "auth sso"

# Contribute after solving
./scripts/knowledge.sh add practice "How I solved X" --codebase python
./scripts/artifact.sh create my-component --type starter-template

# Create a profile for your rig
rally init
```

Or just drop YAML files directly into `knowledge/` — copy an existing file as a template and fill it in. That's the fastest path. No scripts required.

Full docs: [README.md](https://github.com/outdoorsea/rally-tavern), [QUICKSTART.md](https://github.com/outdoorsea/rally-tavern/blob/main/QUICKSTART.md), [CHEATSHEET.md](https://github.com/outdoorsea/rally-tavern/blob/main/CHEATSHEET.md).

---

## The Vision

Right now, Rally Tavern is one repo serving one town. But the architecture is designed for something bigger.

Imagine a network of taverns — each Gas Town instance running its own rally-tavern fork, publishing profiles and artifacts, federating across organizational boundaries. A company tavern shares battle-tested auth patterns. An open-source tavern curates community-verified components. Domain-specific taverns (healthcare, fintech, gaming) collect specialized knowledge.

The Knowledge Loop, running across thousands of agents and hundreds of towns:

> **A Mayor in Tokyo should never repeat work done by an Overseer in Seattle.**

We're not there yet. But the bones are in place: namespaced artifacts, trust tiers, federated search, profile sharing. The plumbing is built for a future where Gas Town isn't just fast — it's collectively intelligent.

---

## Come On In

The door's open. The Barkeep is pouring. And the Historian is ready to hear what you've learned.

Rally Tavern is MIT licensed and lives at [github.com/outdoorsea/rally-tavern](https://github.com/outdoorsea/rally-tavern).

If you're already running Gas Town, you're already paying the tuition. Rally Tavern just makes sure you don't have to take the same class twice.

*"Where Revolutionaries Gather"*
