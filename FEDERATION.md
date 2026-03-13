# 🌐 Federation

Multiple Taverns and Gas Town rigs share artifacts and knowledge through federation.

## How It Works

Rally Tavern is the canonical hub. Each Gas Town rig has its own `artifacts/` directory under its own namespace. Federated search aggregates results across all rigs, ranked by relevance, trust tier, and token savings.

```
rally_tavern (hub)                    spoke rigs
────────────────                      ──────────
artifacts/                            vitalitek/artifacts/
  io.github.rally-tavern/              io.github.outdoorsea/vitalitek/
    python-fastapi-sso-starter/       theoutlived/artifacts/
    react-css-showcase/                 io.github.outdoorsea/theoutlived/
    ...                               meety_me/artifacts/
federated-index.json ◄── aggregated     io.github.outdoorsea/meety_me/
```

## Federation Infrastructure (Live)

- **Canonical scripts** in rally_tavern: `artifact.sh`, `artifacts-search.sh`, `artifacts-json.sh`
- **`ARTIFACT_DIR_OVERRIDE`** env var in all 3 scripts — allows spoke rigs to use their own `artifacts/` directory
- **`artifact-federated-search.sh`** — cross-rig ranked search with `source_rig` annotation
- **`artifact-federated-index.sh`** — aggregates all rig indexes into `federated-index.json`
- **Shim scripts** deployed in vitalitek, theoutlived, meety_me (delegate to rally_tavern canonical scripts)
- Each rig has its own namespace and `artifacts/` directory
- Spoke rig CLAUDE.md files updated with artifact system documentation

## Cross-Rig Search

```bash
# Search all rigs
./scripts/artifact-federated-search.sh "auth sso" --all-rigs

# Search a specific rig
./scripts/artifact-federated-search.sh "auth sso" --rig vitalitek

# Rebuild the federated index
./scripts/artifact-federated-index.sh
```

Results include `source_rig` so you know where each artifact lives.

## Rig Namespaces

| Rig | Namespace |
|-----|-----------|
| rally_tavern | `io.github.rally-tavern` |
| vitalitek | `io.github.outdoorsea/vitalitek` |
| theoutlived | `io.github.outdoorsea/theoutlived` |
| meety_me | `io.github.outdoorsea/meety_me` |

## Trust Across Rigs

Content from other rigs follows the same trust tier model as local artifacts:

| Tier | Requirements |
|------|-------------|
| 🔴 Experimental | Created, no review needed |
| 🟡 Community | Used in 2+ projects, passing tests |
| 🟢 Verified | Community + human overseer review |

Use the security scanner before importing:

```bash
./scripts/security.sh scan imported-content/
```

## Knowledge Push

The `knowledge-push.sh` script finds relevant knowledge entries for a bead based on its tags and title, enabling cross-rig knowledge sharing:

```bash
./scripts/knowledge-push.sh --tags "gas-town,hooks" --title "Fix hook lifecycle"
```

## Profile Sharing

Tavern profiles (tech stack descriptions) are published to `profiles/` in rally_tavern for cross-rig discovery:

```bash
# Publish your rig's profile
cp tavern-profile.yaml rally-tavern/profiles/myrig.tavern-profile.yaml

# Discover what others use
ls profiles/
```

## Adding a New Spoke Rig

1. Create `artifacts/` directory in your rig
2. Choose your namespace (e.g., `io.github.yourorg/yourrig`)
3. Copy the shim scripts from an existing spoke rig
4. Set `ARTIFACT_DIR_OVERRIDE` to your rig's artifacts path
5. Register your namespace in `CONTRIBUTING-ARTIFACTS.md`
6. Run `./scripts/artifact-federated-index.sh` to include your rig
