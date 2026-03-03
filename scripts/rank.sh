#!/bin/bash
# Check your tavern rank

WHO="${1:-$(git config user.name)}"

echo "🏆 Tavern Rank for: $WHO"
echo ""

# Count contributions
COMMITS=$(git log --author="$WHO" --oneline 2>/dev/null | wc -l | xargs)
KNOWLEDGE=$(grep -rl "contributed_by:.*$WHO" knowledge/ 2>/dev/null | wc -l | xargs)
BOUNTIES=$(grep -rl "posted_by:.*$WHO" bounties/ 2>/dev/null | wc -l | xargs)
POSTMORTEMS=$(grep -rl "contributed_by:.*$WHO" knowledge/postmortems/ 2>/dev/null | wc -l | xargs)

TOTAL=$((COMMITS + KNOWLEDGE + BOUNTIES))

echo "📊 Stats:"
echo "   Commits: $COMMITS"
echo "   Knowledge: $KNOWLEDGE"
echo "   Bounties: $BOUNTIES"
echo "   Post Mortems: $POSTMORTEMS"
echo "   Total: $TOTAL"
echo ""

# Determine rank
if [ $TOTAL -ge 50 ]; then
  RANK="👑 Tavern Master"
elif [ $TOTAL -ge 30 ]; then
  RANK="🏠 Innkeeper"
elif [ $TOTAL -ge 15 ]; then
  RANK="⭐ Trusted"
elif [ $TOTAL -ge 5 ]; then
  RANK="🍺 Regular"
else
  RANK="🚪 Newcomer"
fi

echo "🎖️  Rank: $RANK"

# Special titles
TITLES=""
[ $KNOWLEDGE -ge 10 ] && TITLES="$TITLES The Wise,"
[ $POSTMORTEMS -ge 10 ] && TITLES="$TITLES The Storyteller,"

if [ -n "$TITLES" ]; then
  echo "📜 Titles: ${TITLES%,}"
fi
