# 🤝 Multi-Overseer Coordination

Prevent stepping on toes when multiple 👤 Overseers work on the same project.

## The Problem

Two overseers, same codebase:
- Both edit the same file → merge conflict
- Both implement same feature → wasted work
- Different approaches → inconsistent code

## The Solution: Claim Before You Work

### 1. Claim Areas

Before starting work, claim the area:

```bash
./scripts/claim-area.sh "auth module" "Refactoring JWT handling"
```

This creates:
```yaml
# coordination/claims/auth-module.yaml
area: auth module
claimed_by: jeremy
description: Refactoring JWT handling
claimed_at: 2026-02-25T12:00:00Z
status: active
files:
  - src/auth/*
  - tests/auth/*
```

### 2. Check Before Working

```bash
./scripts/check-area.sh "src/auth/jwt.py"
# ⚠️ Area claimed by jeremy: "Refactoring JWT handling"
```

### 3. Release When Done

```bash
./scripts/release-area.sh "auth module"
```

## Daily Sync

Post what you're working on today:

```bash
./scripts/today.sh "Working on auth refactor, staying out of API routes"
```

Others can see:
```bash
./scripts/today.sh --list
# 👤 jeremy: Working on auth refactor, staying out of API routes
# 👤 sarah: Updating API documentation, won't touch code
```

## Handoffs

Formally hand off work to another overseer:

```bash
./scripts/handoff.sh "sarah" "Auth refactor" \
  --context "JWT signing done, refresh tokens TODO" \
  --files "src/auth/jwt.py,src/auth/refresh.py"
```

## Coordination Board

See who's working on what:

```bash
./scripts/coord.sh
```

Output:
```
🤝 Project Coordination

ACTIVE CLAIMS:
  👤 jeremy: auth module (since 2h ago)
     Files: src/auth/*
  👤 sarah: api docs (since 30m ago)
     Files: docs/api/*

TODAY'S FOCUS:
  👤 jeremy: Refactoring JWT handling
  👤 sarah: Updating API documentation

RECENT HANDOFFS:
  jeremy → sarah: Database migrations (yesterday)
```
