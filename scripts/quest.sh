#!/bin/bash
# Get a random quest from the tavern

QUESTS=(
  "🗡️  Find and share a useful repo you discovered this week"
  "📜 Write a post mortem about something that went wrong recently"
  "🤝 Answer someone's help request"
  "📚 Document a best practice you use but haven't shared"
  "🔍 Look for a 'looking-for' bounty you can answer"
  "🍺 Give someone's knowledge a verification"
  "🧹 Find outdated knowledge and mark it deprecated"
  "🎓 Share a starter template for a framework you know"
  "💡 Post today's focus to help others coordinate"
  "🏆 Celebrate a recent win in the Hall of Fame"
)

RANDOM_INDEX=$((RANDOM % ${#QUESTS[@]}))

echo "⚔️  TODAY'S QUEST:"
echo ""
echo "   ${QUESTS[$RANDOM_INDEX]}"
echo ""
echo "   Complete the quest and earn honor at the Tavern!"
