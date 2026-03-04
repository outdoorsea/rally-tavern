#!/bin/bash
# Rally Tavern Artifact Management
# TCEP artifact lifecycle: create, register, list, show, instantiate, deprecate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
TEMPLATE="$ROOT_DIR/templates/artifact.yaml"
INDEX="$ARTIFACTS_DIR/.index.json"

ACTION="${1:-help}"
shift 2>/dev/null || true

# --- Helpers ---

die() { echo "❌ $1" >&2; exit 1; }

require_yq() {
  command -v yq >/dev/null 2>&1 || die "yq is required. Install: brew install yq"
}

# Generate artifact ID from namespace + name
artifact_id() {
  local namespace="$1" name="$2"
  echo "${namespace}/${name}"
}

# Find artifact directory by ID (namespace/name)
find_artifact_dir() {
  local id="$1"
  local dir="$ARTIFACTS_DIR/$id"
  [ -d "$dir" ] && echo "$dir" && return 0
  return 1
}

# Rebuild .index.json from all artifact.yaml files
rebuild_index() {
  require_yq
  echo "[" > "$INDEX"
  local first=1
  for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
    [ -f "$manifest" ] || continue
    [ $first -eq 0 ] && echo "," >> "$INDEX"
    first=0

    local name namespace version desc artifact_type trust tags
    name=$(yq -r '.name // .metadata.id // ""' "$manifest")
    namespace=$(yq -r '.namespace // ""' "$manifest")
    version=$(yq -r '.version // .metadata.version // "0.0.0"' "$manifest")
    desc=$(yq -r '.description // .metadata.description // ""' "$manifest")
    artifact_type=$(yq -r '.spec.artifactType // "unknown"' "$manifest" 2>/dev/null || echo "unknown")
    trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$manifest")
    tags=$(yq -r '(.tags // .metadata.tags // []) | @json' "$manifest" 2>/dev/null || echo "[]")
    token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")

    cat >> "$INDEX" <<ENTRY
  {
    "id": "${namespace}/${name}",
    "name": "$name",
    "namespace": "$namespace",
    "version": "$version",
    "description": "$desc",
    "artifactType": "$artifact_type",
    "trust": "$trust",
    "tags": $tags,
    "tokenSavingsEstimate": $token_savings,
    "path": "$(dirname "$manifest" | sed "s|$ARTIFACTS_DIR/||")"
  }
ENTRY
  done
  echo "" >> "$INDEX"
  echo "]" >> "$INDEX"
}

# --- Commands ---

cmd_create() {
  local name="" artifact_type="starter-template" namespace="io.github.rally-tavern"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --type) artifact_type="$2"; shift 2;;
      --namespace) namespace="$2"; shift 2;;
      *) name="$1"; shift;;
    esac
  done

  [ -z "$name" ] && die "Usage: artifact.sh create <name> [--type TYPE] [--namespace NS]"

  local dir="$ARTIFACTS_DIR/$namespace/$name"
  [ -d "$dir" ] && die "Artifact already exists: $dir"

  # Validate artifact type
  case "$artifact_type" in
    starter-template|module|skill|mcp-server|playbook) ;;
    *) die "Invalid type: $artifact_type (valid: starter-template, module, skill, mcp-server, playbook)";;
  esac

  mkdir -p "$dir"/{templates,acceptance,skills,bounties}

  # Generate manifest matching the established format (see example artifact)
  cat > "$dir/artifact.yaml" <<MANIFEST
schema_version: 1

name: $name
namespace: $namespace
version: "0.1.0"
description: ""

provides:
  - capability: ""
    style: ""

compatibility:
  platforms: []
  frameworks: []
  languages: []

trust_tier: experimental
contributed_by: ""
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

spec:
  artifactType: "$artifact_type"
  audience: "both"

scoring:
  tokenSavingsEstimate: 0

tags: []

requires: []

entrypoints:
  install: null
  configure: null
  test: acceptance/test.sh
MANIFEST

  # Create placeholder acceptance test
  cat > "$dir/acceptance/test.sh" <<'TEST'
#!/bin/bash
# Acceptance test for this artifact
echo "TODO: Add acceptance tests"
exit 0
TEST
  chmod +x "$dir/acceptance/test.sh"

  rebuild_index
  git add "$dir"

  echo "✓ Created artifact: $namespace/$name"
  echo "  Directory: $dir"
  echo "  Type: $artifact_type"
  echo "  Next: edit artifact.yaml, add templates, then commit."
}

cmd_register() {
  local path="$1"
  [ -z "$path" ] && die "Usage: artifact.sh register <path-to-artifact-dir>"
  [ -f "$path/artifact.yaml" ] || die "No artifact.yaml found in: $path"

  require_yq

  # Validate required fields
  local name namespace
  name=$(yq -r '.name // .metadata.id // ""' "$path/artifact.yaml")
  namespace=$(yq -r '.namespace // ""' "$path/artifact.yaml")

  [ -z "$name" ] && die "artifact.yaml missing 'name' or 'metadata.id'"

  # If it's already in the artifacts dir, just rebuild index
  if [[ "$path" == "$ARTIFACTS_DIR"/* ]]; then
    rebuild_index
    echo "✓ Registered artifact: $namespace/$name (index rebuilt)"
    return
  fi

  # Otherwise copy it in
  local dest="$ARTIFACTS_DIR/$namespace/$name"
  [ -d "$dest" ] && die "Artifact already exists at: $dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$path" "$dest"
  rebuild_index
  git add "$dest"

  echo "✓ Registered artifact: $namespace/$name"
  echo "  Copied to: $dest"
}

cmd_update() {
  local id="$1"
  shift || die "Usage: artifact.sh update <namespace/name> [--version VER]"

  local dir
  dir=$(find_artifact_dir "$id") || die "Artifact not found: $id"

  require_yq

  while [[ $# -gt 0 ]]; do
    case $1 in
      --version)
        yq -i ".version = \"$2\"" "$dir/artifact.yaml" 2>/dev/null ||
          yq -i ".metadata.version = \"$2\"" "$dir/artifact.yaml"
        echo "  version → $2"
        shift 2;;
      --description)
        yq -i ".description = \"$2\"" "$dir/artifact.yaml" 2>/dev/null ||
          yq -i ".metadata.description = \"$2\"" "$dir/artifact.yaml"
        echo "  description → $2"
        shift 2;;
      --trust)
        yq -i ".trust_tier = \"$2\"" "$dir/artifact.yaml" 2>/dev/null ||
          yq -i ".trust.level = \"$2\"" "$dir/artifact.yaml"
        echo "  trust → $2"
        shift 2;;
      *) shift;;
    esac
  done

  # Update timestamp
  yq -i ".provenance.updatedAt = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$dir/artifact.yaml" 2>/dev/null || true

  rebuild_index
  git add "$dir/artifact.yaml"
  echo "✓ Updated artifact: $id"
}

cmd_show() {
  local id="$1"
  [ -z "$id" ] && die "Usage: artifact.sh show <namespace/name>"

  local dir
  dir=$(find_artifact_dir "$id") || die "Artifact not found: $id"

  require_yq

  local name version desc artifact_type trust
  name=$(yq -r '.name // .metadata.id // ""' "$dir/artifact.yaml")
  version=$(yq -r '.version // .metadata.version // "?"' "$dir/artifact.yaml")
  desc=$(yq -r '.description // .metadata.description // ""' "$dir/artifact.yaml")
  artifact_type=$(yq -r '.spec.artifactType // "unknown"' "$dir/artifact.yaml" 2>/dev/null || echo "unknown")
  trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$dir/artifact.yaml")

  echo "📦 $name v$version"
  echo "   Type: $artifact_type"
  echo "   Trust: $trust"
  echo "   $desc"
  echo ""
  echo "   Path: $dir"
  echo ""

  # Show directory contents
  echo "   Contents:"
  for item in "$dir"/*/; do
    [ -d "$item" ] || continue
    local count
    count=$(find "$item" -type f 2>/dev/null | wc -l | xargs)
    echo "     $(basename "$item")/ ($count files)"
  done
}

cmd_list() {
  local filter_type="" filter_trust=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --type) filter_type="$2"; shift 2;;
      --trust) filter_trust="$2"; shift 2;;
      *) shift;;
    esac
  done

  require_yq

  echo "📦 Artifact Registry"
  echo ""

  local count=0
  for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
    [ -f "$manifest" ] || continue

    local name namespace version artifact_type trust desc
    name=$(yq -r '.name // .metadata.id // ""' "$manifest")
    namespace=$(yq -r '.namespace // ""' "$manifest")
    version=$(yq -r '.version // .metadata.version // "?"' "$manifest")
    artifact_type=$(yq -r '.spec.artifactType // "unknown"' "$manifest" 2>/dev/null || echo "unknown")
    trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$manifest")
    desc=$(yq -r '.description // .metadata.description // ""' "$manifest")

    # Apply filters
    [ -n "$filter_type" ] && [ "$artifact_type" != "$filter_type" ] && continue
    [ -n "$filter_trust" ] && [ "$trust" != "$filter_trust" ] && continue

    local trust_icon="🔴"
    case "$trust" in
      verified) trust_icon="🟢";;
      community) trust_icon="🟡";;
    esac

    echo "  $trust_icon $namespace/$name v$version [$artifact_type]"
    [ -n "$desc" ] && echo "     $desc"
    count=$((count + 1))
  done

  echo ""
  echo "  Total: $count artifacts"
}

cmd_instantiate() {
  local id="" target="" sets=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --into) target="$2"; shift 2;;
      --set) sets+=("$2"); shift 2;;
      *) id="$1"; shift;;
    esac
  done

  [ -z "$id" ] && die "Usage: artifact.sh instantiate <namespace/name> --into <dir> [--set key=value]"
  [ -z "$target" ] && die "Missing --into <target-directory>"

  local dir
  dir=$(find_artifact_dir "$id") || die "Artifact not found: $id"

  [ ! -d "$dir/templates" ] && die "Artifact has no templates/ directory"

  # Copy templates to target
  mkdir -p "$target"
  cp -r "$dir/templates/"* "$target/" 2>/dev/null || die "No files in templates/"

  # Apply --set substitutions
  for pair in "${sets[@]}"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    find "$target" -type f -exec sed -i '' "s/{{$key}}/$value/g" {} + 2>/dev/null || true
  done

  echo "✓ Instantiated $id → $target"

  # Run install skill if defined
  require_yq
  local install_skill
  install_skill=$(yq -r '.entrypoints.install // ""' "$dir/artifact.yaml" 2>/dev/null || echo "")
  if [ -n "$install_skill" ] && [ -f "$dir/$install_skill" ]; then
    echo "  📋 Install skill available: $dir/$install_skill"
  fi
}

cmd_deprecate() {
  local id="" superseded_by=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --superseded-by) superseded_by="$2"; shift 2;;
      *) id="$1"; shift;;
    esac
  done

  [ -z "$id" ] && die "Usage: artifact.sh deprecate <namespace/name> [--superseded-by NEW_ID]"

  local dir
  dir=$(find_artifact_dir "$id") || die "Artifact not found: $id"

  require_yq
  yq -i ".deprecated = true" "$dir/artifact.yaml"
  [ -n "$superseded_by" ] && yq -i ".superseded_by = \"$superseded_by\"" "$dir/artifact.yaml"
  yq -i ".provenance.updatedAt = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$dir/artifact.yaml" 2>/dev/null || true

  rebuild_index
  git add "$dir/artifact.yaml"

  echo "✓ Deprecated: $id"
  [ -n "$superseded_by" ] && echo "  Superseded by: $superseded_by"
}

cmd_validate() {
  local path="${1:-.}"
  [ -f "$path/artifact.yaml" ] || die "No artifact.yaml found in: $path"

  require_yq

  local errors=0

  # Check required fields
  local name
  name=$(yq -r '.name // .metadata.id // ""' "$path/artifact.yaml")
  if [ -z "$name" ]; then
    echo "  ❌ Missing: name or metadata.id"
    errors=$((errors + 1))
  fi

  local version
  version=$(yq -r '.version // .metadata.version // ""' "$path/artifact.yaml")
  if [ -z "$version" ]; then
    echo "  ❌ Missing: version"
    errors=$((errors + 1))
  fi

  local desc
  desc=$(yq -r '.description // .metadata.description // ""' "$path/artifact.yaml")
  if [ -z "$desc" ]; then
    echo "  ⚠️  Missing: description"
  fi

  # Check directories
  [ -d "$path/templates" ] || echo "  ⚠️  No templates/ directory"
  [ -d "$path/acceptance" ] || echo "  ⚠️  No acceptance/ directory"

  if [ $errors -eq 0 ]; then
    echo "✓ Artifact valid: $name v$version"
  else
    echo "❌ Validation failed: $errors errors"
    exit 1
  fi
}

# --- Dispatch ---

case "$ACTION" in
  create)      cmd_create "$@";;
  register)    cmd_register "$@";;
  update)      cmd_update "$@";;
  show)        cmd_show "$@";;
  list)        cmd_list "$@";;
  instantiate) cmd_instantiate "$@";;
  deprecate)   cmd_deprecate "$@";;
  validate)    cmd_validate "$@";;
  reindex)     rebuild_index; echo "✓ Index rebuilt: $INDEX";;
  help|*)
    echo "Usage: artifact.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create <name> [--type TYPE] [--namespace NS]  Create new artifact from template"
    echo "  register <path>                               Register existing artifact"
    echo "  update <id> [--version VER] [--trust LEVEL]   Update artifact metadata"
    echo "  show <id>                                     Show artifact details"
    echo "  list [--type TYPE] [--trust LEVEL]             List all artifacts"
    echo "  instantiate <id> --into <dir> [--set k=v]     Copy artifact into target"
    echo "  deprecate <id> [--superseded-by NEW_ID]       Mark artifact as deprecated"
    echo "  validate [path]                               Validate artifact manifest"
    echo "  reindex                                       Rebuild .index.json"
    echo ""
    echo "Artifact types: starter-template, module, skill, mcp-server, playbook"
    echo "Trust levels: experimental, community, verified"
    ;;
esac
