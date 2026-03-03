#!/bin/bash
# Rally - Agent-first planning, skill orchestration, and component reuse
# Usage: rally <command> [args...]
#
# Commands:
#   init [path]           Create project-profile.yaml interactively
#   validate <path>       Validate a project-profile.yaml
#   skill <action>        Skill runner (run, list, show, validate)
#   defaults <action>     View/apply stack defaults
#   help                  Show this help

source "$(dirname "$0")/../lib/common.sh"

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)
    exec "$TAVERN_ROOT/scripts/rally-init.sh" "$@"
    ;;
  validate)
    exec "$TAVERN_ROOT/scripts/rally-validate-profile.sh" "$@"
    ;;
  skill)
    exec "$TAVERN_ROOT/scripts/rally-skill.sh" "$@"
    ;;
  defaults)
    exec "$TAVERN_ROOT/scripts/rally-defaults.sh" "$@"
    ;;
  help|--help|-h)
    echo "Rally - Agent-first planning and skill orchestration"
    echo ""
    echo "Usage: rally <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  init [path]           Create project-profile.yaml interactively"
    echo "  validate <path>       Validate a project-profile.yaml"
    echo "  skill <action>        Skill runner (run, list, show, validate)"
    echo "  defaults <action>     View/apply stack defaults"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  rally init                          # Create profile in current dir"
    echo "  rally init ./myproject/profile.yaml # Create at specific path"
    echo "  rally validate project-profile.yaml # Validate existing profile"
    echo "  rally skill list                    # List available skills"
    echo "  rally skill run pm --profile p.yaml # Run a skill"
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    log_info "Run 'rally help' for usage"
    exit 1
    ;;
esac
