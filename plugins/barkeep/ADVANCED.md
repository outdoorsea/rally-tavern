# Barkeep Advanced Mode: Persistent Crew Patrol

The default barkeep runs as a **deacon plugin** — a dog gets dispatched every 10
minutes, does one pass through the inbox, and exits. This is zero-friction and
works well for most deployments.

For power users who want continuous knowledge curation with richer context, the
barkeep can run as a **persistent crew member** using the full patrol formula.

## Why Crew Mode?

| | Plugin (default) | Crew patrol (advanced) |
|---|------------------|------------------------|
| **Context** | Fresh each cycle — no memory between passes | Accumulates understanding across nominations |
| **Hygiene** | No staleness scanning | Periodic knowledge health checks (every 10th cycle) |
| **Pattern recognition** | Each nomination reviewed in isolation | Can spot duplicate themes, suggest merges |
| **Cost** | Lightweight — dog session per dispatch | Persistent Claude session (higher token usage) |
| **Supervision** | Fully automatic via deacon | User-managed — must start manually |
| **Recovery** | Deacon re-dispatches automatically | No auto-restart if session dies |

Crew mode is worth it when:
- Your knowledge base has >50 entries and needs active curation
- Multiple rigs are nominating frequently (>5/day)
- You want staleness scanning and hygiene checks
- You care about editorial consistency across nominations

## Setup

### 1. Disable the plugin (avoid double-processing)

Change the gate in `$GT_ROOT/plugins/barkeep/plugin.md` to manual:

```toml
[gate]
type = "manual"
```

Or remove the symlink/copy from `$GT_ROOT/plugins/barkeep/` entirely.

### 2. Add barkeep as a crew member

```bash
gt crew add barkeep rally_tavern
```

This creates a crew workspace at `rally_tavern/crew/barkeep/`.

### 3. Configure the crew member's context

Create `rally_tavern/crew/barkeep/CLAUDE.md` with:

```markdown
# Barkeep — Rally Tavern Knowledge Curator

You are the Barkeep. On startup, run the barkeep patrol formula:

\`\`\`bash
gt formula run mol-barkeep-patrol
\`\`\`

This loops continuously: check inbox, process nominations/reports, run
knowledge hygiene, check context limits, sleep, repeat.

Your mail address is `rally_tavern/barkeep`.

When context gets high (>80%), hand off:
\`\`\`bash
gt handoff -s "Barkeep patrol handoff" -m "<pending items summary>"
\`\`\`
```

### 4. Start the barkeep

```bash
gt crew start barkeep
```

The barkeep session runs in tmux, executing the patrol formula in a loop.

### 5. Monitor

```bash
gt crew status barkeep          # Check if session is alive
gt mail inbox --to rally_tavern/barkeep  # Check pending nominations
```

## The Patrol Formula

The `mol-barkeep-patrol` formula defines a 5-step cycle:

1. **heartbeat** — Signal liveness to the daemon
2. **inbox-check** — Process all RALLY_NOMINATION and RALLY_REPORT messages
3. **knowledge-hygiene** — Count entries, flag stale knowledge (every 10th cycle)
4. **context-check** — If context >80%, write handoff and exit
5. **loop-or-exit** — Report patrol results, sleep (5min if idle, 2min if active), loop

The formula lives in the gastown repo at:
```
internal/formula/formulas/mol-barkeep-patrol.formula.toml
```

It ships with gastown — no need to copy or maintain it separately.

## Operational Notes

**Session death:** Crew members have no Witness monitoring. If the barkeep
session dies, nominations queue up in the inbox. They'll be processed when you
restart. Nothing is lost — mail is durable.

**Context cycling:** Long-running sessions accumulate context. The patrol formula
handles this automatically (step 4 checks context and hands off). After handoff,
restart with `gt crew start barkeep`.

**Coexistence:** You can run crew mode AND keep the plugin as a fallback. Set
the plugin gate to `type = "cooldown"` with `duration = "1h"`. If the crew
session is processing nominations, the plugin pass will find an empty inbox and
skip. If the crew session dies, the plugin picks up after 1 hour.

## Scaling

For high-volume deployments (many rigs, frequent nominations), consider:

- **Shorter sleep intervals**: Edit the formula or override via `gt formula run mol-barkeep-patrol --var sleep_idle=120`
- **Multiple curators**: Add a second crew member (`gt crew add historian rally_tavern`) with a CLAUDE.md that focuses on knowledge hygiene while the barkeep handles nominations
- **Hybrid mode**: Crew for curation + plugin as safety net (see coexistence above)
