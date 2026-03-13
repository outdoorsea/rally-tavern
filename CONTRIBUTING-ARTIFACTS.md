# Contributing Artifacts to Rally Tavern

Guidelines for creating, publishing, and maintaining TCEP artifacts across the
Gas Town federation.

---

## Quick Start

```bash
# Create a new artifact in your rig
./scripts/artifact.sh create my-artifact --type starter-template --namespace io.github.outdoorsea/vitalitek

# Validate it
./scripts/artifact.sh validate artifacts/io.github.outdoorsea/vitalitek/my-artifact

# Rebuild your local index
./scripts/artifact.sh reindex
```

---

## Naming Conventions

### Artifact Names

- **Lowercase kebab-case**: `python-fastapi-sso-starter`, not `PythonFastAPISSOStarter`
- **Descriptive, stack-first**: lead with language/framework, end with purpose
- **Suffix by type**: `-starter` for starters, `-module` for modules, `-skill` for skills

Good: `ios-swift-auth-settings-starter`, `python-flask-rbac-module`
Bad: `auth-thing`, `my-template`, `v2-api`

### Namespaces

Each rig owns its namespace:

| Rig | Namespace |
|-----|-----------|
| rally_tavern | `io.github.rally-tavern` |
| vitalitek | `io.github.outdoorsea/vitalitek` |
| theoutlived | `io.github.outdoorsea/theoutlived` |
| meety_me | `io.github.outdoorsea/meety_me` |

Artifacts are always created under their rig's namespace. Cross-rig discovery
happens through federated search, not namespace sharing.

---

## Required Manifest Fields

Every `artifact.yaml` must include:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Kebab-case artifact name |
| `namespace` | Yes | Rig namespace |
| `version` | Yes | Semver string (e.g., `"0.1.0"`) |
| `description` | Yes | One-line summary (shown in search results) |
| `spec.artifactType` | Yes | One of: `starter-template`, `module`, `skill`, `mcp-server`, `playbook` |
| `trust_tier` | Yes | One of: `experimental`, `community`, `verified` |
| `tags` | Yes | Array of searchable keywords |
| `scoring.tokenSavingsEstimate` | Recommended | Estimated tokens saved per use |

### Artifact Types

| Type | When to Use |
|------|------------|
| `starter-template` | Scaffolds a new project or feature from scratch |
| `module` | Reusable component that plugs into existing code |
| `skill` | Structured prompt + output schema for planning/review |
| `mcp-server` | MCP server exposing tools to agents |
| `playbook` | Step-by-step operational procedure |

---

## Trust Tier Promotion

All artifacts start as `experimental`. Promotion requires evidence.

### Experimental (default)

- Created by any agent or contributor
- No review required
- May have rough edges

### Community

Requires:
- [ ] Used successfully in at least 2 distinct projects
- [ ] Has passing acceptance tests (`acceptance/test.sh` exits 0)
- [ ] Description and tags are accurate and complete
- [ ] Templates use proper variable conventions (see below)
- [ ] No hardcoded secrets or credentials in templates

### Verified

Requires everything in Community, plus:
- [ ] Reviewed by a human overseer
- [ ] Acceptance tests cover core functionality, not just "exit 0"
- [ ] Token savings estimate is based on actual measurement
- [ ] Has been stable (no breaking changes) for 30+ days

---

## Directory Structure

```
artifacts/<namespace>/<name>/
├── artifact.yaml          # Manifest (required)
├── templates/             # Template files for instantiation
│   ├── src/
│   ├── tests/
│   └── ...
├── acceptance/            # Acceptance tests
│   └── test.sh            # Must exit 0 for community+ trust
├── skills/                # Associated skill definitions (optional)
└── bounties/              # Open bounties for improvements (optional)
```

---

## Template Variable Conventions

Use double-brace syntax for substitution: `{{variable_name}}`

### Standard Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{project_name}}` | Project name (kebab-case) | `my-api` |
| `{{project_name_snake}}` | Snake case variant | `my_api` |
| `{{project_name_pascal}}` | Pascal case variant | `MyApi` |
| `{{namespace}}` | Artifact namespace | `io.github.rally-tavern` |
| `{{author}}` | Author name | `Rally Tavern` |
| `{{year}}` | Current year | `2026` |

### Substitution at Instantiation

```bash
./scripts/artifact.sh instantiate io.github.rally-tavern/python-fastapi-sso-starter \
  --into ./my-project \
  --set project_name=my-api \
  --set author="Your Name"
```

This replaces all `{{project_name}}` occurrences in template files with `my-api`.

---

## Acceptance Tests

Every artifact should have `acceptance/test.sh`. At minimum:

```bash
#!/bin/bash
set -euo pipefail

# Verify required files exist
[ -f "artifact.yaml" ] || { echo "FAIL: missing artifact.yaml"; exit 1; }
[ -d "templates" ] || { echo "FAIL: missing templates/"; exit 1; }

# Verify manifest has required fields
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq not available"; exit 0; }
name=$(yq -r '.name // ""' artifact.yaml)
[ -n "$name" ] || { echo "FAIL: manifest missing name"; exit 1; }

echo "PASS: basic validation"
```

For `community` and `verified` tiers, tests should also:
- Instantiate templates into a temp directory
- Verify the instantiated code compiles/lints
- Run any included test suites

---

## Federated Search

Artifacts are discoverable across all rigs:

```bash
# Search all rigs
./scripts/artifact.sh search "auth sso" --all-rigs

# Search only your rig
./scripts/artifact.sh search "auth sso"

# Search a specific rig
./scripts/artifact-federated-search.sh "auth sso" --rig rally_tavern
```

Results are ranked by term match, trust tier, and token savings.

---

## Workflow: From Pattern to Artifact

1. **Recognize repetition**: You've built the same auth flow for the third time
2. **Extract**: `./scripts/artifact.sh create python-auth-module --type module`
3. **Templatize**: Move code to `templates/`, replace project-specific values with `{{variables}}`
4. **Test**: Write acceptance tests that validate the template
5. **Document**: Fill in `artifact.yaml` with accurate description and tags
6. **Reindex**: `./scripts/artifact.sh reindex`
7. **Commit**: Standard git workflow, push to main

---

## Common Mistakes

- **Missing tags**: Without good tags, federated search can't find your artifact
- **Hardcoded values in templates**: Use `{{variables}}` instead
- **Empty descriptions**: One line of description makes the difference in search results
- **Skipping acceptance tests**: Even a basic file-existence check catches problems
- **Wrong namespace**: Always use your rig's namespace, not rally_tavern's
