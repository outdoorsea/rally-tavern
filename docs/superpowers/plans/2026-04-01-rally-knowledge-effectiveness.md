# Rally Tavern Knowledge Effectiveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rally_tavern knowledge actually reach agents in other rigs by curating the corpus (remove Gas Town ops noise) and wiring push-based delivery (formula overlays + CONTEXT.md).

**Architecture:** Two parallel workstreams. Workstream A (Tasks 1-4) curates the knowledge base — relocating Gas Town ops entries, removing noise, verifying transferable entries. Workstream B (Tasks 5-8) wires push-based delivery using pull-safe extension points: formula overlays for mol-polecat-work and mol-idea-to-plan, CONTEXT.md per rig, and barkeep activation. No upstream-tracked gastown files are modified.

**Tech Stack:** YAML knowledge entries, TOML formula overlays, Markdown CONTEXT.md files, bash scripting for snapshot regeneration.

**Beads:** rt-4ze (content curation, Tasks 1-4), rt-iuy (push delivery, Tasks 5-8)

---

## Workstream A: Content Curation (Bead rt-4ze)

### Task 1: Relocate Gas Town ops entries

Move 26 Gas Town operational entries from rally_tavern knowledge base to `gastown/crew/beercan/docs/ops-knowledge/`. These are accurate runbooks but only useful to Gas Town agents, not project rigs.

**Files:**
- Move from: `/Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/` (various subdirs)
- Move to: `/Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/` (new directory)

- [ ] **Step 1: Create destination directory**

```bash
mkdir -p /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge
```

- [ ] **Step 2: Move learned/ Gas Town ops entries**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
mv learned/gas-town-gt-done-every-session.yaml \
   learned/gas-town-homebrew-binary-shadow.yaml \
   learned/gas-town-temporal-language-inverts-dependencies.yaml \
   learned/gas-town-dolt-flatten-oldest-commit-trap.yaml \
   learned/gas-town-escalate-feedback-loop.yaml \
   /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/
```

- [ ] **Step 3: Move postmortems/ Gas Town ops entries**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
mv postmortems/2026-03-10-polecat-crash-loop-stale-hooks.yaml \
   postmortems/2026-03-15-dolt-rogue-server-cascade.yaml \
   /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/
```

- [ ] **Step 4: Move practices/ Gas Town ops entries**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
mv practices/dolt-server-recovery.yaml \
   practices/gas-town-bead-filing-correct-rig.yaml \
   practices/gas-town-beads-workflow.yaml \
   practices/gas-town-communication-mail-vs-nudge.yaml \
   practices/gas-town-deacon-plugins.yaml \
   practices/gas-town-dolt-diagnostics.yaml \
   practices/gas-town-dolt-orphan-cleanup.yaml \
   practices/gas-town-escalation-protocol.yaml \
   practices/gas-town-git-hygiene-gaps.yaml \
   practices/gas-town-git-worktree-discipline.yaml \
   practices/gas-town-molecule-formula-workflow.yaml \
   practices/gas-town-nudge-vs-escalate.yaml \
   practices/gas-town-persist-findings-session-survival.yaml \
   practices/gas-town-plugin-live-vs-repo.yaml \
   practices/gas-town-polecat-session-lifecycle.yaml \
   practices/gas-town-refinery-rig-beads-redirect.yaml \
   practices/gas-town-security-audits.yaml \
   practices/gas-town-upgrade-sequence.yaml \
   practices/gas-town-wisp-gc-timeout.yaml \
   practices/gas-town-witness-metadata-missing.yaml \
   practices/tool-upgrade-procedure.yaml \
   /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/
```

- [ ] **Step 5: Move solutions/ Gas Town ops entries**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
mv solutions/gas-town-beads-correct-flags.yaml \
   solutions/gas-town-dolt-flatten-syntax.yaml \
   solutions/gas-town-dolt-query-direct.yaml \
   solutions/gas-town-merge-queue-rejection-recovery.yaml \
   /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/
```

- [ ] **Step 6: Move repos/ Gas Town-specific entry**

```bash
mv /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/repos/ai-agents/gastown.yaml \
   /Users/jeremy/Documents/gt/gastown/crew/beercan/docs/ops-knowledge/
```

- [ ] **Step 7: Verify remaining files are all transferable**

```bash
find /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/ -name "*.yaml" | sort
```

Expected remaining files (~21 entries):
- `learned/multi-agent-context-sharing.yaml`
- `postmortems/2026-02-25-multi-agent-file-conflicts.yaml`
- `practices/hipaa-minimum-necessary-api.yaml`
- `practices/ios-background-processing.yaml`
- `practices/ios-credentials-keychain.yaml`
- `practices/ios-logging-pii.yaml`
- `practices/web-showcase-page.yaml`
- `solutions/github-actions-gitleaks-secrets-scan.yaml`
- `solutions/swift-sendable-nsmutablearray-box.yaml`
- `starters/fastapi-with-sqlite.yaml`
- `repos/ai-agents/beads.yaml`
- `repos/ai-agents/openclaw.yaml`
- `repos/dev-tools/claude-code.yaml`
- `repos/templates/fastapi-template.yaml`

- [ ] **Step 8: Commit in both repos**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "chore: relocate Gas Town ops knowledge to gastown repo

26 entries moved to gastown/crew/beercan/docs/ops-knowledge/.
Rally knowledge base now contains only transferable engineering patterns."

cd /Users/jeremy/Documents/gt/gastown/crew/beercan
git add docs/ops-knowledge/
git commit -m "docs: import Gas Town ops knowledge from rally_tavern

26 operational runbooks (dolt, polecats, beads, communication) relocated
from rally_tavern knowledge base. These are Gas Town-specific and belong
here, not in the cross-rig knowledge hub."
```

### Task 2: Remove generic and test entries

**Files:**
- Delete: `/Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/practices/tmux-mouse-support.yaml`
- Delete: `/Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/practices/staleness-canary-test.yaml`

- [ ] **Step 1: Remove generic entries**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
rm practices/tmux-mouse-support.yaml
rm practices/staleness-canary-test.yaml
```

- [ ] **Step 2: Commit**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "chore: remove generic and canary test knowledge entries

tmux-mouse-support: generic knowledge any LLM already has.
staleness-canary-test: test fixture, not real knowledge."
```

### Task 3: Verify transferable entries

Read each remaining entry and confirm it is accurate, actionable, and contains
information that wouldn't be obvious from reading the target codebase.

**Files:**
- Review: all remaining `.yaml` files under `/Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/`

- [ ] **Step 1: Read and verify each entry**

For each remaining knowledge file, check:
1. Is the information still technically accurate? (e.g., Swift 6 concurrency patterns — is the code correct?)
2. Is it actionable? (Does it tell you what to DO, not just what to know?)
3. Is it non-obvious? (Would an agent figure this out without the entry?)
4. Are tags and metadata correct for profile matching?

```bash
for f in $(find /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/ -name "*.yaml" | sort); do
  echo "=== $(basename $f) ==="
  head -20 "$f"
  echo ""
done
```

- [ ] **Step 2: Fix any issues found**

Update entries with incorrect information, missing tags, or weak actionability.
Each fix should improve the entry's usefulness to agents in other rigs.

- [ ] **Step 3: Commit fixes**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "fix: verify and update transferable knowledge entries

Reviewed all remaining entries for accuracy, actionability, and tags."
```

### Task 4: Rebuild snapshot.json

Regenerate the knowledge index to reflect the curated corpus.

**Files:**
- Modify: `/Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/snapshot.json`

- [ ] **Step 1: Check current snapshot format**

```bash
cat /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/snapshot.json | head -30
```

Understand the schema so we can regenerate it correctly.

- [ ] **Step 2: Regenerate snapshot.json**

Build a new snapshot from all remaining YAML files. The snapshot should index
every entry with its title, tags, category, and file path. Use the same schema
as the existing snapshot.

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge
# Script to regenerate — adapt based on existing schema found in Step 1
python3 -c "
import yaml, json, glob, os

entries = []
for path in sorted(glob.glob('**/*.yaml', recursive=True)):
    with open(path) as f:
        data = yaml.safe_load(f)
    if data:
        data['_file'] = path
        entries.append(data)

with open('snapshot.json', 'w') as f:
    json.dump({'generated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)', 'count': len(entries), 'entries': entries}, f, indent=2)
print(f'Indexed {len(entries)} entries')
"
```

- [ ] **Step 3: Verify snapshot**

```bash
cat /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/snapshot.json | python3 -m json.tool | head -20
```

Confirm entry count matches expected (~19 YAML files after curation).

- [ ] **Step 4: Commit**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "chore: rebuild knowledge snapshot after curation

Index now reflects curated corpus: ~19 transferable entries, zero Gas Town ops."
```

---

## Workstream B: Push-Based Delivery (Bead rt-iuy)

### Task 5: Create formula overlay for mol-polecat-work

Add rally knowledge check to the implement step and a nomination prompt to the
submit-and-exit step via formula overlay.

**Files:**
- Create: `/Users/jeremy/Documents/gt/formula-overlays/mol-polecat-work.toml`

- [ ] **Step 1: Create formula-overlays directory**

```bash
mkdir -p /Users/jeremy/Documents/gt/formula-overlays
```

- [ ] **Step 2: Verify the overlay system recognizes the directory**

```bash
gt formula overlay list 2>&1
```

Expected: empty list or directory listing (no errors).

- [ ] **Step 3: Write the overlay file**

Create `/Users/jeremy/Documents/gt/formula-overlays/mol-polecat-work.toml`:

```toml
# Rally Tavern knowledge injection for mol-polecat-work
# Appends rally knowledge check to implement step and nomination prompt to submit-and-exit

[[step-overrides]]
step_id = "implement"
mode = "append"
description = """

## Rally Knowledge Check
Before implementing, check for known patterns relevant to this task:
```
gt rally lookup <relevant-tags-from-your-issue>
```
If `gt rally` is unavailable, skip this step and proceed.
If results are returned, review them — known patterns prevent repeated work across rigs.
"""

[[step-overrides]]
step_id = "submit-and-exit"
mode = "append"
description = """

## Knowledge Contribution
If you discovered a reusable engineering pattern during this work (not Gas Town
ops, but patterns applicable to other projects — auth, security, testing, CI,
platform-specific gotchas), nominate it:
```
gt rally nominate --category <practice|solution|learned> \
  --title "..." --summary "..." --tags "..."
```
If `gt rally` is unavailable, skip this step.
"""
```

- [ ] **Step 4: Verify the overlay loads correctly**

```bash
gt formula overlay show mol-polecat-work 2>&1
```

Expected: shows both step overrides with correct step IDs and modes.

- [ ] **Step 5: Test that prime renders the overlay**

```bash
gt prime 2>&1 | grep -A5 "Rally Knowledge"
```

Expected: "Rally Knowledge Check" appears in the implement step output (only
visible if a polecat is primed with mol-polecat-work attached).

- [ ] **Step 6: Commit**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add /Users/jeremy/Documents/gt/formula-overlays/mol-polecat-work.toml
git commit -m "feat: add formula overlay for rally knowledge in mol-polecat-work

Appends rally lookup to implement step and nomination prompt to submit-and-exit.
Uses formula overlay system — survives gastown upstream pulls."
```

### Task 6: Create formula overlay for mol-idea-to-plan

Upgrade the rally search from optional/advisory to a concrete step in the
intake phase.

**Files:**
- Create: `/Users/jeremy/Documents/gt/formula-overlays/mol-idea-to-plan.toml`

- [ ] **Step 1: Write the overlay file**

Create `/Users/jeremy/Documents/gt/formula-overlays/mol-idea-to-plan.toml`:

```toml
# Rally Tavern knowledge injection for mol-idea-to-plan
# Appends required rally search to intake step

[[step-overrides]]
step_id = "intake"
mode = "append"
description = """

## Rally Knowledge (Required)
Search for known patterns and include results in the PRD draft under
`## Known Patterns`:
```
gt rally search --profile --limit 5
```
If rally_tavern is unavailable, note "Rally: unavailable" and proceed.
If results are found, reference them in the PRD so the implementation plan
can leverage existing solutions instead of reinventing them.
"""
```

- [ ] **Step 2: Verify the overlay loads correctly**

```bash
gt formula overlay show mol-idea-to-plan 2>&1
```

Expected: shows step override for intake with append mode.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add /Users/jeremy/Documents/gt/formula-overlays/mol-idea-to-plan.toml
git commit -m "feat: add formula overlay for rally knowledge in mol-idea-to-plan

Appends required rally search to intake step. Results go into PRD under
Known Patterns section. Uses formula overlay — survives upstream pulls."
```

### Task 7: Create CONTEXT.md for rigs with tavern profiles

Add a static CONTEXT.md to each rig that has a tavern-profile.yaml. This puts
rally commands in every agent's prime output.

**Files:**
- Create: `/Users/jeremy/Documents/gt/vitalitek/CONTEXT.md`
- Create: `/Users/jeremy/Documents/gt/meety_me/CONTEXT.md`
- Create: `/Users/jeremy/Documents/gt/theoutlived/CONTEXT.md`
- Create: `/Users/jeremy/Documents/gt/switchyard/CONTEXT.md`
- Create: `/Users/jeremy/Documents/gt/gastown/CONTEXT.md`

Note: Only create CONTEXT.md for rigs that don't already have one. Check first
and append to existing files rather than overwriting.

- [ ] **Step 1: Check which rigs already have CONTEXT.md**

```bash
for rig in vitalitek meety_me theoutlived switchyard gastown; do
  if [ -f "/Users/jeremy/Documents/gt/$rig/CONTEXT.md" ]; then
    echo "$rig: EXISTS"
  else
    echo "$rig: MISSING"
  fi
done
```

- [ ] **Step 2: Create CONTEXT.md for each rig without one**

For each rig that reported MISSING, create the file:

```markdown
## Rally Tavern Knowledge

This rig has a tavern profile. Known engineering patterns are available:
- `gt rally search --profile` — patterns matched to this rig's tech stack
- `gt rally lookup <tag>` — look up a specific pattern by tag
- `gt rally nominate` — contribute a pattern you discovered during this work
```

For rigs that already have CONTEXT.md, append the above section to the end.

- [ ] **Step 3: Verify injection works**

Pick one rig and test:

```bash
GT_ROLE=vitalitek/crew/test gt prime 2>&1 | grep -A5 "Rally Tavern Knowledge"
```

Expected: the rally section appears in prime output.

- [ ] **Step 4: Commit**

Each rig's CONTEXT.md should be committed in that rig's repo if it has one,
or noted if the rig directory isn't a git repo.

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "feat: add CONTEXT.md with rally knowledge pointers to project rigs

Agents in vitalitek, meety_me, theoutlived, switchyard, and gastown now see
rally commands in their prime output."
```

### Task 8: Activate barkeep nomination flow

Ensure the barkeep plugin is registered and running so nominations get processed.

**Files:**
- Review: `/Users/jeremy/Documents/gt/rally_tavern/crew/franklin/plugins/barkeep/`
- Modify: barkeep plugin config as needed for deacon registration

- [ ] **Step 1: Read barkeep plugin structure**

```bash
ls -la /Users/jeremy/Documents/gt/rally_tavern/crew/franklin/plugins/barkeep/
cat /Users/jeremy/Documents/gt/rally_tavern/crew/franklin/plugins/barkeep/plugin.md
```

Understand what barkeep expects: mail routing, patrol frequency, acceptance criteria.

- [ ] **Step 2: Verify barkeep mail address is routable**

```bash
gt mail send rally_tavern/barkeep -s "TEST: Barkeep routing check" -m "Testing that mail reaches barkeep. This is a test message — discard." --dry-run 2>&1
```

Expected: dry-run shows the message would be sent to rally_tavern/barkeep.

- [ ] **Step 3: Check deacon patrol registration**

```bash
# Check if barkeep is in the deacon config
cat /Users/jeremy/Documents/gt/rally_tavern/settings/config.json 2>/dev/null
# Also check deacon plugin directory
ls /Users/jeremy/Documents/gt/rally_tavern/plugins/ 2>/dev/null
```

If barkeep is not registered in the deacon patrol, add it to the appropriate
config so it runs on the deacon's patrol cycle.

- [ ] **Step 4: Send a test nomination**

```bash
gt rally nominate --category practice \
  --title "Test Nomination — Barkeep Activation" \
  --summary "Test entry to verify barkeep processes nominations" \
  --tags "test,barkeep" \
  --dry-run 2>&1
```

Verify the nomination format is correct and would route to barkeep.

- [ ] **Step 5: Commit any config changes**

```bash
cd /Users/jeremy/Documents/gt/rally_tavern/crew/franklin
git add -A
git commit -m "feat: activate barkeep nomination flow

Barkeep registered in deacon patrol. Nomination mail routing verified.
Agents can now nominate knowledge via gt rally nominate."
```

---

## Verification

After both workstreams complete:

- [ ] **V1: Knowledge corpus is clean**

```bash
find /Users/jeremy/Documents/gt/rally_tavern/mayor/rig/knowledge/ -name "*.yaml" | wc -l
```

Expected: ~19 files, zero with `gas-town-` prefix.

- [ ] **V2: Formula overlays load**

```bash
gt formula overlay list 2>&1
```

Expected: shows mol-polecat-work.toml and mol-idea-to-plan.toml.

- [ ] **V3: CONTEXT.md injected in project rigs**

```bash
cat /Users/jeremy/Documents/gt/vitalitek/CONTEXT.md
```

Expected: contains "Rally Tavern Knowledge" section.

- [ ] **V4: Rally search returns only transferable knowledge**

```bash
gt rally search --limit 20 2>&1
```

Expected: results contain HIPAA, iOS, Swift, security entries — zero Gas Town ops.
