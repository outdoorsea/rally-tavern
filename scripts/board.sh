#!/bin/bash
# Show the Rally Tavern bounty board

echo "🍺 RALLY TAVERN - Bounty Board"
echo "=============================="
echo ""

# Group by type
for TYPE in looking-for build explain fix collab; do
  case "$TYPE" in
    looking-for) ICON="🔍"; LABEL="LOOKING FOR (already built?)";;
    build) ICON="🔨"; LABEL="BUILD";;
    explain) ICON="📖"; LABEL="EXPLAIN";;
    fix) ICON="🔧"; LABEL="FIX";;
    collab) ICON="🤝"; LABEL="COLLABORATION";;
  esac
  
  # Check if any bounties of this type exist
  HAS_TYPE=0
  for f in bounties/open/*.yaml 2>/dev/null; do
    [ -f "$f" ] || continue
    t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
    [ "$t" = "$TYPE" ] && HAS_TYPE=1 && break
  done
  
  [ $HAS_TYPE -eq 0 ] && continue
  
  echo "$ICON $LABEL:"
  for f in bounties/open/*.yaml 2>/dev/null; do
    [ -f "$f" ] || continue
    t=$(grep "^type:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
    [ "$t" != "$TYPE" ] && continue
    
    id=$(basename "$f" .yaml)
    title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
    priority=$(grep "^priority:" "$f" | cut -d: -f2 | xargs)
    by_type=$(grep "^posted_by_type:" "$f" | cut -d: -f2 | xargs)
    
    # Show if from mayor or overseer
    [ "$by_type" = "mayor" ] && badge="🤖" || badge="👤"
    
    echo "  ○ [$id] P${priority:-3} $title $badge"
  done
  echo ""
done

echo "─────────────────────────────────"
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

echo ""
echo "Legend: 👤 = overseer (human), 🤖 = mayor (AI)"
