+++
name = "barkeep"
description = "Curate Rally Tavern knowledge base — process nominations and reports from agents"
version = 1

[gate]
type = "cooldown"
duration = "10m"

[tracking]
labels = ["plugin:barkeep", "rig:rally_tavern", "category:knowledge"]
digest = true

[execution]
timeout = "10m"
notify_on_failure = true
severity = "medium"
+++

# Barkeep — Rally Tavern Knowledge Curator

The **Barkeep** tends the Rally Tavern knowledge base by processing nominations
and reports from agents across all rigs.

This is a **single-pass** plugin. Check the inbox, process what's there, exit.
The Deacon dispatches you on a cooldown — you do not loop.

## Step 1: Check Inbox

```bash
gt mail inbox --to rally_tavern/barkeep
```

Look for messages with subject prefix `RALLY_NOMINATION:` or `RALLY_REPORT:`.

If inbox is empty, record a skip wisp and exit:
```bash
bd create --wisp-type patrol \
  --labels type:plugin-run,plugin:barkeep,rig:rally_tavern,result:skipped \
  --description "No pending nominations or reports" \
  "Plugin: barkeep [skipped]"
```

If inbox has > 10 messages, process only the first 5 this cycle.

## Step 2: Process RALLY_NOMINATION Messages

For each message with subject prefix `RALLY_NOMINATION:`:

### Read it

```bash
gt mail read <msg-id>
```

The body starts with `RALLY_NOMINATION_V1` followed by YAML. Key fields:
- `category`: practice | solution | learned
- `title`: short name
- `summary`: one-liner
- `details`: full write-up (may be empty)
- `tags`: searchable tags
- `nominated_by`: which agent sent it
- `nomination_id`: unique ID like `nom-a3f9c2`

### Review against quality bar

**Accept** if the nomination is:
- **Specific and actionable** — not "be careful with X" but "do Y when Z happens"
- **Has a clear summary** — value graspable in one sentence
- **Not a duplicate** — check: `gt rally search "<title keywords>"`
- **General enough to reuse** — applies beyond the one task that produced it

**Reject** if:
- Too vague or opinion-only
- Duplicate of existing knowledge
- Too narrow to help future agents
- Missing required fields

When in doubt, **accept with light editing**. 80% polished beats never written.

### If accepting

**Generate filename** using kebab-case from title + 6-hex suffix from `nomination_id`:
```
knowledge/<category>s/<kebab-title>-<hex-suffix>.yaml
```

**Write the YAML file** to the rally_tavern knowledge directory:

```yaml
id: <slug-with-suffix>
title: <from nomination>
contributed_by: <nominated_by field>
contributor_type: agent
created_at: <nominated_at field>
verified_by: []
codebase_type: <from nomination, or omit if empty>
summary: |
  <from nomination>
details: |
  <from nomination>
tags: [<from nomination>]
```

Add category-specific fields as appropriate:
- **practice**: `gotchas`, `examples`
- **solution**: `problem`, `solution`
- **learned**: `context`, `lesson`

Omit empty optional fields.

**Commit:**
```bash
cd $RALLY_TAVERN_ROOT   # or ~/gt/rally_tavern if unset
git add -f knowledge/<category>s/<filename>
git commit -m "Add: <title> (from <nominated_by>, <nomination_id>)"
git push
```

Note: `knowledge/` may be gitignored in some layouts — use `git add -f`.

**Reply to nominator:**
```bash
gt mail send <nominated_by> \
  -s "Re: RALLY_NOMINATION: <title> [<category>]" \
  -m "Accepted. Written to knowledge/<category>s/<filename>.yaml — thanks."
```

### If rejecting

```bash
gt mail send <nominated_by> \
  -s "Re: RALLY_NOMINATION: <title> [<category>]" \
  -m "Not accepted: <brief reason>. <What would make it acceptable.>"
```

### Archive processed messages

```bash
gt mail archive <msg-id>
```

## Step 3: Process RALLY_REPORT Messages

For each message with subject prefix `RALLY_REPORT:`:

```bash
gt mail read <msg-id>
```

Body starts with `RALLY_REPORT_V1` followed by YAML. Key fields:
- `entry_id` or `entry_tag`: which entry
- `kind`: stale | wrong | improve | verify
- `reason` / `improvement`: details
- `reported_by`: which agent

**verify** — Update `last_verified` in the YAML, commit:
```bash
git commit -m "Verify: <entry_id> (confirmed by <reported_by>)"
```

**stale/wrong** — Mark `deprecated: true` or edit to correct. Commit with reason.

**improve** — Apply if it adds value. Commit with what changed.

Reply to reporter for stale/wrong/improve. Archive all processed messages.

## Step 4: Record Result

```bash
bd create --wisp-type patrol \
  --labels type:plugin-run,plugin:barkeep,rig:rally_tavern,result:success \
  --description "Processed N nominations (A accepted, R rejected), M reports" \
  "Plugin: barkeep [success]"
```

On failure:
```bash
bd create --wisp-type patrol \
  --labels type:plugin-run,plugin:barkeep,rig:rally_tavern,result:failure \
  --description "Failed: $ERROR" \
  "Plugin: barkeep [failure]"

gt escalate --severity=medium \
  --subject="Plugin FAILED: barkeep" \
  --body="$ERROR" \
  --source="plugin:barkeep"
```

## Quality Bar Examples

**ACCEPT:**
- "Enable tmux mouse support: add `setw -g mouse on` to ~/.tmux.conf" — specific, reproducible
- "gt dolt sql -e doesn't exist — use mysql directly" — saves agents from a footgun
- "Dolt flatten timing: don't flatten if newest commit < 2h old" — concrete rule

**REJECT:**
- "Always write good commit messages" — too vague
- "Dolt can be slow sometimes" — no actionable advice
- Duplicate of existing entry with no new information
