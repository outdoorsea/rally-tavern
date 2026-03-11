# Contributing to Rally Tavern

## Quick Contributions

The fastest way to contribute is to write YAML directly — copy a file from `knowledge/` as a template and fill it in:

```bash
# Copy a template
cp knowledge/solutions/github-actions-gitleaks-secrets-scan.yaml \
   knowledge/solutions/my-new-solution.yaml

# Edit it, then push
git add knowledge/
git commit -m "Add: [summary]"
git push
```

Or use the scripts:

| Want to... | Script | Direct YAML path |
|------------|--------|-----------------|
| Share a best practice | `./scripts/knowledge.sh add practice "Title"` | `knowledge/practices/` |
| Share a copy-paste solution | `./scripts/knowledge.sh add solution "Title"` | `knowledge/solutions/` |
| Recommend a repo | `./scripts/repos.sh add owner/repo --category X` | `knowledge/repos/` |
| Post a lesson learned | `./scripts/postmortem.sh add "Title"` | `knowledge/postmortems/` |
| Ask if something exists | `./scripts/post.sh "Looking for X" --looking-for` | bounties/ board |
| Answer a question | `./scripts/answer.sh bounty-id "Answer"` | bounties/ board |

### Linking to Source

Always include a `github_source` field pointing to the public PR or commit where the knowledge was produced. This lets other builders see the full context and verify the artifact in a real codebase.

```yaml
github_source: https://github.com/your-org/your-repo/pull/42
```

## Quality Guidelines

### For Knowledge

✅ **Good knowledge:**
- Specific and actionable
- Includes context (when/where it applies)
- Has examples or code snippets
- Lists gotchas/edge cases

❌ **Avoid:**
- Vague advice ("be careful with X")
- Opinion without evidence
- Outdated information
- Duplicates of existing knowledge

### For Bounties

✅ **Good bounties:**
- Clear title describing the need
- Context on why it's needed
- Acceptance criteria
- Relevant tags

### For Post Mortems

✅ **Good post mortems:**
- Honest about what went wrong
- Specific Stop/Start/Continue items
- Outcome after applying lessons
- Tags for discoverability

## Review Process

1. **Self-review** - Does it meet quality guidelines?
2. **Push** - `git push` (or PR for high-risk content)
3. **Community verification** - Others can verify
4. **Maintainer approval** - For configs/sensitive content

## Deprecating Content

Knowledge gets outdated. Mark it:

```yaml
deprecated: true
deprecated_at: 2026-03-01
deprecated_reason: Superseded by new-approach.yaml
superseded_by: knowledge/practices/new-approach.yaml
```

## Disagreements

If you disagree with existing knowledge:
1. Don't edit/delete the original
2. Add your alternative with different context
3. Let usage determine which is better
4. Both can coexist if they apply to different situations
