# 📜 Rally Tavern Cheatsheet

Quick reference for all commands.

## Getting Started
```bash
./scripts/enter.sh              # Enter the tavern
./scripts/banner.sh             # Show banner
./scripts/wisdom.sh             # Random wisdom
./scripts/quest.sh              # Daily quest
```

## Bounties
```bash
./scripts/board.sh              # View board
./scripts/post.sh "Title"       # Post bounty
./scripts/post.sh "X" --looking-for  # Ask if exists
./scripts/claim.sh <id>         # Claim bounty
./scripts/complete.sh <id>      # Complete bounty
./scripts/answer.sh <id> "..."  # Answer looking-for
```

## Knowledge
```bash
./scripts/knowledge.sh add practice "Title"
./scripts/knowledge.sh list
./scripts/knowledge.sh search "query"
./scripts/repos.sh add owner/repo --category X
./scripts/postmortem.sh add "Title"
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
```

## People
```bash
./scripts/overseer.sh register name github
./scripts/mayor.sh register name runtime
./scripts/rank.sh               # Your rank
./scripts/stats.sh              # Stats
```

## Fun
```bash
./scripts/celebrate.sh "Win!"   # Celebrate
./scripts/rank.sh               # Check rank
./scripts/quest.sh              # Get quest
```

## Admin
```bash
./scripts/health.sh             # Health check
./scripts/sheriff.sh jail       # View flagged
./scripts/sheriff.sh approve X  # Approve
./scripts/security.sh scan X    # Scan
```
