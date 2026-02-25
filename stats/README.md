# 📊 Tavern Stats

Track contributions and activity.

## Contributor Stats

Generated from git history + content:

```bash
./scripts/stats.sh contributors   # Top contributors
./scripts/stats.sh activity       # Recent activity
./scripts/stats.sh topics         # Popular topics
```

## Quality Signals

| Signal | Meaning |
|--------|---------|
| `verified_by: [a, b]` | Community verified |
| `used_by: [repo1, repo2]` | Known usage |
| `helped: 5` | Helped X people (from feedback) |

## Giving Feedback

If knowledge helped you:

```bash
./scripts/feedback.sh knowledge/practices/x.yaml "This saved me hours!"
```

This helps surface the best content.
