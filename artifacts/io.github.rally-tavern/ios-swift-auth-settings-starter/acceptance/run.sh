#!/bin/bash
# Acceptance test for ios-swift-auth-settings-starter
set -euo pipefail

echo "Running acceptance tests..."

# Check required files exist
for f in \
  "{{project_name}}App.swift" \
  "Views/LoginView.swift" \
  "Views/SettingsView.swift" \
  "Views/HomeView.swift" \
  "Models/AuthManager.swift" \
  "Models/SettingsManager.swift" \
  "{{project_name}}.xcodeproj/project.pbxproj"
do
  [ -f "$f" ] || { echo "FAIL Missing: $f"; exit 1; }
done
echo "OK Required files present"

# Build the project (requires Xcode)
if command -v xcodebuild &>/dev/null; then
  xcodebuild build \
    -scheme "{{project_name}}" \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -quiet 2>&1
  echo "OK Project builds"

  # Run tests
  xcodebuild test \
    -scheme "{{project_name}}" \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -quiet 2>&1
  echo "OK All tests passed"
else
  echo "SKIP xcodebuild not available (not on macOS with Xcode)"
fi

echo ""
echo "OK Acceptance tests complete"
