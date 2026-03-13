# Rally Tavern Component Registry

Searchable index of reusable components for Gas Town projects.

## Quick Reference

```bash
# List all components
rally component list

# List by capability
rally component list --capability user-authentication

# Search by text
rally component search "fastapi auth"

# Resolve components for a project
rally resolve project-profile.yaml

# Show component details
rally component show io.github.rally-tavern/python-fastapi-sso-starter

# Validate a component
rally component validate ./artifacts/io.github.rally-tavern/my-component

# Create a new component
rally component new my-component --type starter-template

# Register an external component
rally component add ./path/to/component
```

## Registered Components

### Starters

| Component | Capabilities | Platform | Trust |
|-----------|-------------|----------|-------|
| `python-fastapi-sso-starter` | user-authentication (sso-oauth2), database-migrations (alembic), api-server (fastapi) | python-web | experimental |
| `ios-swift-auth-settings-starter` | user-authentication (email-password), settings-preferences (userdefaults), ios-app-scaffold (swiftui) | ios-swiftui | experimental |

### Modules

| Component | Capabilities | Platform | Trust |
|-----------|-------------|----------|-------|
| `python-pytest-harness` | test-harness (pytest), test-fixtures (factory-pattern), coverage-reporting (pytest-cov) | python-web, python-api, python-cli | experimental |

### Components

| Component | Capabilities | Platform | Trust |
|-----------|-------------|----------|-------|
| `react-css-showcase` | design-system-browser (css-custom-properties), showcase-page (react-component), token-adoption-analysis (stylesheet-scanner) | web (react, typescript) | experimental |

### Examples

| Component | Description | Trust |
|-----------|-------------|-------|
| `hello-world` | Minimal example artifact for testing | experimental |

## Component Resolution

The resolution engine matches project needs to components using multi-factor scoring:

1. **Platform compatibility** (hard filter) — component must support project platform
2. **Language compatibility** (hard filter) — component must support project language
3. **Capability match** (15 pts each) — capabilities derived from project facets
4. **Framework match** (10 pts) — bonus for matching framework
5. **Trust tier** (0-15 pts) — verified > community > experimental
6. **Version stability** (0-10 pts) — stable releases score higher
7. **Reuse count** (0-10 pts) — more usage = more trusted
8. **Token savings** (0-10 pts) — higher savings = better value

Unmatched capabilities are flagged as "build candidates" — needs the project has
that no existing component satisfies.

## Capability Vocabulary

Components declare what they provide via the `provides` field:

```yaml
provides:
  - capability: user-authentication
    style: sso-oauth2
  - capability: api-server
    style: fastapi
```

Common capabilities:
- `user-authentication` — Login, registration, session management
- `api-server` — HTTP API framework setup
- `database-migrations` — Schema migration tooling
- `test-harness` — Test framework setup with fixtures
- `test-fixtures` — Factory/fixture patterns for test data
- `coverage-reporting` — Code coverage measurement
- `ui-scaffold` — Frontend/UI project structure
- `ios-app-scaffold` — iOS application skeleton
- `settings-preferences` — User settings/preferences storage

## Trust Tiers

| Tier | Requirements | Icon |
|------|-------------|------|
| `experimental` | Created, no review needed | 🔴 |
| `community` | Used in 2+ projects, passing tests, accurate metadata | 🟡 |
| `verified` | Community + human overseer review, measured token savings | 🟢 |

## Directory Structure

```
artifacts/
├── .index.json                    # Compiled registry (auto-generated)
├── federated-index.json           # Cross-rig federated index
├── <namespace>/
│   └── <component-name>/
│       ├── artifact.yaml          # Component manifest
│       ├── templates/             # Template files for instantiation
│       ├── acceptance/            # Acceptance tests
│       │   └── test.sh
│       ├── skills/                # Associated skills (optional)
│       └── .usage.jsonl           # Usage telemetry (auto-generated)
```

## Contributing

See [CONTRIBUTING-ARTIFACTS.md](CONTRIBUTING-ARTIFACTS.md) for full guidelines.
