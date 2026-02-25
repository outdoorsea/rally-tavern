#!/bin/bash
# Check tavern health

echo "🏥 Tavern Health Check"
echo ""

# Activity
RECENT_COMMITS=$(git log --since="7 days ago" --oneline | wc -l | xargs)
echo "📊 Activity (last 7 days):"
echo "   Commits: $RECENT_COMMITS"

if [ $RECENT_COMMITS -gt 10 ]; then
  echo "   Status: 🟢 Active"
elif [ $RECENT_COMMITS -gt 0 ]; then
  echo "   Status: 🟡 Moderate"
else
  echo "   Status: 🔴 Inactive"
fi

echo ""

# Bounties
OPEN=$(ls bounties/open/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
CLAIMED=$(ls bounties/claimed/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
DONE=$(ls bounties/done/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)

echo "📋 Bounties:"
echo "   Open: $OPEN | Claimed: $CLAIMED | Done: $DONE"

if [ $OPEN -gt 0 ] && [ $CLAIMED -gt 0 ]; then
  echo "   Status: 🟢 Healthy flow"
elif [ $OPEN -gt 5 ] && [ $CLAIMED -eq 0 ]; then
  echo "   Status: 🟡 Bounties not getting claimed"
else
  echo "   Status: 🟢 OK"
fi

echo ""

# Knowledge
KNOWLEDGE=$(find knowledge -name "*.yaml" 2>/dev/null | grep -v gitkeep | wc -l | xargs)
VERIFIED=$(grep -rl "verified_by: \[" knowledge/ 2>/dev/null | wc -l | xargs)

echo "📚 Knowledge:"
echo "   Total: $KNOWLEDGE | Verified: $VERIFIED"

if [ $KNOWLEDGE -gt 0 ]; then
  PCT=$((VERIFIED * 100 / KNOWLEDGE))
  echo "   Verification rate: ${PCT}%"
  [ $PCT -gt 50 ] && echo "   Status: 🟢 Good" || echo "   Status: 🟡 Needs more verification"
fi

echo ""

# Jail
JAILED=$(ls tavern/jail/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
echo "🚨 Security:"
echo "   Flagged items: $JAILED"
[ $JAILED -eq 0 ] && echo "   Status: 🟢 All clear" || echo "   Status: 🟡 Items need review"

echo ""

# Coordination
CLAIMS=$(ls coordination/claims/*.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
MAYOR_ACTIVE=$(ls coordination/mayors/*-intent.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)

echo "🤝 Coordination:"
echo "   Active claims: $CLAIMS | Mayor intents: $MAYOR_ACTIVE"

echo ""
echo "─────────────────────────────────────────────────────"
echo "Run ./scripts/stats.sh for detailed statistics"
