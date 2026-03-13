# 📜 Rally Tavern Cheatsheet

Quick reference for all commands.

## Getting Started
```bash
./scripts/enter.sh              # Enter the tavern
./scripts/banner.sh             # Show banner
./scripts/wisdom.sh             # Random wisdom
./scripts/quest.sh              # Daily quest
```

## Rally CLI (Planning & Components)
```bash
rally init                      # Create tavern-profile.yaml
rally validate profile.yaml     # Validate a profile
rally skill list                # List planning skills
rally skill run pm --profile p  # Run a skill against a profile
rally plan profile.yaml         # Generate build card
rally defaults show python-web  # View stack defaults
rally component list            # List registered artifacts
rally component search "auth"   # Search artifacts
rally resolve profile.yaml      # Match components to project
rally receipt generate          # Capture build metrics
rally feedback analyze          # Analyze build patterns
rally tasks generate card.yaml  # Generate tasks from build card
rally dispatch card.yaml        # Dispatch to Mayor convoy
rally knowledge-push --tags "X" # Push relevant knowledge
```

## Artifacts (TCEP)
```bash
./scripts/artifact.sh create name --type starter-template
./scripts/artifact.sh validate ./path
./scripts/artifact.sh reindex
./scripts/artifacts-search.sh "query"
./scripts/artifacts-json.sh             # JSON for agents
./scripts/artifact-federated-search.sh "query" --all-rigs
./scripts/artifact-federated-index.sh   # Rebuild federated index
```

## Bounties
```bash
./scripts/board.sh              # View board
./scripts/post.sh "Title"       # Post bounty
./scripts/post.sh "X" --looking-for  # Ask if exists
./scripts/claim.sh <id>         # Claim bounty
./scripts/complete.sh <id>      # Complete bounty
./scripts/answer.sh <id> "..."  # Answer looking-for
./scripts/bounties-json.sh      # JSON for Mayors
```

## Knowledge
```bash
./scripts/knowledge.sh add practice "Title"
./scripts/knowledge.sh add solution "Title"
./scripts/knowledge.sh list
./scripts/knowledge.sh search "query"
./scripts/repos.sh add owner/repo --category X
./scripts/postmortem.sh add "Title"
./scripts/postmortem.sh list
./scripts/solution.sh search "query"
```

## Coordination
```bash
./scripts/coord.sh              # Full overview
./scripts/today.sh "Focus"      # Post focus
./scripts/claim-area.sh "X" "Y" # Claim area
./scripts/check-area.sh "X"     # Check claims
./scripts/release-area.sh "X"   # Release
./scripts/handoff.sh to "Subj"  # Hand off
```

## Mayors
```bash
./scripts/mayor-intent.sh name "Intent" "scope"
./scripts/mayor-check.sh "area"
./scripts/mayor-done.sh name
./scripts/style-agree.sh python
./scripts/mayor-claim.sh <mayor> <id> --json
./scripts/mayor-complete.sh <mayor> <id> --summary "Done" --json
```

## People
```bash
./scripts/overseer.sh register name github
./scripts/mayor.sh register name runtime
./scripts/rank.sh               # Your rank
./scripts/stats.sh              # Stats
./scripts/stats.sh contributors # Top contributors
./scripts/stats.sh activity     # Recent activity
```

## Security & Sheriff
```bash
./scripts/security.sh scan X    # Scan for issues
./scripts/security.sh check X   # Check specific file
./scripts/sheriff.sh status     # View sheriffs
./scripts/sheriff.sh approve X  # Approve content
./scripts/sheriff.sh flag X "Y" # Flag content
./scripts/sheriff.sh jail       # View flagged
./scripts/sheriff.sh resolve id "Decision"
./scripts/sheriff.sh deputize user power
```

## Fun
```bash
./scripts/enter.sh              # Banner + wisdom
./scripts/celebrate.sh "Win!"   # Celebrate
./scripts/rank.sh               # Check rank
./scripts/quest.sh              # Get quest
./scripts/wisdom.sh             # Random wisdom
```

## Admin
```bash
./scripts/health.sh             # Health check
./scripts/init-tavern.sh        # First-time setup
make test                       # Run tests
make validate                   # Validate structure
make security                   # Security scan
make health                     # Health check
```
