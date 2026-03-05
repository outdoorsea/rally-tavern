#!/bin/bash
# Rally - Agent-first planning, skill orchestration, and component reuse
# Usage: rally <command> [args...]
#
# Commands:
#   init [path]           Create project-profile.yaml interactively
#   validate <path>       Validate a project-profile.yaml
#   skill <action>        Skill runner (run, list, show, validate)
#   plan <profile>        Generate build card from project profile
#   defaults <action>     View/apply stack defaults
#   component <action>    Component management (validate, search, resolve, list)
#   resolve <profile>     Resolve components for a project profile
#   receipt <action>      Build receipt capture and history
#   feedback <action>     Feedback loop analysis from receipts
#   tasks <action>        Task generation from build cards
#   dispatch <build-card> Dispatch tasks to Mayor convoy system
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
  plan)
    exec "$TAVERN_ROOT/scripts/rally-plan.sh" "$@"
    ;;
  defaults)
    exec "$TAVERN_ROOT/scripts/rally-defaults.sh" "$@"
    ;;
  component)
    exec "$TAVERN_ROOT/scripts/rally-component.sh" "$@"
    ;;
  resolve)
    exec "$TAVERN_ROOT/scripts/component-resolve.sh" "$@"
    ;;
  receipt)
    exec "$TAVERN_ROOT/scripts/rally-receipt.sh" "$@"
    ;;
  feedback)
    exec "$TAVERN_ROOT/scripts/rally-feedback.sh" "$@"
    ;;
  tasks)
    exec "$TAVERN_ROOT/scripts/rally-tasks.sh" "$@"
    ;;
  dispatch)
    exec "$TAVERN_ROOT/scripts/rally-dispatch.sh" "$@"
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
    echo "  plan <profile>        Generate build card from project profile"
    echo "  defaults <action>     View/apply stack defaults"
    echo "  component <action>    Component management (validate, new, search, list, resolve)"
    echo "  resolve <profile>     Resolve components for a project profile"
    echo "  receipt <action>      Build receipt capture and history"
    echo "  feedback <action>     Feedback loop analysis from receipts"
    echo "  tasks <action>        Task generation from build cards"
    echo "  dispatch <build-card> Dispatch tasks to Mayor convoy system"
    echo "  help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  rally init                          # Create profile in current dir"
    echo "  rally init ./myproject/profile.yaml # Create at specific path"
    echo "  rally validate project-profile.yaml # Validate existing profile"
    echo "  rally skill list                    # List available skills"
    echo "  rally skill run pm --profile p.yaml # Run a skill"
    echo "  rally plan project-profile.yaml     # Generate build card"
    echo "  rally component validate ./my-comp  # Validate component manifest"
    echo "  rally component list --capability user-authentication"
    echo "  rally resolve project-profile.yaml  # Find matching components"
    echo "  rally receipt generate              # Capture build metrics"
    echo "  rally feedback analyze              # Analyze build patterns"
    echo "  rally tasks generate build-card.yaml  # Generate tasks from build card"
    echo "  rally dispatch build-card.yaml      # Dispatch tasks to Mayor"
    ;;
  *)
    log_error "Unknown command: $COMMAND"
    log_info "Run 'rally help' for usage"
    exit 1
    ;;
esac
