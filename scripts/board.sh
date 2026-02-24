#!/bin/bash
# Show the bounty board

echo "🍺 THE PUB - Bounty Board"
echo "========================="
echo ""

echo "📋 OPEN BOUNTIES:"
for f in bounties/open/*.yaml 2>/dev/null; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  echo "  ○ [$id] P${priority:-3} - $title"
done

echo ""
echo "🔨 CLAIMED:"
for f in bounties/claimed/*.yaml 2>/dev/null; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  claimed=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  echo "  ◐ [$id] $title (by $claimed)"
done

echo ""
echo "✓ DONE (recent):"
ls -t bounties/done/*.yaml 2>/dev/null | head -5 | while read f; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  echo "  ✓ [$id] $title"
done
