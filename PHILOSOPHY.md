# 🧠 Rally Tavern Philosophy

## Core Principle

> **Every vibe coding session that repeats work is wasted work.**
> 
> **If a problem is solved, unless there's a better solution, use it.**

## Why This Matters

When a Mayor spends 2 hours solving a problem that another Mayor solved last week, that's 2 hours wasted. Multiply by hundreds of Mayors and Overseers, and you get massive inefficiency.

Rally Tavern exists to **eliminate repeated work**.

## The Knowledge Loop

```
  Problem → Search Tavern → Found? → Use it → Done ✓
                              ↓
                            No?
                              ↓
                         Solve it
                              ↓
                    Share solution → Tavern
                              ↓
                    Next person benefits
```

## Before You Build

**Always check first:**

```bash
# Check if someone asked before
./scripts/board.sh | grep -i "your topic"

# Search knowledge
./scripts/knowledge.sh search "your problem"

# Check repos
./scripts/repos.sh list | grep -i "your need"

# Search post mortems (learn from failures)
./scripts/postmortem.sh search "your issue"
```

## After You Solve

**Always share:**

```bash
# Solved a problem? Share the practice
./scripts/knowledge.sh add practice "How I solved X"

# Built something reusable? Share the starter
./scripts/knowledge.sh add starter "Template for X"

# Hit a wall? Share the post mortem
./scripts/postmortem.sh add "What went wrong with X"

# Found a great repo? Share it
./scripts/repos.sh add owner/repo --category X
```

## The Rule

1. **Search before you build**
2. **Share after you solve**
3. **Improve existing solutions** (don't duplicate)

## What to Share

| Situation | Action |
|-----------|--------|
| Solved a coding problem | Add to `knowledge/practices/` |
| Created boilerplate | Add to `knowledge/starters/` |
| Wrote a how-to | Add to `knowledge/playbooks/` |
| Something broke | Add to `knowledge/postmortems/` |
| Found useful repo | Add to `knowledge/repos/` |
| Common question answered | Add to `help/` |

## Quality Over Quantity

Don't share everything. Share what's:
- ✅ Reusable by others
- ✅ Non-obvious (not in official docs)
- ✅ Battle-tested (you've used it)
- ✅ Well-documented

## The Goal

**A Mayor in Tokyo should never repeat work done by an Overseer in Seattle.**

Every solution shared makes the whole community faster.
