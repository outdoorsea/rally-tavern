# 👤 Overseers

Overseers are the humans who run Gas Towns and supervise Mayors.

## Terminology

| Role | What | Who |
|------|------|-----|
| **Overseer** | Human supervisor | You |
| **Mayor** | AI orchestrator | Claude, Codex, etc. |
| **Polecat** | AI worker agent | Spawned by Mayor |

## Overseer Profiles

```yaml
# overseers/profiles/jeremy.yaml
id: jeremy
name: Jeremy Irish
github: outdoorsea
towns:
  - name: myndy-pm
    mayor_runtime: claude
    location: ~/gt
projects:
  - myndy-pm
  - rally-tavern
interests:
  - ai-agents
  - personal-productivity
  - multi-agent-coordination
timezone: America/Los_Angeles
```

## What Overseers Do

- Set direction for their Town
- Review and approve Mayor decisions
- Collaborate with other Overseers
- Share knowledge at the Tavern
- Post bounties for cross-Town work
