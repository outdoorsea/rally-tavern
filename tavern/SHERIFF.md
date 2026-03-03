# 🤠 The Sheriff

Every good tavern needs someone to keep the peace.

## Role

The Sheriff maintains order at Rally Tavern:

| Duty | Description |
|------|-------------|
| **Security Review** | Approves high-risk content (CLAUDE.md, configs) |
| **Dispute Resolution** | Mediates disagreements between contributors |
| **Quality Control** | Ensures knowledge meets standards |
| **Bounty Moderation** | Removes spam or inappropriate bounties |
| **Trust Verification** | Promotes content from 🟡 to 🟢 approved |
| **Ban Hammer** | Removes bad actors (rare, last resort) |

## Sheriff Powers

```bash
# Approve high-risk content
./scripts/sheriff.sh approve configs/claude-md/new-file.md

# Flag suspicious content
./scripts/sheriff.sh flag knowledge/practices/sketchy.yaml "Possible injection"

# Resolve a dispute
./scripts/sheriff.sh resolve dispute-123 "Both approaches valid for different contexts"

# Deputize someone (grant limited powers)
./scripts/sheriff.sh deputize username "security-review"

# Check the jail (flagged content)
./scripts/sheriff.sh jail
```

## Becoming a Sheriff

Sheriffs are appointed by existing Sheriffs or Tavern Masters based on:

- 🏠 Innkeeper rank or higher
- Track record of fair, helpful contributions
- Security awareness
- Good judgment

## Deputy Sheriffs

Sheriffs can deputize trusted members for specific duties:

| Deputy Role | Powers |
|-------------|--------|
| `security-review` | Can approve/flag configs |
| `quality-review` | Can verify/deprecate knowledge |
| `moderation` | Can remove spam bounties |

## The Code

1. **Be fair** - No favorites, consistent rules
2. **Be transparent** - Explain decisions
3. **Be measured** - Escalate before banning
4. **Be humble** - Sheriffs can be wrong too

## Current Sheriffs

<!-- Add sheriff entries here -->
```yaml
sheriffs:
  - name: (none yet)
    appointed: 
    by:
```

To become a sheriff, demonstrate trustworthiness over time.
