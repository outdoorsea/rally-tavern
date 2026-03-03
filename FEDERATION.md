# 🌐 Federation

Multiple Taverns can share content.

## Use Cases

- **Company Tavern** - Private, internal knowledge
- **Public Tavern** - Open source community
- **Team Tavern** - Specific project/team

## Sharing Between Taverns

### Upstream (Pull from another Tavern)

```bash
# Add upstream tavern
git remote add upstream-tavern https://github.com/other/tavern.git

# Pull their knowledge
git fetch upstream-tavern
git checkout upstream-tavern/main -- knowledge/practices/useful-thing.yaml
git commit -m "Import useful-thing from upstream"
```

### Downstream (Share to main Tavern)

```bash
# Fork the main tavern
# Add your knowledge
# PR back to main
```

## Trust Across Taverns

Content from other Taverns should be reviewed before importing.
Use the security scanner:

```bash
./scripts/security.sh scan imported-content/
```

## Future: Automated Federation

Eventually, Taverns could auto-sync selected content based on tags/topics.
This is a future enhancement.
