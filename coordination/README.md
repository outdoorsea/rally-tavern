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
claimed_by: alice
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
# ⚠️ Area claimed by alice: "Refactoring JWT handling"
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
# 👤 alice: Working on auth refactor, staying out of API routes
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
  👤 alice: auth module (since 2h ago)
     Files: src/auth/*
  👤 sarah: api docs (since 30m ago)
     Files: docs/api/*

TODAY'S FOCUS:
  👤 alice: Refactoring JWT handling
  👤 sarah: Updating API documentation

RECENT HANDOFFS:
  alice → sarah: Database migrations (yesterday)
```

---

# 🎩 Multi-Mayor Coordination

When multiple AI Mayors work on the same project.

## The Problem

Two Mayors, same codebase:
- Both spawn polecats for same files → conflicts
- Different coding styles → inconsistent code
- No shared context → duplicate decisions

## Mayor Protocols

### 1. Announce Intent

Before starting work, Mayor announces:

```yaml
# coordination/mayors/example-mayor-intent.yaml
mayor: example-mayor
runtime: claude
intent: Refactoring auth module
scope:
  files: [src/auth/*]
  exclude: [src/auth/legacy/*]
timestamp: 2026-02-25T12:00:00Z
expected_duration: 2h
```

### 2. Check for Conflicts

```bash
./scripts/mayor-check.sh "src/auth/"
# ⚠️ example-mayor is working on src/auth/*
```

### 3. Coordinate via Gossip

Mayors share context through gossip:

```yaml
# gossip/auth-refactor-approach.yaml
topic: auth-refactor
intel: |
  Using OAuth2PasswordBearer pattern.
  JWT stored in httponly cookies, not localStorage.
  Refresh tokens in separate table.
posted_by: example-mayor
```

### 4. Signal Completion

```bash
./scripts/mayor-done.sh "example-mayor" "auth module"
```

## Mayor Handoff Protocol

When one Mayor needs to hand off to another:

```yaml
# coordination/handoffs/mayor-handoff-xyz.yaml
from_mayor: example-mayor
to_mayor: codex-mayor
reason: Need test coverage, Claude can't run tests
context: |
  Auth refactor complete in src/auth/
  Need pytest tests for jwt.py and refresh.py
  Use existing test fixtures in tests/conftest.py
beads: [gt-abc, gt-def]
files_touched: [src/auth/jwt.py, src/auth/refresh.py]
```

## Style Sync

Mayors should agree on style before parallel work:

```yaml
# coordination/style/python-style.yaml
language: python
agreed_by: [example-mayor, codex-mayor]
conventions:
  - Use type hints everywhere
  - Pydantic for all schemas
  - async def for IO operations
  - 88 char line length (black default)
  - Google-style docstrings
```
