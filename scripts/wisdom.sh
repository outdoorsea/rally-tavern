#!/bin/bash
# Get tavern wisdom

WISDOM_FILE="tavern/wisdom.txt"
LINES=$(wc -l < "$WISDOM_FILE" | xargs)
RANDOM_LINE=$((RANDOM % LINES + 1))

echo "🍺 Tavern Wisdom:"
echo ""
sed -n "${RANDOM_LINE}p" "$WISDOM_FILE"
