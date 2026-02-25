#!/bin/bash
# Celebrate a win!

WIN="$1"
CHEERS="${2:-1}"

WHO=$(git config user.name)
DATE=$(date +%Y-%m-%d)

# Convert cheers to beers
case "$CHEERS" in
  1|"1 beer") BEERS="🍺";;
  2|"2 beers") BEERS="🍺🍺";;
  3|"3 beers") BEERS="🍺🍺🍺";;
  *) BEERS="🍺";;
esac

echo ""
echo "🎉 ════════════════════════════════════════════ 🎉"
echo ""
echo "   $WHO just achieved:"
echo ""
echo "   ✨ $WIN ✨"
echo ""
echo "   The tavern raises their glasses: $BEERS"
echo ""
echo "🎉 ════════════════════════════════════════════ 🎉"
echo ""

# Log to hall of fame
mkdir -p tavern/wins
echo "- who: $WHO" >> tavern/wins/${DATE}.yaml
echo "  what: $WIN" >> tavern/wins/${DATE}.yaml
echo "  date: $DATE" >> tavern/wins/${DATE}.yaml
echo "  cheers: $BEERS" >> tavern/wins/${DATE}.yaml
echo "" >> tavern/wins/${DATE}.yaml

git add tavern/wins/
echo "Added to the Hall of Fame! 🏆"
