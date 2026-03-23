#!/bin/bash
# Initialize a new tavern (for forks)
#
# Non-interactive usage (for agents/CI):
#   RALLY_TAVERN_NAME="my-tavern" RALLY_OVERSEER_NAME="Alice" RALLY_OVERSEER_GITHUB="alice" ./scripts/init-tavern.sh
#   ./scripts/init-tavern.sh "my-tavern" "Alice" "alice"

echo "🍺 Initializing your Rally Tavern..."
echo ""

# Accept values from positional args, env vars, or interactive prompts
# Priority: positional arg > env var > interactive prompt

# Tavern name
if [ -n "$1" ]; then
  TAVERN_NAME="$1"
elif [ -n "$RALLY_TAVERN_NAME" ]; then
  TAVERN_NAME="$RALLY_TAVERN_NAME"
elif [ -t 0 ]; then
  read -p "Tavern name (default: rally-tavern): " TAVERN_NAME
fi
TAVERN_NAME="${TAVERN_NAME:-rally-tavern}"

# Overseer name
if [ -n "$2" ]; then
  YOUR_NAME="$2"
elif [ -n "$RALLY_OVERSEER_NAME" ]; then
  YOUR_NAME="$RALLY_OVERSEER_NAME"
elif [ -t 0 ]; then
  read -p "Your name: " YOUR_NAME
else
  echo "Error: overseer name required (set RALLY_OVERSEER_NAME or pass as arg 2)" >&2
  exit 1
fi

# GitHub username
if [ -n "$3" ]; then
  GITHUB_USER="$3"
elif [ -n "$RALLY_OVERSEER_GITHUB" ]; then
  GITHUB_USER="$RALLY_OVERSEER_GITHUB"
elif [ -t 0 ]; then
  read -p "Your GitHub username: " GITHUB_USER
else
  echo "Error: GitHub username required (set RALLY_OVERSEER_GITHUB or pass as arg 3)" >&2
  exit 1
fi

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
