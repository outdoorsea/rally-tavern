# Rally Tavern Knowledge Effectiveness Fix

**Date:** 2026-04-01
**Author:** franklin (rally_tavern crew)
**Status:** Approved

## Problem

Rally Tavern was built as a cross-rig knowledge sharing hub, but other rigs
aren't benefitting from it. Investigation revealed three root causes:

1. **Content mix:** 26 of 54 knowledge entries (48%) are Gas Town operational
   runbooks (dolt diagnostics, polecat lifecycle, gt done discipline). These are
   accurate but useless to project rigs like vitalitek or meety_me.

2. **Pull-based delivery:** The only integration point is an optional advisory
   step in `mol-idea-to-plan` (line 90) that agents routinely skip.
   `mol-polecat-work` has zero rally integration. `gt prime` injects nothing.

3. **Dead flywheel:** Barkeep inbox is empty — zero nominations ever processed.
   Knowledge was manually seeded on 2026-03-17 and hasn't changed since.

## Constraints

- **Upstream safety:** `gastown/crew/beercan` tracks `steveyegge/gastown` as
  upstream. Any changes to `prime.go`, formula source files, or `AGENTS.md` get
  overwritten on `git pull upstream main`. All delivery changes must use
  extension points that live outside the gastown git tree.

- **Pull-safe extension points available:**
  - **Formula overlays** at `<townRoot>/formula-overlays/<formulaName>.toml` —
    append/replace/skip formula steps without modifying base files. Loaded at
    prime time, survive upstream pulls.
  - **CONTEXT.md** at each rig root — injected into every agent's prime output
    after role context. Static file, not tracked by gastown upstream.
  - **Barkeep plugin** in rally_tavern's own repo — not upstream-tracked.

## Design

Two parallel workstreams.

### Workstream A: Content Curation

**Goal:** Transform the knowledge base from ~50 entries (48% noise) to ~25-30
entries (100% transferable signal).

#### A1. Relocate Gas Town ops entries

Move the 26 Gas Town operational entries out of rally_tavern's knowledge base.
These belong in Gas Town's own documentation, not in a cross-rig knowledge hub.

**Entries to relocate** (all prefixed `gas-town-*` plus dolt-specific entries):

| Category | Count | Examples |
|----------|-------|---------|
| Dolt operations | 7 | server recovery, diagnostics, orphan cleanup, flatten syntax, query direct, rogue server cascade |
| Polecat lifecycle | 5 | gt done, session lifecycle, persist findings, crash loop, worktree discipline |
| Beads workflow | 4 | beads workflow, bead filing, correct flags, temporal language |
| Communication | 3 | mail vs nudge, nudge vs escalate, escalation protocol |
| Gas Town meta | 7 | deacon plugins, molecule formulas, git hygiene, upgrade sequence, plugin live vs repo, security audits, refinery redirect, wisp GC, witness metadata, homebrew shadow, escalate feedback loop |

**Destination:** These entries should be consolidated into
`gastown/crew/beercan/docs/ops/` or equivalent — they're operational runbooks
for the gastown project itself.

#### A2. Remove generic entries

Delete the 1 generic entry (tmux mouse support) and the canary test entry that
exists only for staleness detection.

#### A3. Keep and verify transferable entries

Retain the 21 transferable entries. Verify each is still accurate and actionable:

- HIPAA minimum necessary API design
- Swift 6 Sendable box pattern
- iOS background processing, keychain credentials, PII logging
- GitHub Actions gitleaks secrets scan
- Multi-agent file conflict prevention (postmortem)
- Multi-agent context sharing
- Web showcase page / CSS design system
- FastAPI with SQLite starter
- Repository references (beads, openclaw, claude-code, fastapi-template)

#### A4. Seed new transferable entries

Mine recent bead history across rigs for 5-10 patterns that recurred
independently. Candidates:

- Auth token refresh/rotation patterns (vitalitek, meety_me)
- Database migration strategies (multiple rigs use different ORMs)
- CI pipeline configurations solved independently by multiple rigs
- Error handling patterns for external API integrations
- Test fixture patterns across languages

#### A5. Rebuild snapshot.json

Regenerate the knowledge index to reflect the curated corpus.

### Workstream B: Push-Based Delivery

**Goal:** Agents in other rigs see relevant knowledge without asking for it,
using only pull-safe extension points.

#### B1. Formula overlay for mol-polecat-work

Create `<townRoot>/formula-overlays/mol-polecat-work.toml` that appends a rally
knowledge check to the implement step:

```toml
[[step-overrides]]
step_id = "implement"
mode = "append"
description = """

## Rally Knowledge Check
Before implementing, check for known patterns relevant to this task:
```bash
gt rally lookup <tags-from-your-issue>
```
If results are returned, review them before writing code. Known patterns
prevent repeated work across rigs.
"""
```

This is a real step appended to the implement phase, not an advisory footnote.
Agents see it as part of their formula checklist.

#### B2. Formula overlay for mol-idea-to-plan

Create `<townRoot>/formula-overlays/mol-idea-to-plan.toml` that replaces the
existing advisory rally search with a concrete step:

```toml
[[step-overrides]]
step_id = "intake"
mode = "append"
description = """

## Rally Knowledge (Required)
Run the following and include results in the PRD draft under
`## Known Patterns`:
```bash
gt rally search --profile --limit 5
```
If rally_tavern is unavailable, note "Rally: unavailable" and proceed.
"""
```

#### B3. CONTEXT.md per rig

For each rig that has a `tavern-profile.yaml`, create or update a `CONTEXT.md`
at the rig root with a static rally knowledge section. This gets injected into
every agent's prime output.

Content should be short (under 10 lines) and point agents to rally commands:

```markdown
## Rally Tavern Knowledge

This rig has a tavern profile. Known engineering patterns are available:
- `gt rally search --profile` — search patterns matched to this rig's tech stack
- `gt rally lookup <tag>` — look up a specific pattern by tag
- `gt rally nominate` — contribute a pattern you discovered during this work
```

#### B4. Barkeep activation

The barkeep plugin (`rally_tavern/crew/franklin/plugins/barkeep/`) exists but
has never processed a nomination. Activate it:

1. Ensure barkeep is registered in the deacon patrol cycle
2. Verify the nomination mail routing (`rally_tavern/barkeep` address)
3. Add a nomination prompt to mol-polecat-work's self-clean step via overlay:

```toml
[[step-overrides]]
step_id = "self-clean"
mode = "append"
description = """

## Knowledge Contribution
If you discovered a reusable pattern during this work (not Gas Town ops,
but engineering patterns applicable to other projects), nominate it:
```bash
gt rally nominate --category <practice|solution|learned> \
  --title "..." --summary "..." --tags "..."
```
"""
```

#### B5. Barkeep patrol for CONTEXT.md refresh

Add a barkeep patrol task that periodically regenerates CONTEXT.md files for
rigs based on their tavern-profile. This keeps the static CONTEXT.md files
fresh as new knowledge enters the corpus.

Frequency: weekly or on knowledge base change (whichever is simpler to
implement).

## What This Does NOT Include

- No changes to upstream-tracked gastown files (prime.go, formula sources,
  AGENTS.md)
- No new MCP server work (exists but isn't the bottleneck)
- No federation architecture changes (spoke model is fine)
- No changes to `gt rally search` CLI (it works)
- No new tavern-profile.yaml authoring (11 profiles already exist)

## Bead Structure

Two beads, assignable to polecats in parallel:

| Bead | Workstream | Steps | Soft dependency |
|------|-----------|-------|-----------------|
| **rally-content-curation** | A | A1-A5 | None |
| **rally-push-delivery** | B | B1-B5 | Content should merge first (delivery over noise trains agents to ignore results) |

**rally-content-curation:**
- Relocate 26 Gas Town ops entries to gastown/docs/ops/
- Remove generic entries
- Verify 21 transferable entries
- Seed 5-10 new cross-project patterns
- Rebuild snapshot.json

**rally-push-delivery:**
- Create formula overlay for mol-polecat-work (implement + self-clean steps)
- Create formula overlay for mol-idea-to-plan (intake step)
- Create/update CONTEXT.md for rigs with tavern profiles
- Activate barkeep nomination flow
- Add barkeep patrol for CONTEXT.md refresh

## Success Criteria

1. An agent priming in vitalitek sees a `## Rally Tavern Knowledge` section in
   its prime output pointing to rally commands.
2. A polecat working mol-polecat-work sees "Rally Knowledge Check" as a real
   step in its implement phase and runs `gt rally lookup`.
3. The knowledge corpus contains zero Gas Town operational entries — only
   transferable engineering patterns.
4. At least one organic nomination flows through barkeep within 2 weeks of
   deployment.
