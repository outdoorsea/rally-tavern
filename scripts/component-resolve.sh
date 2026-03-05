#!/bin/bash
# Component Resolution Engine
# Matches project needs (from profile) to component registry
#
# Scoring algorithm:
#   1. Required facet compatibility (hard filter — platform, language, framework)
#   2. Capability match (hard filter or bonus for partial match)
#   3. Trust tier score (verified=15, community=10, experimental=0)
#   4. Stability score (version maturity: 1.x=10, 0.x=5, 0.0.x=0)
#   5. Reuse count (usage frequency: 2 points per use, cap 10)
#   6. Token savings bonus (scaled, cap 10)
#
# Usage: component-resolve.sh <profile.yaml> [--capability CAP] [--format human|json] [--limit N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACT_DIR_OVERRIDE:-$ROOT_DIR/artifacts}"

source "$ROOT_DIR/lib/common.sh"

PROFILE=""
FILTER_CAPABILITY=""
FORMAT="human"
LIMIT=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --capability) FILTER_CAPABILITY="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --help|-h)
      echo "Usage: component-resolve.sh <profile.yaml> [options]"
      echo ""
      echo "Options:"
      echo "  --capability CAP   Filter to components providing a specific capability"
      echo "  --format human|json  Output format (default: human)"
      echo "  --limit N          Max results (default: 10)"
      exit 0
      ;;
    *)
      if [[ -z "$PROFILE" ]]; then
        PROFILE="$1"
      fi
      shift
      ;;
  esac
done

[[ -z "$PROFILE" ]] && { log_error "Usage: component-resolve.sh <profile.yaml> [--capability CAP] [--format human|json]"; exit 1; }
[[ -f "$PROFILE" ]] || { log_error "Profile not found: $PROFILE"; exit 1; }

command -v yq >/dev/null 2>&1 || { log_error "yq is required. Install: brew install yq"; exit 1; }

# --- Read project profile ---
PROJ_PLATFORM=$(yq -r '.platform // ""' "$PROFILE" 2>/dev/null)
PROJ_LANGUAGE=$(yq -r '.language // ""' "$PROFILE" 2>/dev/null)
PROJ_FRAMEWORK=$(yq -r '.framework // ""' "$PROFILE" 2>/dev/null)
PROJ_AUTH=$(yq -r '.facets.auth // "none"' "$PROFILE" 2>/dev/null)
PROJ_DATABASE=$(yq -r '.facets.database // "none"' "$PROFILE" 2>/dev/null)
PROJ_API=$(yq -r '.facets.api_style // "none"' "$PROFILE" 2>/dev/null)
PROJ_DEPLOYMENT=$(yq -r '.facets.deployment // "local"' "$PROFILE" 2>/dev/null)
PROJ_UI=$(yq -r '.facets.ui // "none"' "$PROFILE" 2>/dev/null)

# Map common facets to capability search terms
derive_needed_capabilities() {
  local caps=()
  [[ "$PROJ_AUTH" != "none" ]] && caps+=("user-authentication")
  [[ "$PROJ_DATABASE" != "none" ]] && caps+=("database")
  [[ "$PROJ_API" != "none" ]] && caps+=("api-server")
  [[ "$PROJ_UI" != "none" ]] && caps+=("ui-scaffold")
  echo "${caps[*]}"
}

NEEDED_CAPS=$(derive_needed_capabilities)

# --- Score each artifact ---
results=()

for manifest in "$ARTIFACTS_DIR"/*/*/artifact.yaml; do
  [[ -f "$manifest" ]] || continue

  # Skip deprecated
  deprecated=$(yq -r '.deprecated // false' "$manifest" 2>/dev/null || echo "false")
  [[ "$deprecated" = "true" ]] && continue

  name=$(yq -r '.name // .metadata.id // ""' "$manifest")
  namespace=$(yq -r '.namespace // ""' "$manifest")
  version=$(yq -r '.version // .metadata.version // "0.0.0"' "$manifest")
  desc=$(yq -r '.description // .metadata.description // ""' "$manifest")
  artifact_type=$(yq -r '.spec.artifactType // "unknown"' "$manifest" 2>/dev/null || echo "unknown")
  trust=$(yq -r '.trust_tier // .trust.level // "experimental"' "$manifest")

  # --- 1. Required facet compatibility (hard filter) ---
  # Read component compatibility
  comp_platforms=$(yq -r '(.compatibility.platforms // .spec.compatibility.platforms // []) | .[]' "$manifest" 2>/dev/null || echo "")
  comp_languages=$(yq -r '(.compatibility.languages // .spec.compatibility.languages // []) | .[]' "$manifest" 2>/dev/null || echo "")
  comp_frameworks=$(yq -r '(.compatibility.frameworks // .spec.compatibility.frameworks // []) | .[]' "$manifest" 2>/dev/null || echo "")

  # If component declares compatibility constraints, project must match at least one
  platform_ok=true
  if [[ -n "$comp_platforms" ]] && [[ -n "$PROJ_PLATFORM" ]]; then
    platform_ok=false
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if [[ "$p" = "$PROJ_PLATFORM" ]]; then
        platform_ok=true
        break
      fi
    done <<< "$comp_platforms"
  fi
  $platform_ok || continue

  language_ok=true
  if [[ -n "$comp_languages" ]] && [[ -n "$PROJ_LANGUAGE" ]]; then
    language_ok=false
    while IFS= read -r l; do
      [[ -z "$l" ]] && continue
      if [[ "$l" = "$PROJ_LANGUAGE" ]]; then
        language_ok=true
        break
      fi
    done <<< "$comp_languages"
  fi
  $language_ok || continue

  # --- 2. Capability match ---
  comp_caps=$(yq -r '(.provides // []) | .[].capability' "$manifest" 2>/dev/null || echo "")

  # If filtering by specific capability, hard-filter
  if [[ -n "$FILTER_CAPABILITY" ]]; then
    cap_match=false
    cap_lower=$(echo "$FILTER_CAPABILITY" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r c; do
      [[ -z "$c" ]] && continue
      c_lower=$(echo "$c" | tr '[:upper:]' '[:lower:]')
      if [[ "$c_lower" == *"$cap_lower"* ]]; then
        cap_match=true
        break
      fi
    done <<< "$comp_caps"
    $cap_match || continue
  fi

  # Score capability matches against derived project needs
  score=0
  cap_matches=0
  for needed in $NEEDED_CAPS; do
    needed_lower=$(echo "$needed" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r c; do
      [[ -z "$c" ]] && continue
      c_lower=$(echo "$c" | tr '[:upper:]' '[:lower:]')
      if [[ "$c_lower" == *"$needed_lower"* ]]; then
        score=$((score + 15))
        cap_matches=$((cap_matches + 1))
        break
      fi
    done <<< "$comp_caps"
  done

  # If no capability matches and no filter, give base score for compatibility
  if [[ $cap_matches -eq 0 ]] && [[ -z "$FILTER_CAPABILITY" ]]; then
    score=5  # Compatible but no direct capability match
  fi

  # Framework bonus (optional facet compatibility)
  if [[ -n "$comp_frameworks" ]] && [[ -n "$PROJ_FRAMEWORK" ]]; then
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if [[ "$f" = "$PROJ_FRAMEWORK" ]]; then
        score=$((score + 10))
        break
      fi
    done <<< "$comp_frameworks"
  fi

  # --- 3. Trust tier score ---
  case "$trust" in
    verified)     score=$((score + 15));;
    community)    score=$((score + 10));;
    experimental) score=$((score + 0));;
  esac

  # --- 4. Stability score (version maturity) ---
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  if [[ "$major" -ge 1 ]] 2>/dev/null; then
    score=$((score + 10))  # Stable release
  elif [[ "$minor" -ge 1 ]] 2>/dev/null; then
    score=$((score + 5))   # Pre-release with features
  fi
  # 0.0.x gets no bonus

  # --- 5. Reuse count ---
  artifact_dir=$(dirname "$manifest")
  usage_file="$artifact_dir/.usage.jsonl"
  use_count=0
  total_actual_saved=0
  if [[ -f "$usage_file" ]]; then
    while IFS= read -r uline; do
      [[ -z "$uline" ]] && continue
      use_count=$((use_count + 1))
      utokens=$(echo "$uline" | jq -r '.tokensSaved // 0' 2>/dev/null || echo "0")
      total_actual_saved=$((total_actual_saved + utokens))
    done < "$usage_file"
  fi
  use_bonus=$((use_count * 2))
  [[ $use_bonus -gt 10 ]] && use_bonus=10
  score=$((score + use_bonus))

  # --- 6. Token savings bonus ---
  token_savings=$(yq -r '.scoring.tokenSavingsEstimate.estimatedSavingsTokens // null' "$manifest" 2>/dev/null)
  if [[ "$token_savings" = "null" ]] || [[ -z "$token_savings" ]]; then
    token_savings=$(yq -r '.scoring.tokenSavingsEstimate // 0' "$manifest" 2>/dev/null || echo "0")
    case "$token_savings" in *baselineTokens*|*{*) token_savings=0;; esac
  fi
  if [[ "$token_savings" -gt 0 ]] 2>/dev/null; then
    savings_bonus=$((token_savings / 10000))
    [[ $savings_bonus -gt 10 ]] && savings_bonus=10
    score=$((score + savings_bonus))
  fi

  # Collect capabilities as comma-separated string
  caps_display=$(yq -r '(.provides // []) | .[] | "\(.capability):\(.style // "any")"' "$manifest" 2>/dev/null | paste -sd, - || echo "")

  results+=("$score|$namespace/$name|$version|$artifact_type|$trust|$token_savings|$desc|$caps_display|$use_count|$cap_matches")
done

# Sort by score descending
if [[ ${#results[@]} -eq 0 ]]; then
  if [[ "$FORMAT" = "json" ]]; then
    echo '{"components": [], "count": 0, "profile": "'"$PROFILE"'", "unmatched_capabilities": []}'
  else
    echo "No compatible components found for profile: $PROFILE"
    if [[ -n "$FILTER_CAPABILITY" ]]; then
      echo "  Capability filter: $FILTER_CAPABILITY"
    fi
    echo ""
    echo "  Unmatched needs (build candidates):"
    for cap in $NEEDED_CAPS; do
      echo "    → $cap"
    done
  fi
  exit 0
fi

IFS=$'\n' sorted=($(printf '%s\n' "${results[@]}" | sort -t'|' -k1 -nr))
unset IFS

# --- Output ---
if [[ "$FORMAT" = "json" ]]; then
  echo '{"components": ['
  count=0
  for entry in "${sorted[@]}"; do
    [[ $count -ge $LIMIT ]] && break
    IFS='|' read -r score id version atype trust savings desc caps use_count cap_matches <<< "$entry"
    [[ $count -gt 0 ]] && echo ","
    cat <<ENTRY
  {
    "id": "$id",
    "version": "$version",
    "artifactType": "$atype",
    "trust": "$trust",
    "score": $score,
    "capabilityMatches": $cap_matches,
    "tokenSavingsEstimate": $savings,
    "useCount": ${use_count:-0},
    "provides": "$caps",
    "description": "$desc"
  }
ENTRY
    count=$((count + 1))
  done
  echo ""
  echo '],'

  # Identify unmatched capabilities
  echo '"unmatchedCapabilities": ['
  first_unmatched=true
  for cap in $NEEDED_CAPS; do
    matched=false
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ _ _ _ _ _ _ caps _ _ <<< "$entry"
      cap_lower=$(echo "$cap" | tr '[:upper:]' '[:lower:]')
      caps_lower=$(echo "$caps" | tr '[:upper:]' '[:lower:]')
      if [[ "$caps_lower" == *"$cap_lower"* ]]; then
        matched=true
        break
      fi
    done
    if ! $matched; then
      $first_unmatched || echo ","
      echo "  \"$cap\""
      first_unmatched=false
    fi
  done
  echo '],'
  echo "\"count\": $count,"
  echo "\"profile\": \"$PROFILE\""
  echo '}'
else
  # Human-readable output
  echo "🔍 Component Resolution for: $PROFILE"
  echo "   Platform: ${PROJ_PLATFORM:-any}  Language: ${PROJ_LANGUAGE:-any}  Framework: ${PROJ_FRAMEWORK:-any}"
  echo ""

  count=0
  for entry in "${sorted[@]}"; do
    [[ $count -ge $LIMIT ]] && break
    IFS='|' read -r score id version atype trust savings desc caps use_count cap_matches <<< "$entry"

    local trust_icon="🔴"
    case "$trust" in
      verified) trust_icon="🟢";;
      community) trust_icon="🟡";;
      *) trust_icon="🔴";;
    esac

    echo "  $trust_icon [$score pts] $id v$version"
    [[ -n "$desc" ]] && echo "     $desc"
    [[ -n "$caps" ]] && echo "     Provides: $caps"
    [[ "${use_count:-0}" -gt 0 ]] && echo "     Usage: $use_count uses"
    [[ "${savings:-0}" -gt 0 ]] 2>/dev/null && echo "     Saves: ~$savings tokens"
    echo ""
    count=$((count + 1))
  done

  echo "  Matched: $count component(s)"

  # Show unmatched capabilities
  has_unmatched=false
  for cap in $NEEDED_CAPS; do
    matched=false
    for entry in "${sorted[@]}"; do
      IFS='|' read -r _ _ _ _ _ _ _ caps _ _ <<< "$entry"
      cap_lower=$(echo "$cap" | tr '[:upper:]' '[:lower:]')
      caps_lower=$(echo "$caps" | tr '[:upper:]' '[:lower:]')
      if [[ "$caps_lower" == *"$cap_lower"* ]]; then
        matched=true
        break
      fi
    done
    if ! $matched; then
      if ! $has_unmatched; then
        echo ""
        echo "  Unmatched needs (build candidates):"
        has_unmatched=true
      fi
      echo "    → $cap"
    fi
  done
fi
