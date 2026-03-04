#!/bin/bash
# Quick structural validation (no Xcode required)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

echo "Validating artifact structure..."

# Check template files exist
for f in \
  "{{project_name}}App.swift" \
  "Views/LoginView.swift" \
  "Views/SettingsView.swift" \
  "Views/HomeView.swift" \
  "Models/AuthManager.swift" \
  "Models/SettingsManager.swift"
do
  [ -f "$TEMPLATE_DIR/$f" ] || { echo "FAIL Missing template: $f"; exit 1; }
done
echo "OK Template files present"

# Check artifact.yaml exists
[ -f "$SCRIPT_DIR/../artifact.yaml" ] || { echo "FAIL Missing artifact.yaml"; exit 1; }
echo "OK artifact.yaml present"

# Check install skill exists
[ -f "$SCRIPT_DIR/../skills/install/SKILL.md" ] || { echo "FAIL Missing SKILL.md"; exit 1; }
echo "OK Install skill present"

echo ""
echo "OK Structure validation passed"
