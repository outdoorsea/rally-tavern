#!/bin/bash
# Full coordination overview

echo "🤝 Project Coordination"
echo ""

# Overseer claims
echo "👤 OVERSEER CLAIMS:"
for f in coordination/claims/*.yaml; do
  [ -f "$f" ] || continue
  area=$(grep "^area:" "$f" | cut -d: -f2- | xargs)
  by=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  desc=$(grep "^description:" "$f" | cut -d: -f2- | xargs)
  echo "  👤 $by: $area"
  echo "     $desc"
done
HAS_CLAIMS=$(ls coordination/claims/*.yaml 2>/dev/null | grep -v gitkeep | head -1)
[ -z "$HAS_CLAIMS" ] && echo "  (none)"

echo ""

# Mayor intents
echo "🎩 MAYOR ACTIVITY:"
for f in coordination/mayors/*-intent.yaml; do
  [ -f "$f" ] || continue
  status=$(grep "^status:" "$f" | cut -d: -f2 | xargs)
  [ "$status" != "active" ] && continue
  
  mayor=$(grep "^mayor:" "$f" | cut -d: -f2 | xargs)
  intent=$(grep "^intent:" "$f" | cut -d: -f2- | xargs)
  scope=$(grep "^scope:" "$f" | cut -d: -f2- | xargs)
  echo "  🎩 $mayor: $intent"
  echo "     Scope: $scope"
done
HAS_MAYORS=$(ls coordination/mayors/*-intent.yaml 2>/dev/null | head -1)
[ -z "$HAS_MAYORS" ] && echo "  (none)"

echo ""

# Today's focus
echo "📅 TODAY'S FOCUS:"
DATE=$(date +%Y-%m-%d)
for f in coordination/today/*.yaml; do
  [ -f "$f" ] || continue
  updated=$(grep "^updated:" "$f" | cut -d: -f2- | xargs)
  [[ "$updated" == "$DATE"* ]] || continue
  
  who=$(grep "^overseer:" "$f" | cut -d: -f2 | xargs)
  focus=$(grep "^focus:" "$f" | cut -d: -f2- | xargs)
  echo "  👤 $who: $focus"
done

echo ""
echo "Commands:"
echo "  👤 Overseer: claim-area.sh, check-area.sh, today.sh, release-area.sh"
echo "  🎩 Mayor:    mayor-intent.sh, mayor-check.sh, mayor-done.sh"
