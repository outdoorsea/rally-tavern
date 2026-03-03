#!/bin/bash
# Rally Defaults — View and apply opinionated stack defaults
#
# Usage:
#   rally-defaults.sh list                    List available stacks
#   rally-defaults.sh show <stack>            Show stack details
#   rally-defaults.sh apply <stack> <profile> Apply stack to project profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULTS_DIR="$(cd "$SCRIPT_DIR/../defaults" && pwd)"
STACKS_DIR="$DEFAULTS_DIR/stacks"

ACTION="${1:-}"
shift 2>/dev/null || true

rally_defaults_list() {
  echo "📦 Available Stack Defaults"
  echo ""
  for f in "$STACKS_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    name=$(grep "^name:" "$f" | head -1 | cut -d: -f2- | xargs)
    display=$(grep "^display_name:" "$f" | head -1 | cut -d: -f2- | xargs)
    echo "  $name"
    echo "    $display"
    echo ""
  done
  echo "Security controls: defaults/security-controls.yaml"
}

rally_defaults_show() {
  local stack="$1"
  local stack_file="$STACKS_DIR/${stack}.yaml"

  if [ ! -f "$stack_file" ]; then
    echo "Error: Stack '$stack' not found."
    echo "Available stacks:"
    for f in "$STACKS_DIR"/*.yaml; do
      [ -f "$f" ] || continue
      echo "  $(basename "$f" .yaml)"
    done
    exit 1
  fi

  cat "$stack_file"
}

rally_defaults_apply() {
  local stack="$1"
  local profile="${2:-}"
  local stack_file="$STACKS_DIR/${stack}.yaml"

  if [ ! -f "$stack_file" ]; then
    echo "Error: Stack '$stack' not found."
    exit 1
  fi

  if [ -z "$profile" ]; then
    echo "Error: Profile path required."
    echo "Usage: rally-defaults.sh apply <stack> <project-profile.yaml>"
    exit 1
  fi

  if [ ! -f "$profile" ]; then
    echo "Error: Profile '$profile' not found."
    exit 1
  fi

  # Extract key values from stack
  local framework platform lang
  framework=$(grep "^  name:" "$stack_file" | head -1 | cut -d: -f2- | xargs)
  platform=$(grep "^platform:" "$stack_file" | head -1 | cut -d: -f2- | xargs)
  lang=$(grep "^  name:" "$stack_file" | head -1 | cut -d: -f2- | xargs)

  echo "✓ Stack defaults for '$stack':"
  echo "  Platform: $platform"
  echo "  Framework: $framework"
  echo ""
  echo "Stack file: $stack_file"
  echo "Profile: $profile"
  echo ""
  echo "To integrate, reference this stack in your project profile:"
  echo "  stack: $stack"
  echo ""
  echo "The planning skills will read stack defaults when generating build cards."
}

case "$ACTION" in
  list)
    rally_defaults_list
    ;;
  show)
    STACK="${1:-}"
    if [ -z "$STACK" ]; then
      echo "Usage: rally-defaults.sh show <stack-name>"
      echo "Run 'rally-defaults.sh list' to see available stacks."
      exit 1
    fi
    rally_defaults_show "$STACK"
    ;;
  apply)
    STACK="${1:-}"
    PROFILE="${2:-}"
    if [ -z "$STACK" ]; then
      echo "Usage: rally-defaults.sh apply <stack-name> <project-profile.yaml>"
      exit 1
    fi
    rally_defaults_apply "$STACK" "$PROFILE"
    ;;
  *)
    echo "Usage: rally-defaults.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                     List available stack defaults"
    echo "  show <stack>             Show full stack definition"
    echo "  apply <stack> <profile>  Apply stack to a project profile"
    echo ""
    echo "Available stacks:"
    for f in "$STACKS_DIR"/*.yaml; do
      [ -f "$f" ] || continue
      echo "  $(basename "$f" .yaml)"
    done
    ;;
esac
