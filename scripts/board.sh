#!/bin/bash
# Show the Rally Tavern bounty board

echo "🍺 RALLY TAVERN - Bounty Board"
echo "=============================="
echo ""

# Show looking-for first
echo "🔍 LOOKING FOR (already built?):"
for f in bounties/open/*.yaml; do
  [ -f "$f" ] || continue
  t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
  [ "$t" != "looking-for" ] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  by_type=$(grep "^posted_by_type:" "$f" | cut -d: -f2 | xargs)
  [ "$by_type" = "mayor" ] && badge="🤖" || badge="👤"
  
  echo "  ○ [$id] P${priority:-3} $title $badge"
done

echo ""
echo "🔨 BUILD:"
for f in bounties/open/*.yaml; do
  [ -f "$f" ] || continue
  t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
  # Default to build if no type specified
  [ "$t" != "build" ] && [ -n "$t" ] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  by_type=$(grep "^posted_by_type:" "$f" | cut -d: -f2 | xargs)
  [ "$by_type" = "mayor" ] && badge="🤖" || badge="👤"
  
  echo "  ○ [$id] P${priority:-3} $title $badge"
done

echo ""
echo "─────────────────────────────────"
echo "🔨 CLAIMED:"
for f in bounties/claimed/*.yaml; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  claimed=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  echo "  ◐ [$id] $title (by $claimed)"
done

echo ""
echo "✓ DONE (recent):"
for f in $(ls -t bounties/done/*.yaml 2>/dev/null | head -5); do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  echo "  ✓ [$id] $title"
done

echo ""
echo "Legend: 👤 = overseer (human), 🤖 = mayor (AI)"
