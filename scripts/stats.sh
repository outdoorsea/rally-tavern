#!/bin/bash
# Rally Tavern Stats

ACTION="${1:-summary}"

case "$ACTION" in
  contributors)
    echo "📊 Top Contributors"
    echo ""
    echo "By commits:"
    git shortlog -sn --all | head -10
    echo ""
    echo "By knowledge items:"
    grep -rh "^contributed_by:" knowledge/ 2>/dev/null | cut -d: -f2 | sort | uniq -c | sort -rn | head -10
    ;;
    
  activity)
    echo "📊 Recent Activity"
    echo ""
    git log --oneline -20
    ;;
    
  topics)
    echo "📊 Popular Topics (by tag frequency)"
    echo ""
    grep -rh "^tags:" knowledge/ bounties/ 2>/dev/null | tr '[],' '\n' | grep -v "^tags:" | grep -v "^$" | sort | uniq -c | sort -rn | head -15
    ;;
    
  summary)
    echo "📊 Rally Tavern Summary"
    echo ""
    echo "Overseers: $(ls overseers/profiles/*.yaml 2>/dev/null | wc -l | xargs)"
    echo "Mayors: $(ls mayors/*.yaml 2>/dev/null | wc -l | xargs)"
    echo "Open bounties: $(ls bounties/open/*.yaml 2>/dev/null | wc -l | xargs)"
    echo "Done bounties: $(ls bounties/done/*.yaml 2>/dev/null | wc -l | xargs)"
    echo "Knowledge items: $(find knowledge -name "*.yaml" 2>/dev/null | wc -l | xargs)"
    echo "Post mortems: $(ls knowledge/postmortems/*.yaml 2>/dev/null | grep -v README | wc -l | xargs)"
    ;;
    
  *)
    echo "Usage: stats.sh [contributors|activity|topics|summary]"
    ;;
esac
