#!/bin/bash
# Federation Sync for Cross-Tavern Artifact Sharing
# Enables pulling artifacts from upstream taverns and pushing to downstreams
#
# Usage:
#   federation.sh pull <upstream-name> [--artifact ID]
#   federation.sh push <downstream-name> <ARTIFACT_ID>
#   federation.sh list-remotes
#   federation.sh status [upstream-name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"
CONFIG_FILE="$ROOT_DIR/configs/federation.yaml"
FEDERATION_DIR="$ROOT_DIR/.federation"

die() { echo "❌ $1" >&2; exit 1; }

require_yq() {
  command -v yq >/dev/null 2>&1 || die "yq is required. Install: brew install yq"
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required. Install: brew install jq"
}

require_config() {
  [ -f "$CONFIG_FILE" ] || die "Federation config not found: $CONFIG_FILE"
}

# Read a value from federation config
config_get() {
  yq -r "$1" "$CONFIG_FILE" 2>/dev/null
}

# Count upstream/downstream entries
config_count() {
  local path="$1"
  local count
  count=$(yq -r "$path | length // 0" "$CONFIG_FILE" 2>/dev/null)
  echo "${count:-0}"
}

# Get upstream config by name
get_upstream() {
  local name="$1"
  local count
  count=$(config_count '.upstreams')
  for i in $(seq 0 $((count - 1))); do
    local uname
    uname=$(config_get ".upstreams[$i].name")
    if [ "$uname" = "$name" ]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# Get downstream config by name
get_downstream() {
  local name="$1"
  local count
  count=$(config_count '.downstreams')
  for i in $(seq 0 $((count - 1))); do
    local dname
    dname=$(config_get ".downstreams[$i].name")
    if [ "$dname" = "$name" ]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# Check if namespace is allowed for an upstream/downstream
check_namespace_allowed() {
  local config_path="$1"  # e.g., .upstreams[0]
  local namespace="$2"

  # Check excluded namespaces
  local excluded_count
  excluded_count=$(yq -r "$config_path.excludedNamespaces | length // 0" "$CONFIG_FILE" 2>/dev/null)
  if [ "${excluded_count:-0}" -gt 0 ]; then
    for i in $(seq 0 $((excluded_count - 1))); do
      local pattern
      pattern=$(config_get "$config_path.excludedNamespaces[$i]")
      if [[ "$namespace" == $pattern ]]; then
        return 1
      fi
    done
  fi

  # Check allowed namespaces (empty = all allowed)
  local allowed_count
  allowed_count=$(yq -r "$config_path.allowedNamespaces | length // 0" "$CONFIG_FILE" 2>/dev/null)
  if [ "${allowed_count:-0}" -eq 0 ]; then
    return 0  # No restrictions
  fi

  for i in $(seq 0 $((allowed_count - 1))); do
    local pattern
    pattern=$(config_get "$config_path.allowedNamespaces[$i]")
    if [[ "$namespace" == $pattern ]]; then
      return 0
    fi
  done

  return 1  # Not in allowed list
}

# Apply trust policy to determine if an artifact should be imported
check_trust_policy() {
  local policy="$1"
  local manifest="$2"

  local trust_level
  trust_level=$(yq -r '.trust.level // .trust_tier // "experimental"' "$manifest" 2>/dev/null)

  local has_approval="false"
  local approval_count
  approval_count=$(yq -r '.trust.approvals | length // 0' "$manifest" 2>/dev/null)
  [ "${approval_count:-0}" -gt 0 ] && has_approval="true"

  local scan_status
  scan_status=$(yq -r '.trust.security.scanners[0].status // .trust.securityScans.status // "pending"' "$manifest" 2>/dev/null)

  case "$policy" in
    require-sheriff-approved)
      if [ "$has_approval" != "true" ]; then
        echo "REJECTED: No sheriff approval found (policy: $policy)"
        return 1
      fi
      ;;
    require-security-scan)
      # We'll run our own scan after import — this just requires the source had one
      if [ "$scan_status" = "pending" ] || [ "$scan_status" = "null" ]; then
        echo "NOTE: Source has no security scan — will scan locally after import"
      fi
      ;;
    accept-verified)
      if [ "$trust_level" != "verified" ]; then
        echo "REJECTED: Trust level is '$trust_level', policy requires 'verified'"
        return 1
      fi
      ;;
    accept-community)
      if [ "$trust_level" != "community" ] && [ "$trust_level" != "verified" ]; then
        echo "REJECTED: Trust level is '$trust_level', policy requires 'community' or higher"
        return 1
      fi
      ;;
    accept-all)
      ;;
    *)
      echo "WARNING: Unknown trust policy '$policy', defaulting to require-security-scan"
      ;;
  esac

  return 0
}

# Clone or update a remote tavern repo
sync_remote() {
  local name="$1"
  local url="$2"
  local remote_dir="$FEDERATION_DIR/remotes/$name"

  mkdir -p "$FEDERATION_DIR/remotes"

  if [ -d "$remote_dir/.git" ]; then
    echo "  Updating remote '$name'..."
    git -C "$remote_dir" fetch origin 2>/dev/null
    git -C "$remote_dir" reset --hard origin/HEAD 2>/dev/null || \
      git -C "$remote_dir" reset --hard origin/main 2>/dev/null || \
      echo "  Warning: Could not reset to latest — using cached version"
  else
    echo "  Cloning remote '$name' from $url..."
    git clone --depth 1 "$url" "$remote_dir" 2>/dev/null || \
      die "Failed to clone remote '$name' from $url"
  fi

  echo "$remote_dir"
}

# Import a single artifact from a remote into local artifacts
import_artifact() {
  local remote_artifact_dir="$1"
  local upstream_name="$2"
  local upstream_url="$3"
  local trust_policy="$4"
  local manifest="$remote_artifact_dir/artifact.yaml"

  [ -f "$manifest" ] || die "No artifact.yaml in $remote_artifact_dir"

  local name namespace artifact_id
  name=$(yq -r '.name // .metadata.id // ""' "$manifest")
  namespace=$(yq -r '.namespace // ""' "$manifest")
  artifact_id="$namespace/$name"

  [ -z "$name" ] && die "Artifact has no name"
  [ -z "$namespace" ] && die "Artifact has no namespace"

  echo ""
  echo "📦 Importing: $artifact_id"

  # Check trust policy
  local policy_result
  if ! policy_result=$(check_trust_policy "$trust_policy" "$manifest"); then
    echo "  $policy_result"
    echo "  ⏭️  Skipped"
    return 1
  fi
  [ -n "${policy_result:-}" ] && echo "  $policy_result"

  local dest_dir="$ARTIFACTS_DIR/$artifact_id"

  # Check if artifact already exists
  if [ -d "$dest_dir" ]; then
    local local_version remote_version
    local_version=$(yq -r '.version // .metadata.version // "0.0.0"' "$dest_dir/artifact.yaml" 2>/dev/null)
    remote_version=$(yq -r '.version // .metadata.version // "0.0.0"' "$manifest" 2>/dev/null)

    if [ "$local_version" = "$remote_version" ]; then
      echo "  Already exists at version $local_version — skipping"
      return 0
    fi
    echo "  Updating: $local_version → $remote_version"
  fi

  # Copy artifact directory
  mkdir -p "$dest_dir"
  cp -R "$remote_artifact_dir"/* "$dest_dir/" 2>/dev/null || true
  cp -R "$remote_artifact_dir"/.[^.]* "$dest_dir/" 2>/dev/null || true

  # Apply trust policy: reset trust on import if configured
  local reset_trust
  reset_trust=$(config_get '.resetTrustOnImport // true')
  if [ "$reset_trust" = "true" ]; then
    local original_trust
    original_trust=$(yq -r '.trust.level // .trust_tier // "experimental"' "$dest_dir/artifact.yaml" 2>/dev/null)
    yq -i '.trust.level = "experimental"' "$dest_dir/artifact.yaml"
    echo "  Trust reset: $original_trust → experimental (policy: resetTrustOnImport)"
  fi

  # Track provenance
  local track_provenance
  track_provenance=$(config_get '.trackProvenance // true')
  if [ "$track_provenance" = "true" ]; then
    local import_time
    import_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local source_revision
    source_revision=$(git -C "$(dirname "$remote_artifact_dir")" rev-parse HEAD 2>/dev/null || echo "unknown")

    yq -i ".provenance.federation.importedFrom = \"$upstream_name\"" "$dest_dir/artifact.yaml"
    yq -i ".provenance.federation.sourceUrl = \"$upstream_url\"" "$dest_dir/artifact.yaml"
    yq -i ".provenance.federation.importedAt = \"$import_time\"" "$dest_dir/artifact.yaml"
    yq -i ".provenance.federation.sourceRevision = \"$source_revision\"" "$dest_dir/artifact.yaml"

    # Preserve original provenance if present
    local orig_repo
    orig_repo=$(yq -r '.provenance.sourceRepo // ""' "$manifest" 2>/dev/null)
    if [ -n "$orig_repo" ] && [ "$orig_repo" != "null" ]; then
      yq -i ".provenance.federation.originalRepo = \"$orig_repo\"" "$dest_dir/artifact.yaml"
    fi

    echo "  Provenance recorded: imported from '$upstream_name'"
  fi

  # Run local security scan
  echo "  Running security scan..."
  if "$SCRIPT_DIR/security.sh" scan-artifact "$artifact_id" > /dev/null 2>&1; then
    echo "  ✅ Security scan passed"
  else
    echo "  ⚠️  Security scan found issues — review before promoting trust"
  fi

  echo "  ✅ Imported: $artifact_id"
  return 0
}

# --- Commands ---

cmd_pull() {
  local upstream_name=""
  local artifact_filter=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --artifact) artifact_filter="$2"; shift 2;;
      *) upstream_name="$1"; shift;;
    esac
  done

  [ -z "$upstream_name" ] && die "Usage: federation.sh pull <upstream-name> [--artifact ID]"

  require_config
  require_yq

  local idx
  idx=$(get_upstream "$upstream_name") || die "Upstream '$upstream_name' not found in $CONFIG_FILE"

  local url trust_policy
  url=$(config_get ".upstreams[$idx].url")
  trust_policy=$(config_get ".upstreams[$idx].trustPolicy // .defaultTrustPolicy // \"require-security-scan\"")

  [ "$url" = "null" ] || [ -z "$url" ] && die "No URL configured for upstream '$upstream_name'"

  echo "🔄 Pulling from upstream: $upstream_name"
  echo "  URL: $url"
  echo "  Trust policy: $trust_policy"

  # Sync remote repo
  local remote_dir
  remote_dir=$(sync_remote "$upstream_name" "$url")

  # Find artifacts in the remote
  local imported=0 skipped=0
  local remote_artifacts_dir="$remote_dir/artifacts"

  [ -d "$remote_artifacts_dir" ] || die "No artifacts/ directory found in remote '$upstream_name'"

  for manifest in "$remote_artifacts_dir"/*/*/artifact.yaml; do
    [ -f "$manifest" ] || continue
    local artifact_dir
    artifact_dir=$(dirname "$manifest")

    local name namespace artifact_id
    name=$(yq -r '.name // .metadata.id // ""' "$manifest")
    namespace=$(yq -r '.namespace // ""' "$manifest")
    artifact_id="$namespace/$name"

    # Apply artifact filter if specified
    if [ -n "$artifact_filter" ] && [ "$artifact_id" != "$artifact_filter" ]; then
      continue
    fi

    # Check namespace restrictions
    local config_path=".upstreams[$idx]"
    if ! check_namespace_allowed "$config_path" "$namespace"; then
      echo "  ⏭️  Namespace '$namespace' not allowed — skipping $artifact_id"
      skipped=$((skipped + 1))
      continue
    fi

    # Skip deprecated
    local deprecated
    deprecated=$(yq -r '.deprecated // false' "$manifest" 2>/dev/null)
    [ "$deprecated" = "true" ] && continue

    if import_artifact "$artifact_dir" "$upstream_name" "$url" "$trust_policy"; then
      imported=$((imported + 1))
    else
      skipped=$((skipped + 1))
    fi
  done

  echo ""
  echo "📊 Pull complete: $imported imported, $skipped skipped"

  # Rebuild index
  if [ $imported -gt 0 ]; then
    echo "  Rebuilding artifact index..."
    "$SCRIPT_DIR/artifact.sh" reindex
  fi
}

cmd_push() {
  local downstream_name=""
  local artifact_id=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      */*) artifact_id="$1"; shift;;
      *) downstream_name="$1"; shift;;
    esac
  done

  [ -z "$downstream_name" ] && die "Usage: federation.sh push <downstream-name> <ARTIFACT_ID>"
  [ -z "$artifact_id" ] && die "Usage: federation.sh push <downstream-name> <ARTIFACT_ID>"

  require_config
  require_yq

  local idx
  idx=$(get_downstream "$downstream_name") || die "Downstream '$downstream_name' not found in $CONFIG_FILE"

  local url require_trust
  url=$(config_get ".downstreams[$idx].url")
  require_trust=$(config_get ".downstreams[$idx].requireTrust // \"experimental\"")

  [ "$url" = "null" ] || [ -z "$url" ] && die "No URL configured for downstream '$downstream_name'"

  # Check artifact exists locally
  local artifact_dir="$ARTIFACTS_DIR/$artifact_id"
  [ -d "$artifact_dir" ] || die "Artifact not found locally: $artifact_id"
  [ -f "$artifact_dir/artifact.yaml" ] || die "No artifact.yaml in: $artifact_dir"

  local manifest="$artifact_dir/artifact.yaml"

  # Check namespace allowed for downstream
  local namespace
  namespace=$(yq -r '.namespace // ""' "$manifest")
  local config_path=".downstreams[$idx]"
  if ! check_namespace_allowed "$config_path" "$namespace"; then
    die "Namespace '$namespace' is not allowed for downstream '$downstream_name'"
  fi

  # Check trust level meets minimum
  local trust_level
  trust_level=$(yq -r '.trust.level // .trust_tier // "experimental"' "$manifest")

  local trust_rank_local trust_rank_required
  case "$trust_level" in
    verified) trust_rank_local=3;;
    community) trust_rank_local=2;;
    *) trust_rank_local=1;;
  esac
  case "$require_trust" in
    verified) trust_rank_required=3;;
    community) trust_rank_required=2;;
    *) trust_rank_required=1;;
  esac

  if [ "$trust_rank_local" -lt "$trust_rank_required" ]; then
    die "Artifact trust '$trust_level' does not meet minimum '$require_trust' for downstream '$downstream_name'"
  fi

  echo "📤 Pushing to downstream: $downstream_name"
  echo "  Artifact: $artifact_id"
  echo "  URL: $url"
  echo "  Trust: $trust_level (meets minimum: $require_trust)"

  # Sync remote repo
  local remote_dir
  remote_dir=$(sync_remote "$downstream_name" "$url")

  # Copy artifact to remote
  local remote_artifacts_dir="$remote_dir/artifacts"
  local dest_dir="$remote_artifacts_dir/$artifact_id"
  mkdir -p "$dest_dir"
  cp -R "$artifact_dir"/* "$dest_dir/" 2>/dev/null || true
  cp -R "$artifact_dir"/.[^.]* "$dest_dir/" 2>/dev/null || true

  # Add export provenance
  local export_time
  export_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  yq -i ".provenance.federation.exportedBy = \"rally-tavern\"" "$dest_dir/artifact.yaml"
  yq -i ".provenance.federation.exportedAt = \"$export_time\"" "$dest_dir/artifact.yaml"

  # Commit and push
  cd "$remote_dir"
  git add "artifacts/$artifact_id" 2>/dev/null
  if git diff --cached --quiet 2>/dev/null; then
    echo "  No changes to push (artifact already up to date)"
  else
    git commit -m "federation: import $artifact_id from rally-tavern" 2>/dev/null
    echo "  Committed to downstream repo"
    echo ""
    echo "  ⚠️  To complete the push, run:"
    echo "     cd $remote_dir && git push origin"
    echo ""
    echo "  (Automatic push disabled for safety — review changes first)"
  fi

  echo "  ✅ Push prepared: $artifact_id → $downstream_name"
}

cmd_list_remotes() {
  require_config
  require_yq

  echo "🌐 Federation Remotes"
  echo ""

  local upstream_count
  upstream_count=$(config_count '.upstreams')
  echo "📥 Upstreams ($upstream_count):"
  if [ "$upstream_count" -gt 0 ]; then
    for i in $(seq 0 $((upstream_count - 1))); do
      local name url policy auto_sync
      name=$(config_get ".upstreams[$i].name")
      url=$(config_get ".upstreams[$i].url")
      policy=$(config_get ".upstreams[$i].trustPolicy // \"default\"")
      auto_sync=$(config_get ".upstreams[$i].autoSync // false")

      local cached=""
      [ -d "$FEDERATION_DIR/remotes/$name/.git" ] && cached=" (cached)"

      echo "  - $name"
      echo "    URL: $url"
      echo "    Trust policy: $policy"
      echo "    Auto-sync: $auto_sync$cached"
    done
  else
    echo "  (none configured)"
  fi

  echo ""
  local downstream_count
  downstream_count=$(config_count '.downstreams')
  echo "📤 Downstreams ($downstream_count):"
  if [ "$downstream_count" -gt 0 ]; then
    for i in $(seq 0 $((downstream_count - 1))); do
      local name url require_trust
      name=$(config_get ".downstreams[$i].name")
      url=$(config_get ".downstreams[$i].url")
      require_trust=$(config_get ".downstreams[$i].requireTrust // \"experimental\"")

      local cached=""
      [ -d "$FEDERATION_DIR/remotes/$name/.git" ] && cached=" (cached)"

      echo "  - $name"
      echo "    URL: $url"
      echo "    Min trust: $require_trust$cached"
    done
  else
    echo "  (none configured)"
  fi

  echo ""
  echo "Default trust policy: $(config_get '.defaultTrustPolicy // "require-security-scan"')"
  echo "Reset trust on import: $(config_get '.resetTrustOnImport // true')"
  echo "Track provenance: $(config_get '.trackProvenance // true')"
}

cmd_status() {
  local upstream_name="${1:-}"
  require_config
  require_yq

  if [ -n "$upstream_name" ]; then
    local idx
    idx=$(get_upstream "$upstream_name") || die "Upstream '$upstream_name' not found"

    local url
    url=$(config_get ".upstreams[$idx].url")
    local remote_dir="$FEDERATION_DIR/remotes/$upstream_name"

    echo "📊 Federation Status: $upstream_name"
    echo "  URL: $url"

    if [ -d "$remote_dir/.git" ]; then
      local last_fetch
      last_fetch=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$remote_dir/.git/FETCH_HEAD" 2>/dev/null || echo "unknown")
      local remote_count=0
      for manifest in "$remote_dir"/artifacts/*/*/artifact.yaml; do
        [ -f "$manifest" ] || continue
        remote_count=$((remote_count + 1))
      done
      echo "  Last synced: $last_fetch"
      echo "  Remote artifacts: $remote_count"
    else
      echo "  Status: Not yet synced (run 'federation.sh pull $upstream_name')"
    fi

    # Show imported artifacts from this upstream
    echo ""
    echo "  Imported from this upstream:"
    local imported_count=0
    for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
      [ -f "$manifest" ] || continue
      local imported_from
      imported_from=$(yq -r '.provenance.federation.importedFrom // ""' "$manifest" 2>/dev/null)
      if [ "$imported_from" = "$upstream_name" ]; then
        local aid
        aid=$(yq -r '(.namespace // "") + "/" + (.name // .metadata.id // "unknown")' "$manifest")
        local ver
        ver=$(yq -r '.version // .metadata.version // "?"' "$manifest")
        echo "    - $aid (v$ver)"
        imported_count=$((imported_count + 1))
      fi
    done
    [ $imported_count -eq 0 ] && echo "    (none)"
  else
    # Show overall status
    echo "📊 Federation Status"
    echo ""

    local total_imported=0
    for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
      [ -f "$manifest" ] || continue
      local imported_from
      imported_from=$(yq -r '.provenance.federation.importedFrom // ""' "$manifest" 2>/dev/null)
      [ -n "$imported_from" ] && [ "$imported_from" != "null" ] && total_imported=$((total_imported + 1))
    done

    echo "  Total imported artifacts: $total_imported"
    echo ""

    local upstream_count
    upstream_count=$(config_count '.upstreams')
    if [ "$upstream_count" -gt 0 ]; then
      for i in $(seq 0 $((upstream_count - 1))); do
        local name
        name=$(config_get ".upstreams[$i].name")
        local cached="not synced"
        [ -d "$FEDERATION_DIR/remotes/$name/.git" ] && cached="synced"
        echo "  📥 $name: $cached"
      done
    fi

    local downstream_count
    downstream_count=$(config_count '.downstreams')
    if [ "$downstream_count" -gt 0 ]; then
      for i in $(seq 0 $((downstream_count - 1))); do
        local name
        name=$(config_get ".downstreams[$i].name")
        local cached="not synced"
        [ -d "$FEDERATION_DIR/remotes/$name/.git" ] && cached="synced"
        echo "  📤 $name: $cached"
      done
    fi
  fi
}

# --- Main ---

ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  pull)       cmd_pull "$@";;
  push)       cmd_push "$@";;
  list-remotes) cmd_list_remotes;;
  status)     cmd_status "$@";;
  *)
    echo "Federation Sync — Cross-Tavern Artifact Sharing"
    echo ""
    echo "Usage:"
    echo "  federation.sh pull <upstream-name> [--artifact ID]   Pull artifacts from upstream"
    echo "  federation.sh push <downstream-name> <ARTIFACT_ID>   Push artifact to downstream"
    echo "  federation.sh list-remotes                           List configured remotes"
    echo "  federation.sh status [upstream-name]                 Show federation status"
    echo ""
    echo "Config: $CONFIG_FILE"
    echo ""
    echo "Trust policies:"
    echo "  require-sheriff-approved   Only import sheriff-approved artifacts"
    echo "  require-security-scan      Run local security scan on import"
    echo "  accept-verified            Only import verified-trust artifacts"
    echo "  accept-community           Import community or verified artifacts"
    echo "  accept-all                 Import any artifact (use with caution)"
    ;;
esac
