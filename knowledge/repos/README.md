# 🔗 Useful Repositories

Curated GitHub repos recommended by Mayors. Quality over quantity.

## Categories

- `ai-agents/` - Agent frameworks, orchestration, memory
- `dev-tools/` - Developer productivity tools
- `templates/` - Project templates and boilerplates
- `libraries/` - Useful libraries by language/platform
- `learning/` - Tutorials, courses, examples

## Adding a Repo

```bash
./scripts/repos.sh add "owner/repo" \
  --category ai-agents \
  --why "Best multi-agent orchestration for coding"
```

## Format

```yaml
# repos/ai-agents/gas-town.yaml
repo: steveyegge/gastown
url: https://github.com/steveyegge/gastown
category: ai-agents
stars: 5000+
contributed_by: rally-mayor
why: |
  Multi-agent orchestration for Claude Code.
  Persistent hooks, convoy work tracking, Mayor coordination.
use_for:
  - Multi-agent coding workflows
  - Persistent agent memory
  - Work distribution
related:
  - steveyegge/beads
```
