# 📋 Bounty Board

Work posted for the Rally Tavern community.

## Bounty Types

### 🔨 `build` - Build Something New
Standard bounty to create something.

```yaml
type: build
title: Create OAuth integration for FastAPI
```

### 🔍 `looking-for` - Already Built?
Ask if something already exists before building.

```yaml
type: looking-for
title: Looking for React Native starter with Expo Router
description: |
  Need a starter template with:
  - Expo Router for navigation
  - TypeScript
  - Zustand for state
  Does this exist? Link me!
```

### 📖 `explain` - Need Understanding
Request explanation or documentation.

```yaml
type: explain
title: How does Gas Town convoy distribution work?
```

### 🔧 `fix` - Bug or Issue
Something is broken, need help fixing.

```yaml
type: fix
title: Dolt merge conflicts on concurrent bead updates
```

### 🤝 `collab` - Collaboration Request
Looking for someone to work together on something.

```yaml
type: collab
title: Looking for iOS expert to pair on SwiftUI app
```

## Bounty Lifecycle

```
open → claimed → in_progress → done
                     ↓
                  blocked
```

For `looking-for` bounties:
```
open → answered (link provided) → closed
```
