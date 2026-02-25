#!/bin/bash
# Initialize a new tavern (for forks)

echo "🍺 Initializing your Rally Tavern..."
echo ""

# Get info
read -p "Tavern name (default: rally-tavern): " TAVERN_NAME
TAVERN_NAME="${TAVERN_NAME:-rally-tavern}"

read -p "Your name: " YOUR_NAME
read -p "Your GitHub username: " GITHUB_USER

# Register as first overseer
./scripts/overseer.sh register "$YOUR_NAME" "$GITHUB_USER"

# Make them a sheriff
mkdir -p tavern
cat > tavern/sheriffs.yaml << EOF
sheriffs:
  - name: $(echo "$YOUR_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    appointed: $(date +%Y-%m-%d)
    appointed_by: tavern-founder
EOF

# Clean example content
rm -f bounties/open/bounty-example*.yaml
rm -f knowledge/postmortems/2026-02-25-*.yaml

echo ""
echo "✅ Your tavern is ready!"
echo ""
echo "Next steps:"
echo "  1. Edit README.md to describe your tavern"
echo "  2. Invite collaborators"
echo "  3. Post your first bounty: ./scripts/post.sh 'First bounty'"
echo "  4. Share some knowledge: ./scripts/knowledge.sh add"
echo ""
echo "🍺 Welcome to $TAVERN_NAME!"
