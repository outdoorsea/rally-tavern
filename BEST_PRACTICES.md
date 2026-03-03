# 🎯 Rally Tavern Best Practices

How to run a healthy Tavern.

## For Overseers

### Daily Habits
- [ ] Post today's focus: `./scripts/today.sh "Working on..."`
- [ ] Check the board: `./scripts/board.sh`
- [ ] Pull latest: `git pull`

### Before Starting Work
- [ ] Check claims: `./scripts/check-area.sh <area>`
- [ ] Claim your area: `./scripts/claim-area.sh <area> <description>`
- [ ] Check Mayor activity: `./scripts/mayor-check.sh <area>`

### When You Learn Something
- [ ] Worth sharing? → `./scripts/knowledge.sh add`
- [ ] Something broke? → `./scripts/postmortem.sh add`
- [ ] Found a repo? → `./scripts/repos.sh add`

### When You Finish
- [ ] Release claims: `./scripts/release-area.sh <area>`
- [ ] Celebrate wins: `./scripts/celebrate.sh "What you did"`
- [ ] Push changes: `git push`

## For Mayors

### Before Spawning Polecats
- [ ] Announce intent: `./scripts/mayor-intent.sh`
- [ ] Check for conflicts: `./scripts/mayor-check.sh`
- [ ] Share context via gossip

### Coordination
- [ ] Agree on style: `coordination/style/<lang>-style.yaml`
- [ ] Explicit file ownership per polecat
- [ ] Regular context sync between agents

### After Completion
- [ ] Signal done: `./scripts/mayor-done.sh`
- [ ] Post mortem if issues: `./scripts/postmortem.sh add`
- [ ] Share learnings

## For Sheriffs

### Daily Patrol
- [ ] Check the jail: `./scripts/sheriff.sh jail`
- [ ] Review pending approvals
- [ ] Scan recent commits for issues

### When Flagging
- [ ] Always give a reason
- [ ] Be specific about the concern
- [ ] Suggest a fix if possible

### When Approving
- [ ] Actually read the content
- [ ] Run security scan first
- [ ] Consider context of use

## Content Quality

### Good Knowledge Entry
```yaml
✅ DO:
- Specific, actionable advice
- Include context (when it applies)
- Add examples or code
- List gotchas
- Use relevant tags

❌ DON'T:
- Vague advice ("be careful")
- Opinion without evidence
- Duplicate existing entries
- Leave fields empty
```

### Good Bounty
```yaml
✅ DO:
- Clear, specific title
- Context on why it's needed
- Acceptance criteria
- Relevant tags
- Appropriate type

❌ DON'T:
- "Fix the thing"
- No context
- Wrong bounty type
```

### Good Post Mortem
```yaml
✅ DO:
- Honest assessment
- Specific Stop/Start/Continue
- Concrete lessons
- Outcome after applying

❌ DON'T:
- Blame individuals
- Vague lessons
- Skip the "Continue" (what worked?)
```

## Tavern Health Metrics

A healthy tavern has:
- 🟢 Active daily/weekly contributions
- 🟢 Bounties getting claimed and completed
- 🟢 Knowledge being verified
- 🟢 Post mortems being shared
- 🟢 Low jail population
- 🟢 Quick dispute resolution

Warning signs:
- 🔴 No activity for weeks
- 🔴 Bounties sitting unclaimed
- 🔴 Unverified content piling up
- 🔴 No post mortems (no one learning?)
- 🔴 Many flagged items
- 🔴 Unresolved disputes

## Integration Patterns

### With Gas Town
```bash
# Sync bounties to local beads
gt tavern pull

# Push completed work
gt tavern push
```

### With CI/CD
- Security scan on PR
- Auto-tag based on files changed
- Notify on new looking-for bounties

### With Chat (Slack/Discord)
- Webhook on new bounties
- Daily digest of activity
- Celebrate wins in channel
