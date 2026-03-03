#!/bin/bash
# Enter the Rally Tavern

./scripts/banner.sh
echo ""
./scripts/wisdom.sh
echo ""
echo "─────────────────────────────────────────────────────"
echo ""

# Quick stats
OPEN=$(ls bounties/open/*.yaml 2>/dev/null | wc -l | xargs)
MAYORS=$(ls coordination/mayors/*-intent.yaml 2>/dev/null | grep -v gitkeep | wc -l | xargs)
echo "📊 Today at the Tavern:"
echo "   $OPEN open bounties waiting"
echo "   $MAYORS Mayors currently working"
echo ""

# Random quest
echo "─────────────────────────────────────────────────────"
./scripts/quest.sh
