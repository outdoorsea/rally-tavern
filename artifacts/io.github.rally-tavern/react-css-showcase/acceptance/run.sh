#!/usr/bin/env bash
# Acceptance test: verify the ShowcasePage component structure is valid
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../templates"

echo "=== react-css-showcase acceptance ==="

# Check required files exist
for f in ShowcasePage.tsx ShowcasePage.css index.ts; do
  if [ ! -f "$TEMPLATES/$f" ]; then
    echo "FAIL: Missing template file: $f"
    exit 1
  fi
  echo "OK: $TEMPLATES/$f exists"
done

# Check component exports the expected function
if ! grep -q "export default function ShowcasePage" "$TEMPLATES/ShowcasePage.tsx"; then
  echo "FAIL: ShowcasePage.tsx missing default export"
  exit 1
fi
echo "OK: ShowcasePage default export found"

# Check it reads CSS custom properties
if ! grep -q "getCustomProperties" "$TEMPLATES/ShowcasePage.tsx"; then
  echo "FAIL: ShowcasePage.tsx missing getCustomProperties"
  exit 1
fi
echo "OK: getCustomProperties function found"

# Check key render types exist
for renderer in ColorSwatch SizeToken ShadowToken RadiusToken TimingToken ZIndexToken; do
  if ! grep -q "function $renderer" "$TEMPLATES/ShowcasePage.tsx"; then
    echo "FAIL: Missing renderer: $renderer"
    exit 1
  fi
  echo "OK: $renderer renderer found"
done

# Check CSS file has required classes
for cls in showcase-page showcase-header showcase-section showcase-color__swatch showcase-size__bar; do
  if ! grep -q "\.$cls" "$TEMPLATES/ShowcasePage.css"; then
    echo "FAIL: Missing CSS class: .$cls"
    exit 1
  fi
  echo "OK: .$cls class found"
done

echo ""
echo "=== All acceptance checks passed ==="
