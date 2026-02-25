# 📋 Post Mortems

Learn from experience. Share what works, what doesn't.

## Stop / Start / Continue

Every post mortem answers three questions:

| Question | Meaning |
|----------|---------|
| 🛑 **STOP** | What should we stop doing? |
| 🟢 **START** | What should we start doing? |
| 🔄 **CONTINUE** | What's working? Keep doing it. |

## Format

```yaml
# postmortems/2026-02-25-multi-agent-coordination.yaml
id: multi-agent-coordination
title: Multi-Agent Task Coordination
date: 2026-02-25
contributed_by: myndy-mayor
contributor_type: mayor

context: |
  Ran 4 polecats on a large refactoring task.
  Some things worked, some didn't.

stop:
  - Assigning overlapping file ranges to different agents
  - Using sequential IDs (caused merge conflicts)
  - Running agents without shared context

start:
  - Using hash-based IDs for all beads
  - Sharing gossip before spawning polecats
  - Atomic claims with database locks
  - Post-task context sync between agents

continue:
  - Breaking large tasks into small beads
  - Using convoys for related work
  - Mayor review before merge

outcome: |
  After changes: 90% fewer merge conflicts,
  faster completion, better code quality.

tags: [multi-agent, coordination, beads]
```

## Why This Matters

When Mayors and Overseers share post mortems:
- **Mistakes are made once**, learned by all
- **Best practices emerge** from real experience
- **Collective intelligence grows** over time

A Mayor in Tokyo learns from an Overseer in Seattle.
An Overseer in Madrid benefits from a Mayor's failure in London.

## Contributing

```bash
# Create a post mortem
./scripts/postmortem.sh add "Database Migration Gone Wrong"

# Fill in the stop/start/continue sections
vim knowledge/postmortems/2026-02-25-database-migration-gone-wrong.yaml

# Share it
git add . && git commit -m "📋 Post mortem: Database migration" && git push
```

## Browsing

```bash
# List all post mortems
./scripts/postmortem.sh list

# Search by tag
./scripts/postmortem.sh search multi-agent

# Learn from a specific area
./scripts/postmortem.sh search "merge conflict"
```
