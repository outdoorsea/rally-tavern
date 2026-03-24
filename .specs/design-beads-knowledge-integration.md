# Design Spec: Beads ↔ Rally Tavern Knowledge Integration

> Linking knowledge provenance to beads, enabling dependency-aware knowledge
> push, and automating the nomination-to-corpus lifecycle.
>
> Author: crew/max | Date: 2026-03-17

---

## 1. Problem Statement

Rally Tavern's knowledge base and Gas Town's beads system operate in parallel
but are structurally disconnected. This creates three concrete problems:

1. **No provenance.** Knowledge entries float free — there's no way to trace a
   practice back to the bead (and therefore the code, PR, and agent) that
   produced it. When knowledge is questioned, there's no audit trail.

2. **Keyword-only matching.** `knowledge-push.sh` matches on tags and title
   words. This misses contextually adjacent knowledge — entries related to
   parent, sibling, or predecessor beads in the same work graph.

3. **Manual lifecycle.** Staleness detection is manual (canary experiment
   `024fee6`). Nomination is opt-in at `gt done` time. There's no signal when
   a knowledge entry's source work has been superseded or invalidated.

Beads already tracks the dependency graph, audit trail, and lifecycle state of
every unit of work. Connecting these two systems closes the loop.

---

## 2. Goals & Non-Goals

### Goals

| # | Goal | Measurable outcome |
|---|------|--------------------|
| G1 | Every knowledge entry traces to its source bead(s) | 100% of new entries have `source_beads` field |
| G2 | Knowledge push uses bead dependency graph | `knowledge-push.sh --bead <id>` walks relations |
| G3 | Bead closure triggers nomination prompt | Polecats prompted at `bd close` when work is novel |
| G4 | Superseded beads flag linked knowledge for review | `knowledge stale` surfaces graph-invalidated entries |
| G5 | Artifact registry uses `bd ship` for publishing | TCEP artifacts discoverable via `bd search` |

### Non-Goals

- Replacing Rally Tavern's YAML knowledge format with beads
- Migrating existing knowledge entries retroactively (can be done later)
- Building a UI — all interactions remain CLI
- Changing beads' core schema (use labels, links, and comments only)

---

## 3. Design

### 3.1 Knowledge ↔ Bead Linking (G1)

**Schema change:** Add optional `source_beads` field to knowledge YAML entries.

```yaml
# knowledge/practices/example.yaml
id: example-practice
title: Example Practice
source_beads: [rt-a1b2, gt-c3d4]   # NEW — beads that produced this knowledge
contributed_by: polecat/rust
created_at: 2026-03-17T00:00:00Z
# ... rest unchanged
```

**Why a list:** A single insight often emerges from multiple beads — a bug fix
that revealed a pattern, plus the follow-up bead that validated it.

**Backlink in beads:** When knowledge is accepted, add a `knowledge:` label to
the source bead(s) so the link is bidirectional:

```bash
bd label add rt-a1b2 knowledge:dolt-server-recovery
```

This uses beads' existing label system — no schema changes to beads.

**Validation:** `knowledge.sh add` and `tavern.nominate` MCP tool updated to
accept and propagate `source_beads`. Template updated.

### 3.2 Dependency-Aware Knowledge Push (G2)

**New flag:** `knowledge-push.sh --bead <bead-id>`

When invoked with a bead ID instead of (or in addition to) tags/title:

1. Resolve the bead: `bd show <id> --json`
2. Walk the relation graph (depth 2):
   - `relates_to`, `blocks`/`blocked_by`, parent/child
   - Collect bead IDs in the neighborhood
3. For each bead in the neighborhood, check if any knowledge entry has a
   matching `source_beads` value
4. Also extract tags from all neighborhood beads and run the existing
   tag-matching logic as a fallback
5. Merge, deduplicate, and rank results (graph-linked entries rank higher
   than tag-matched)

**Implementation:**

```bash
# New: scripts/knowledge-bead-walk.sh
# Input: bead ID
# Output: JSON array of related bead IDs + their tags

bd show "$BEAD_ID" --json | jq '{
  id: .id,
  tags: .labels,
  relates_to: [.links[] | select(.type == "relates_to") | .target],
  parent: .parent,
  children: [.children[].id]
}'

# Then for each related bead, repeat one level deep
```

**Integration with `gt sling`:** When a polecat is slung a bead, `gt sling`
already calls `knowledge-push.sh --tags`. Add `--bead $BEAD_ID` to the
invocation so the polecat receives graph-aware knowledge automatically.

### 3.3 Auto-Nomination on Bead Close (G3)

**Hook point:** `bd close` supports post-close hooks via beads formulas.
Alternatively, Rally Tavern can register a Gas Town hook.

**Flow:**

```
Polecat completes work
  → bd close <bead-id>
    → post-close hook fires
      → scripts/knowledge-nominate-check.sh <bead-id>
        → Heuristics:
          1. Did the bead's comments mention a workaround, gotcha, or pattern?
          2. Was the bead reopened at least once? (indicates non-obvious fix)
          3. Does the bead have children? (indicates decomposed problem)
          4. Is the bead type = bug or incident? (high knowledge value)
        → If score >= threshold:
          → Prompt polecat: "This bead looks like it contains reusable knowledge.
             Nominate? [Y/n]"
          → If yes: pre-fill nomination from bead title, labels, and comments
```

**Heuristic scoring:**

| Signal | Points | Rationale |
|--------|--------|-----------|
| Bead was reopened | +3 | Non-obvious problem, worth documenting |
| Bead has >2 comments | +2 | Discussion = nuance worth capturing |
| Bead type is bug/incident | +2 | Failure modes are high-value knowledge |
| Bead has children | +1 | Decomposed = complex enough to document |
| Bead blocked other work | +1 | Impact = worth sharing |
| Bead labels include `gotcha` or `workaround` | +3 | Explicit signal |

**Threshold:** 3 points triggers the prompt. This is configurable via
`tavern-profile.yaml`:

```yaml
knowledge:
  auto_nominate_threshold: 3  # default
```

**Non-interactive mode:** For polecats running autonomously (no human in the
loop), skip the prompt and create a nomination bead instead:

```bash
bd create --type=nomination "Knowledge candidate from $BEAD_ID" \
  --label "auto-nominated" \
  --link "relates_to:$BEAD_ID"
```

The Historian reviews nomination beads asynchronously.

### 3.4 Graph-Aware Staleness Detection (G4)

**Mechanism:** When a bead is closed with `supersedes` link, check if the
superseded bead has linked knowledge:

```
bd close rt-new --link "supersedes:rt-old"
  → post-close hook
    → Is rt-old linked to any knowledge entry? (check rt-old's labels for knowledge:*)
      → If yes: flag the knowledge entry for review
        → Add `needs_review: true` and `staleness_reason: "superseded by rt-new"`
        → Optionally: bd create --type=task "Review knowledge: <entry-id>"
```

**Periodic sweep:** `scripts/knowledge-stale.sh` enhanced to also check:

```bash
# For each knowledge entry with source_beads:
for bead in source_beads:
  # Check if bead has been superseded
  bd show $bead --json | jq '.links[] | select(.type == "superseded_by")'
  # Check if bead's area has high recent activity (churn = staleness risk)
  bd query "label:$area state:open created:>-30d" --count
```

This replaces the manual canary approach with a structural signal.

### 3.5 Artifact Registry via `bd ship` (G5)

**Current state:** TCEP artifacts are YAML manifests in
`artifacts/io.github.rally-tavern/`. Federated search is a custom bash script.

**Proposed:** Publish artifacts as beads with `bd ship`, which provides:
- Cross-project dependency tracking (built into beads)
- Version history via Dolt
- Discoverability via `bd search`
- Trust tiers map to bead labels: `trust:experimental`, `trust:community`,
  `trust:verified`

**Migration path:**

1. Keep YAML manifests as the source of truth (they contain rich metadata)
2. `artifact.sh register` now also runs `bd ship` to publish a bead
3. `artifacts-search.sh` tries `bd search` first, falls back to local YAML
4. Federated search (`artifact-federated-search.sh`) uses `bd search` across
   rigs instead of custom index files

**Bead format for shipped artifact:**

```bash
bd ship "python-fastapi-sso-starter" \
  --type=artifact \
  --label "trust:community" \
  --label "stack:python,fastapi" \
  --label "tokens-saved:45000" \
  --field "manifest_path=artifacts/io.github.rally-tavern/python-fastapi-sso-starter/manifest.yaml"
```

---

## 4. MCP Server Changes

Update `mcp-server/src/index.ts` with new/modified tools:

| Tool | Change | Description |
|------|--------|-------------|
| `tavern.nominate` | Modified | Accept optional `source_beads` param, create backlinks |
| `tavern.search` | Modified | Accept optional `bead` param for graph-aware search |
| `tavern.stale` | New | Return knowledge entries flagged by graph staleness |
| `tavern.linkBead` | New | Retroactively link a knowledge entry to a bead |

---

## 5. Implementation Phases

### Phase 1: Linking (G1) — ~2 hours

1. Update knowledge YAML template with `source_beads` field
2. Update `knowledge.sh add` to accept `--bead` flag
3. Update `tavern.nominate` MCP tool to accept and store `source_beads`
4. Add backlink logic: label source beads with `knowledge:<entry-id>`
5. Update `knowledge-push.sh` help text

**Files touched:**
- `templates/knowledge-practice.yaml`, `templates/solution.yaml`
- `scripts/knowledge.sh`
- `mcp-server/src/index.ts`

**Dependency:** None. Can ship independently.

### Phase 2: Graph-Aware Push (G2) — ~3 hours

1. New script: `scripts/knowledge-bead-walk.sh`
2. Modify `knowledge-push.sh` to accept `--bead` and call the walker
3. Update ranking logic: graph-linked > tag-matched > title-matched
4. Update `gt sling` integration point (if Rally Tavern controls it)

**Files touched:**
- New: `scripts/knowledge-bead-walk.sh`
- Modified: `scripts/knowledge-push.sh`

**Dependency:** Phase 1 (needs `source_beads` field populated).

### Phase 3: Auto-Nomination (G3) — ~3 hours

1. New script: `scripts/knowledge-nominate-check.sh`
2. Heuristic scoring engine (bead analysis)
3. Hook registration (Gas Town post-close hook or beads formula)
4. Non-interactive mode: create nomination beads for autonomous polecats
5. Config in `tavern-profile.yaml`

**Files touched:**
- New: `scripts/knowledge-nominate-check.sh`
- Modified: `templates/tavern-profile.yaml`

**Dependency:** Phase 1 (nomination creates entries with `source_beads`).

### Phase 4: Graph Staleness (G4) — ~2 hours

1. Post-close hook for `supersedes` links
2. Enhanced `scripts/knowledge-stale.sh` with graph signals
3. `tavern.stale` MCP tool

**Files touched:**
- Modified: `scripts/knowledge-stale.sh`
- Modified: `mcp-server/src/index.ts`

**Dependency:** Phase 1. Can run in parallel with Phase 2/3.

### Phase 5: Artifact Shipping (G5) — ~3 hours

1. Modify `artifact.sh register` to also `bd ship`
2. Modify `artifacts-search.sh` to query beads first
3. Update `artifact-federated-search.sh` to use `bd search`
4. Trust tier → label mapping

**Files touched:**
- Modified: `scripts/artifact.sh`
- Modified: `scripts/artifacts-search.sh`
- Modified: `scripts/artifact-federated-search.sh`

**Dependency:** None. Independent of Phases 1-4.

---

## 6. Dependency Graph

```
Phase 1 (Linking)
  ├── Phase 2 (Graph Push)     ← needs source_beads populated
  ├── Phase 3 (Auto-Nominate)  ← nominations create source_beads
  └── Phase 4 (Staleness)      ← reads source_beads for graph walk

Phase 5 (Artifact Ship)        ← independent, can start anytime
```

Phases 2, 3, and 4 can run in parallel after Phase 1.

---

## 7. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `bd show --json` output format changes | Push breaks | Low | Pin to bd version; validate JSON schema |
| Graph walk on large bead graphs is slow | Polecat startup delay | Medium | Cap walk depth at 2; cache results in snapshot.json |
| Auto-nomination creates noise | Historian overwhelmed | Medium | Tunable threshold; start high (5), lower as trust builds |
| Dolt stress from backlink labels | Server fragility | Low | Batch label operations; use `--dolt-auto-commit=batch` |
| Polecats don't populate `source_beads` | Graph stays empty | High | Auto-fill from hooked bead at nomination time (fallback) |

**Critical risk:** The biggest threat is adoption — if polecats don't pass
`source_beads`, the graph stays disconnected. Mitigation: **auto-fill from the
polecat's hooked bead** at nomination time. Since polecats always have a hooked
bead (`gt hook` returns it), the nomination script can grab it automatically.
This makes the link zero-effort for the polecat.

---

## 8. Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Knowledge entries with source_beads | >80% of new entries (30 days post-launch) | `grep -l source_beads knowledge/**/*.yaml \| wc -l` |
| Graph-push hit rate | >30% of pushes return graph-linked results | Log in knowledge-push.sh, aggregate weekly |
| Auto-nomination acceptance rate | >40% of prompted nominations accepted | Count nomination beads vs accepted entries |
| Staleness detection lead time | Flag stale entries within 48h of supersede | Compare supersede timestamp to flag timestamp |
| Time-to-knowledge for polecats | Reduce repeated solutions by 50% | Before/after count of duplicate knowledge nominations |

---

## 9. Open Questions

1. **Hook mechanism:** Should auto-nomination use a beads post-close formula,
   a Gas Town hook, or a dedicated `gt done` integration? Each has different
   reliability and agent-visibility trade-offs.

2. **Retroactive linking:** Should we backfill `source_beads` on existing
   knowledge entries by mining git blame + commit messages for bead IDs?
   Low-cost, medium-value.

3. **Cross-rig knowledge:** When a bead is moved between rigs (`bd move`),
   should its linked knowledge entries follow? Or stay in the originating
   rig's corpus?

4. **`bd recall` integration:** Beads has `bd remember`/`bd recall` for
   persistent agent memory. Should Rally Tavern knowledge be searchable via
   `bd recall`, or should these remain separate systems? Merging them would
   give agents a single search surface but blurs the curation boundary.
