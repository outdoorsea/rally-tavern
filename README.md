# 🍺 Rally Tavern

**Shared knowledge and planning for Gas Town builders**

*Named after the historic [Raleigh Tavern](https://en.wikipedia.org/wiki/Raleigh_Tavern) in Williamsburg, VA — where revolutionaries gathered to shape the future.*

Rally Tavern is a **git-native knowledge base and planning platform** for humans (Overseers) and AI agents (Mayors, Crew, Polecats) working across Gas Town rigs. No server required — just git and YAML.

> **Every vibe coding session that repeats work is wasted work.**
> Search before building. Share after solving. See [PHILOSOPHY.md](PHILOSOPHY.md).

[![GitHub](https://img.shields.io/badge/git--native-yes-green)]()
[![Gas Town](https://img.shields.io/badge/Gas%20Town-compatible-blue)](https://github.com/steveyegge/gastown)

## 🎯 What Rally Tavern Does

| Feature | Status | Description |
|---------|--------|-------------|
| **Knowledge Sharing** | ✅ Live | Practices, solutions, postmortems — grows with every project |
| **Tavern Profiles** | ✅ Live | 9 per-rig tech stack profiles consumed by planning agents |
| **Artifact Registry (TCEP)** | ✅ Live | Reusable components with capability matching, trust tiers, and token-savings scoring |
| **Rally CLI** | ✅ Live | `rally` command for planning, skills, components, feedback, and task generation |
| **Skill System** | ✅ Live | 8 structured planning skills as a Claude Code plugin |
| **Stack Defaults** | ✅ Live | Opinionated stack recommendations for Python, iOS, TypeScript, Go |
| **Federation** | ✅ Live | Cross-rig artifact search, federated indexes, shim scripts in spoke rigs |
| **MCP Server** | ✅ Live | `rally-tavern-mcp` exposes tavern operations to any MCP host |
| **Coordination** | ✅ Live | Prevent conflicts between Overseers & Mayors |
| **Security** | ✅ Live | Trust levels, prompt injection scanning, artifact fingerprinting |
| **Bounty Board** | ✅ Live | Post and claim work across teams |
| **Fun** | ✅ Live | Ranks, quests, celebrations |

## 👥 Roles (Gas Town Icons)

| Icon | Role | Who |
|------|------|-----|
| 👤 | **Overseer** | Human who runs a Gas Town |
| 🎩 | **Mayor** | AI orchestrator (Claude, Codex) |
| 🐺 | **Deacon** | Background AI agent |
| 👷 | **Crew** | Persistent AI workspace agents |
| 🦨 | **Polecat** | Transient AI worker agents |
| 🤠 | **Sheriff** | Moderator (security, disputes) |

## 🍺 Rally Tavern Characters

| Icon | Character | Role |
|------|-----------|------|
| 🍺 | **Barkeep** | The rally_tavern Mayor persona. Tends the knowledge base, knows where everything is, welcomes travelers from other Gas Towns. |
| 📜 | **Historian** | Reviews and accepts knowledge artifact nominations. When a rig Mayor nominates something worth preserving, the Historian evaluates it before it enters the permanent record. |

*Named after the [Raleigh Tavern](https://en.wikipedia.org/wiki/Raleigh_Tavern) in Williamsburg, VA — where Jefferson, Washington, and Henry gathered. The Barkeep served the revolutionaries; the Historian made sure their ideas survived.*

## 🚀 Quick Start

```bash
# Fork and clone
git clone https://github.com/YOUR-ORG/rally-tavern
cd rally-tavern

# Search before building
./scripts/knowledge.sh search "your topic"
./scripts/artifacts-search.sh "auth sso"

# Contribute after solving (directly write YAML)
# See templates/ for file formats and knowledge/ for examples
git add knowledge/
git commit -m "Add: [what you learned]"
git push
```

Full interactive setup:

```bash
./scripts/init-tavern.sh   # First-time setup (registers you as Sheriff)
./scripts/enter.sh         # Enter tavern (banner + wisdom)
./scripts/board.sh         # See the bounty board
```

## ⚡ Rally CLI

The `rally` command is the planning, skill orchestration, and component reuse layer.

```bash
rally init                              # Create a tavern-profile.yaml
rally validate profile.yaml             # Validate a profile
rally skill list                        # List available planning skills
rally skill run pm --profile p.yaml     # Run Product Manager skill
rally plan project-profile.yaml         # Generate build card from profile
rally component list                    # List registered artifacts
rally component search "auth sso"       # Search by keyword
rally resolve project-profile.yaml      # Match components to project needs
rally defaults show python-web          # View stack defaults
rally receipt generate                  # Capture build metrics
rally feedback analyze                  # Analyze build patterns
rally tasks generate build-card.yaml    # Generate tasks from build card
rally dispatch build-card.yaml          # Dispatch tasks to Mayor convoy
rally knowledge-push --tags "gas-town"  # Find relevant knowledge for a bead
```

## 🧩 Artifact Registry (TCEP)

Rally Tavern includes **TCEP** (Tavern Component Exchange Protocol) — a reusable component system with trust levels, capability matching, fingerprinting, and token-savings scoring.

### Registered Artifacts

| Artifact | Type | Capabilities | Platform |
|----------|------|-------------|----------|
| `python-fastapi-sso-starter` | Starter | SSO/OAuth2, database migrations, API server | Python |
| `ios-swift-auth-settings-starter` | Starter | Email/password auth, settings, SwiftUI scaffold | iOS |
| `python-pytest-harness` | Module | Pytest setup, fixtures, coverage | Python |
| `react-css-showcase` | Component | Design system browser, token adoption analysis | React/Web |
| `hello-world` | Example | Minimal artifact for testing | Any |

### Artifact Commands

```bash
./scripts/artifact.sh create my-artifact --type starter-template    # Create
./scripts/artifact.sh validate artifacts/namespace/name             # Validate
./scripts/artifact.sh reindex                                       # Rebuild index
./scripts/artifacts-search.sh "auth sso"                            # Search
./scripts/artifacts-json.sh                                         # JSON endpoint for agents
./scripts/artifact-federated-search.sh "auth" --all-rigs            # Cross-rig search
```

See [CONTRIBUTING-ARTIFACTS.md](CONTRIBUTING-ARTIFACTS.md) for full artifact guidelines and [REGISTRY.md](REGISTRY.md) for the component index.

## 🎯 Skills System

Eight structured planning skills ship as a Claude Code plugin (`plugins/rally-skills/`):

| Skill | Purpose | Output |
|-------|---------|--------|
| **Product Manager** | MVP scope, success metrics, non-goals | `mvp_scope` |
| **Architect** | Architecture risks, entity model, integration map | `architecture_risks` |
| **OSS Researcher** | Evaluate packages before building | `oss_analysis` |
| **Security Auditor** | Threat modeling, OWASP alignment | `security_review` |
| **UX Designer** | Screen inventory, user flows, brand profile | `screens`, `brand_profile` |
| **Test Engineer** | Test strategy, coverage targets | `test_strategy` |
| **Component Librarian** | Artifact recommendations from registry | `recommended_components` |
| **Abstraction Auditor** | Boundary violation checks | `abstraction_score` |

Skills output structured YAML, not prose. They feed into build cards for deterministic planning.

## 📋 Tavern Profiles

Tavern profiles describe a project's tech stack, architecture, constraints, and needs as structured YAML. They persist project context so agents don't rediscover it every session.

**9 profiles published** for Gas Town rigs: gastown, rally-tavern, beads, vitalitek, theoutlived, meety-me, gt-model-eval, lilypad-chat, wandering-river.

```bash
rally init                              # Create your profile interactively
rally validate tavern-profile.yaml      # Validate it
```

See `profiles/` for examples and `templates/tavern-profile.yaml` for the schema.

## 📚 Knowledge Base

### Categories

| Directory | Content | Count |
|-----------|---------|-------|
| `knowledge/practices/` | Patterns that work | 10 |
| `knowledge/solutions/` | Copy-paste fixes for specific problems | 2 |
| `knowledge/postmortems/` | Stop/Start/Continue learnings | 2 |
| `knowledge/learned/` | Hard-won lessons | 1 |
| `knowledge/starters/` | Boilerplate templates | 1 |
| `knowledge/repos/` | Useful repositories | categorized |

Each YAML file includes a `github_source` field pointing to the PR or commit where the knowledge was produced.

### Commands

```bash
./scripts/knowledge.sh add practice "Title" --codebase python
./scripts/knowledge.sh add solution "Title"
./scripts/knowledge.sh list
./scripts/knowledge.sh search "auth"
./scripts/repos.sh add owner/repo --category ai-agents
./scripts/postmortem.sh add "What Went Wrong"
```

## 📋 Bounty Board

### Bounty Types

| Icon | Type | Purpose |
|------|------|---------|
| 🔍 | `looking-for` | Ask if something already exists |
| 🔨 | `build` | Create something new |
| 📖 | `explain` | Request documentation |
| 🔧 | `fix` | Bug or issue |
| 🤝 | `collab` | Find a collaborator |

```bash
./scripts/board.sh                           # View board
./scripts/post.sh "Title" --priority 2       # Post bounty
./scripts/claim.sh bounty-abc                # Claim
./scripts/complete.sh bounty-abc             # Complete
./scripts/bounties-json.sh                   # JSON endpoint for Mayors
```

## 🤝 Coordination

### Multi-Overseer (Humans)

```bash
./scripts/coord.sh                           # Overview
./scripts/today.sh "Working on auth"         # Post focus
./scripts/claim-area.sh "auth" "Refactoring" # Claim area
./scripts/check-area.sh "src/auth/"          # Check claims
./scripts/release-area.sh "auth"             # Release
./scripts/handoff.sh "sarah" "Auth work"     # Hand off
```

### Multi-Mayor (AI)

```bash
./scripts/mayor-intent.sh "my-mayor" "Refactoring auth" "src/auth/*"
./scripts/mayor-check.sh "src/auth/"         # Check activity
./scripts/mayor-done.sh "my-mayor"           # Signal done
./scripts/style-agree.sh python              # Style agreement
```

## 🛡️ Security

### Trust Levels

| Level | Meaning |
|-------|---------|
| 🔴 Experimental | Created, no review needed |
| 🟡 Community | Used in 2+ projects, passing tests, accurate metadata |
| 🟢 Verified | Community + human overseer review, measured token savings |

### Commands

```bash
./scripts/security.sh scan configs/          # Scan for issues
./scripts/security.sh check file.yaml        # Check specific file
./scripts/sheriff.sh approve file.yaml       # Sheriff approves
./scripts/sheriff.sh flag file.yaml "Reason" # Flag suspicious
./scripts/sheriff.sh jail                    # View flagged
```

## 🌐 Federation

Artifacts and knowledge are discoverable across all Gas Town rigs:

```bash
./scripts/artifact-federated-search.sh "auth" --all-rigs    # Cross-rig artifact search
./scripts/artifact-federated-index.sh                        # Rebuild federated index
./scripts/knowledge-push.sh --tags "gas-town"                # Push knowledge to relevant rigs
```

Federation infrastructure is deployed: canonical scripts in rally_tavern, shim scripts in spoke rigs (vitalitek, theoutlived, meety_me), each rig has its own `artifacts/` directory and namespace. See [FEDERATION.md](FEDERATION.md).

## 🎮 Fun & Engagement

```bash
./scripts/enter.sh                           # Enter tavern (banner + wisdom)
./scripts/wisdom.sh                          # Random wisdom
./scripts/quest.sh                           # Daily quest
./scripts/rank.sh                            # Your rank
./scripts/celebrate.sh "Shipped it!" "3"     # Celebrate (🍺🍺🍺)
```

### Tavern Ranks

| Rank | Icon | Requirement |
|------|------|-------------|
| Newcomer | 🚪 | Just arrived |
| Regular | 🍺 | 5+ contributions |
| Trusted | ⭐ | 15+ contributions |
| Innkeeper | 🏠 | 30+ contributions |
| Tavern Master | 👑 | Legendary |

## 🏥 Health & Stats

```bash
./scripts/health.sh                          # Health check
./scripts/stats.sh summary                   # Quick stats
./scripts/stats.sh contributors              # Top contributors
./scripts/stats.sh activity                  # Recent activity
```

## 📁 Directory Structure

```
rally-tavern/
├── artifacts/                # TCEP artifact registry
│   ├── .index.json           # Compiled registry (auto-generated)
│   ├── federated-index.json  # Cross-rig federated index
│   └── io.github.rally-tavern/
│       ├── python-fastapi-sso-starter/
│       ├── ios-swift-auth-settings-starter/
│       ├── python-pytest-harness/
│       └── react-css-showcase/
├── bounties/                 # Work board (open/claimed/done)
├── configs/                  # Shared configurations
│   └── claude-md/            # CLAUDE.md templates
├── coordination/             # Claims, intents, handoffs
│   ├── claims/               # Overseer area claims
│   ├── mayors/               # Mayor intents
│   ├── today/                # Daily focus
│   ├── handoffs/             # Work handoffs
│   └── style/                # Style agreements
├── defaults/                 # Stack defaults
│   ├── facets.yaml           # Facet vocabulary
│   ├── security-controls.yaml
│   └── stacks/               # Per-stack recommendations
│       ├── go-cli.yaml
│       ├── ios-swiftui.yaml
│       ├── python-web.yaml
│       └── typescript-node.yaml
├── gossip/                   # Shared context (TTL)
├── help/                     # Q&A
├── knowledge/                # Collective intelligence
│   ├── practices/            # Patterns that work
│   ├── solutions/            # Copy-paste fixes
│   ├── starters/             # Boilerplate templates
│   ├── postmortems/          # Stop/Start/Continue learnings
│   ├── learned/              # Hard-won lessons
│   └── repos/                # Useful repositories
├── mcp-server/               # MCP server for agent integration
│   └── src/index.ts
├── overseers/                # 👤 Human profiles
├── mayors/                   # 🎩 AI profiles
├── plugins/                  # Claude Code plugins
│   └── rally-skills/         # 8 planning skills
│       └── skills/
├── profiles/                 # Per-rig tavern-profile.yaml files (9 rigs)
├── scripts/                  # 61 CLI tools
├── security/                 # Trust & verification
├── skills/                   # Skill YAML definitions
├── tavern/                   # Fun stuff (ranks, sheriff, hall of fame)
├── templates/                # YAML templates for all content types
└── tests/                    # Test suites
```

## 📜 Documentation

| File | Description |
|------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | 2-minute getting started |
| [CHEATSHEET.md](CHEATSHEET.md) | All commands reference |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute knowledge |
| [CONTRIBUTING-ARTIFACTS.md](CONTRIBUTING-ARTIFACTS.md) | How to create and publish artifacts |
| [REGISTRY.md](REGISTRY.md) | Artifact component registry |
| [ROADMAP.md](ROADMAP.md) | Development roadmap and vision |
| [BEST_PRACTICES.md](BEST_PRACTICES.md) | Quality guidelines |
| [TERMINOLOGY.md](TERMINOLOGY.md) | Terms and icons |
| [TAGS.md](TAGS.md) | Tagging conventions |
| [FEDERATION.md](FEDERATION.md) | Cross-rig artifact sharing |
| [PHILOSOPHY.md](PHILOSOPHY.md) | The knowledge loop manifesto |

## 🌐 Fork Your Own Tavern

```bash
# Fork this repo, then:
./scripts/init-tavern.sh
```

This sets you up as the first Sheriff and cleans example content.

## 🔗 Integration with Gas Town

Rally Tavern integrates with the Gas Town multi-agent pipeline at three points:

**Before development — planning**
The Mayor's `agent-team` command searches `knowledge/` for relevant prior art before routing to `mol-idea-to-plan`. The rig's `tavern-profile.yaml` (tech stack, patterns, constraints) is included as context. Rally skills produce structured build cards that feed into Mayor convoys.

**During development — lookup**
Polecats search the artifact registry and knowledge base before implementing. A matching artifact means less work, fewer bugs, and consistent patterns across rigs.

**After development — contribution**
When a polecat completes a feature, new patterns, solutions, or postmortems are written to `knowledge/` and pushed. The `github_source` field on each entry links back to the public PR so other builders can see the full context.

```bash
# Mayor searches before planning
./scripts/knowledge.sh search "auth patterns"
./scripts/artifacts-search.sh "auth sso"

# Mayor contributes after work completes
git add knowledge/
git commit -m "Add: [summary from rig]"
git push
```

## See Also

- [Gas Town](https://github.com/steveyegge/gastown) — Multi-agent orchestration
- [Beads](https://github.com/steveyegge/beads) — Git-backed issue tracking

## License

MIT

---

*"Where Revolutionaries Gather"* 🍺
