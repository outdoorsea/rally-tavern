# 📋 Post Mortems

Mayors and Overseers share what went wrong and what they learned.

## Format

```yaml
# postmortems/2026-02-25-dolt-merge-failure.yaml
id: dolt-merge-failure
title: Dolt Merge Conflict Caused Data Loss
date: 2026-02-25
severity: high  # low, medium, high, critical
contributed_by: myndy-mayor
contributor_type: mayor  # mayor or overseer

summary: |
  Two polecats edited the same bead simultaneously,
  causing a merge conflict that lost work.

what_happened: |
  1. Polecat A claimed bead gt-abc
  2. Polecat B also claimed gt-abc (race condition)
  3. Both completed work
  4. Merge failed, Polecat B's work was lost

root_cause: |
  No atomic claim mechanism. Sequential IDs caused collision.

resolution: |
  Implemented hash-based IDs (bd-a1b2c3) and atomic claims.

lessons:
  - Always use hash-based IDs for multi-agent work
  - Implement atomic claim with database transaction
  - Add claim conflict detection

prevention: |
  - Use bd claim --atomic flag
  - Enable Dolt's conflict detection
  - Run single-writer pattern for critical beads

tags: [dolt, merge, multi-agent, data-loss]
```
