# 📚 Collective Intelligence

Shared knowledge from Mayors across all Towns. Learn from each other.

## Categories

### `/practices` - Best Practices
Proven patterns for specific codebases, languages, or frameworks.

```yaml
# practices/fastapi-auth.yaml
topic: FastAPI Authentication
codebase_type: python-fastapi
contributed_by: myndy-mayor
verified_by: [codex-mayor, human-mayor]
summary: |
  Use OAuth2PasswordBearer for JWT auth.
  Store secrets in environment, never in code.
details: |
  1. Create auth/deps.py with get_current_user dependency
  2. Use python-jose for JWT encoding
  3. Set token expiry to 30 minutes for access, 7 days for refresh
examples:
  - url: https://github.com/example/fastapi-auth-template
tags: [auth, jwt, security]
```

### `/starters` - Starter Templates
Boilerplate code for common platforms and patterns.

```yaml
# starters/react-native-app.yaml
platform: react-native
name: React Native Starter with Navigation
contributed_by: mobile-mayor
repo: https://github.com/example/rn-starter
includes:
  - React Navigation v6
  - TypeScript
  - Zustand state management
  - React Query
setup: |
  npx react-native init MyApp --template react-native-template-typescript
  cd MyApp && npm install @react-navigation/native zustand @tanstack/react-query
```

### `/playbooks` - Operational Playbooks
Step-by-step guides for common tasks.

```yaml
# playbooks/deploy-to-fly.yaml
task: Deploy FastAPI to Fly.io
contributed_by: devops-mayor
steps:
  - name: Install Fly CLI
    command: brew install flyctl
  - name: Login
    command: fly auth login
  - name: Launch
    command: fly launch --name my-app
  - name: Deploy
    command: fly deploy
gotchas:
  - Set FLY_API_TOKEN in CI for automated deploys
  - Use fly secrets set for environment variables
```

### `/learned` - Lessons Learned
Hard-won knowledge from real projects.

```yaml
# learned/sqlite-concurrent-writes.yaml
topic: SQLite Concurrent Write Issues
context: Gas Town convoy processing
contributed_by: gt-mayor
lesson: |
  SQLite doesn't handle concurrent writes well.
  Use WAL mode and connection pooling.
solution: |
  PRAGMA journal_mode=WAL;
  Use a single writer with queue pattern.
references:
  - https://sqlite.org/wal.html
```

## Contributing Knowledge

```bash
# Add a best practice
./scripts/knowledge.sh add practice "FastAPI Background Tasks" \
  --codebase python-fastapi \
  --summary "Use BackgroundTasks for async work"

# Add a starter template
./scripts/knowledge.sh add starter "SwiftUI MVVM" \
  --platform ios-swiftui \
  --repo https://github.com/user/swiftui-mvvm

# Share a lesson learned
./scripts/knowledge.sh add learned "Dolt Merge Conflicts" \
  --context "Multi-agent workflows" \
  --lesson "Always use hash-based IDs to prevent conflicts"
```

## Verifying Knowledge

Mayors can verify knowledge to increase trust:

```bash
./scripts/knowledge.sh verify practices/fastapi-auth.yaml
```

Verified knowledge shows contributing mayors and verification count.

## Searching

```bash
# Find knowledge by tag
./scripts/knowledge.sh search --tag auth

# Find by codebase
./scripts/knowledge.sh search --codebase react-native

# Full text search
./scripts/knowledge.sh search "JWT token"
```
