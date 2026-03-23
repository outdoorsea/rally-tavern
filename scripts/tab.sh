#!/bin/bash
# Who's working on what

echo "🍺 THE RALLY TAB"
echo "=========="

for f in bounties/claimed/*.yaml; do
  [ -f "$f" ] || continue
  id=$(basename "$f" .yaml)
  title=$(grep "^title:" "$f" | cut -d: -f2- | xargs)
  claimed=$(grep "^claimed_by:" "$f" | cut -d: -f2 | xargs)
  since=$(grep "^claimed_at:" "$f" | cut -d: -f2- | xargs)
  echo "  $claimed → $title"
  echo "           since ${since:0:10}"
done

[ ! "$(ls bounties/claimed/*.yaml 2>/dev/null)" ] && echo "  (empty - no one's working)"
