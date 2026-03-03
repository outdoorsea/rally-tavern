# Artifact Registry

Reusable component registry for Rally Tavern. Artifacts are versioned,
namespaced modules that provide capabilities (auth, CRUD, testing, etc.)
and can be resolved against project profiles.

## Directory Structure

```
artifacts/
├── README.md           # This file
├── .index.json         # Auto-generated artifact index
└── {namespace}/
    └── {artifact-name}/
        ├── artifact.yaml   # Manifest: metadata, capabilities, compatibility
        ├── templates/      # Artifact template files (code, configs, etc.)
        ├── acceptance/     # Test/validation scripts
        ├── skills/         # Install/configure skills (Agent Skills compatible)
        └── bounties/       # Related bounty history
```

## Namespace Convention

Namespaces use a reverse-DNS pattern bound to GitHub org or user identity:

| Pattern | Example | Use Case |
|---------|---------|----------|
| `io.github.{user}` | `io.github.alice` | Personal GitHub artifacts |
| `io.github.{org}` | `io.github.acme-corp` | Organization artifacts |
| `com.{domain}` | `com.example` | Custom domain artifacts |

This mirrors the MCP Registry pattern, enabling:
- **Authenticity**: Namespace ownership can be verified via DNS/GitHub
- **Federation**: Artifacts can be shared between taverns without collision
- **Discovery**: Namespace browsing and search by origin

## Artifact Manifest (artifact.yaml)

Each artifact must have an `artifact.yaml` at its root with:

```yaml
schema_version: 1
name: my-artifact            # Unique within namespace
namespace: io.github.user    # Owner namespace
version: "0.1.0"             # Semver
description: "Short summary"

# What this artifact provides
provides:
  - capability: auth         # Capability identifier
    style: jwt               # Implementation style

# Compatibility constraints
compatibility:
  platforms: [python-web]    # Required platform facets
  frameworks: [fastapi]     # Required framework facets
  languages: [python]       # Required language facets

# Trust and maturity
trust_tier: experimental     # experimental | community | verified
contributed_by: user-name
```

## Commands

```bash
# Search artifacts by capability
rally component search auth

# List artifacts matching a project profile
rally component list --capability auth --profile project-profile.yaml

# Validate an artifact manifest
rally component validate artifacts/io.github.user/my-artifact/

# Add a new artifact to the index
rally component add artifacts/io.github.user/my-artifact/
```

## Contributing Artifacts

1. Create a directory under your namespace: `artifacts/{namespace}/{name}/`
2. Add `artifact.yaml` with the required fields
3. Add template files in `templates/`
4. Add acceptance tests in `acceptance/`
5. Run `rally component validate` to check your manifest
6. Submit via PR or bounty workflow
