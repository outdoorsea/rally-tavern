#!/bin/bash
# Show the Rally Tavern bounty board

echo "🍺 RALLY TAVERN - Bounty Board"
echo "=============================="
echo ""

# Quick stats
OPEN=$(ls bounties/open/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
CLAIMED=$(ls bounties/claimed/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
echo "📊 Open: $OPEN | In Progress: $CLAIMED"
echo ""

# Show looking-for first
echo "🔍 LOOKING FOR (already built?):"
for f in bounties/open/*.yaml; do
  [ -f "$f" ] || continue
  [[ "$f" == *".gitkeep"* ]] && continue
  t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
  [ "$t" != "looking-for" ] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  by_type=$(grep "^posted_by_type:" "$f" | cut -d: -f2 | xargs)
  
  [ "$by_type" = "mayor" ] && badge="🎩" || badge="👤"
  
  echo "  ○ [$id] P${priority:-3} $title $badge"
done

echo ""
echo "🔨 BUILD (Mayors: claim with mayor-claim.sh):"
for f in bounties/open/*.yaml; do
  [ -f "$f" ] || continue
  [[ "$f" == *".gitkeep"* ]] && continue
  t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
  [ "$t" != "build" ] && [ -n "$t" ] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
  by_type=$(grep "^posted_by_type:" "$f" | cut -d: -f2 | xargs)
  tags=$(grep "^tags:" "$f" | cut -d: -f2- | tr -d '[]' | xargs)
  
  [ "$by_type" = "mayor" ] && badge="🎩" || badge="👤"
  
  echo "  ○ [$id] P${priority:-3} $title $badge"
  [ -n "$tags" ] && echo "     Tags: $tags"
done

echo ""
echo "─────────────────────────────────────────────────────"
echo "🎩 IN PROGRESS (Mayor claimed):"
for f in bounties/claimed/*.yaml; do
  [ -f "$f" ] || continue
  [[ "$f" == *".gitkeep"* ]] && continue
  
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  claimed=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  ctype=$(grep "^claimed_by_type:" "$f" | cut -d: -f2 | xargs)
  
  [ "$ctype" = "mayor" ] && icon="🎩" || icon="👤"
  
  echo "  ◐ [$id] $title"
  echo "     $icon $claimed"
done

echo ""
echo "✓ DONE (recent):"
for f in $(ls -t bounties/done/*.yaml 2>/dev/null | head -3); do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  echo "  ✓ [$id] $title"
done

echo ""
echo "─────────────────────────────────────────────────────"
echo "🎩 Mayor commands:"
echo "   ./scripts/bounties-json.sh        # List as JSON"
echo "   ./scripts/mayor-claim.sh <m> <b>  # Claim bounty"
echo "   ./scripts/mayor-complete.sh <m> <b> --summary '...'  # Complete"
echo ""
echo "Legend: 👤 = Overseer  🎩 = Mayor"
