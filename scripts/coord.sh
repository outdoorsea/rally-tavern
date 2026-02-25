#!/bin/bash
# Coordination overview

echo "🤝 Project Coordination"
echo ""

echo "ACTIVE CLAIMS:"
for f in coordination/claims/*.yaml; do
  [ -f "$f" ] || continue
  area=$(grep "^area:" "$f" | cut -d: -f2- | xargs)
  by=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  desc=$(grep "^description:" "$f" | cut -d: -f2- | xargs)
  echo "  👤 $by: $area"
  echo "     $desc"
done
[ ! "$(ls coordination/claims/*.yaml 2>/dev/null)" ] && echo "  (none)"

echo ""
echo "TODAY'S FOCUS:"
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
echo "  ./scripts/claim-area.sh <area> <description>  - Claim an area"
echo "  ./scripts/check-area.sh <file>                - Check if claimed"
echo "  ./scripts/today.sh <focus>                    - Post today's work"
