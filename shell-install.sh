#!/bin/bash
# shell-install.sh - Interactive setup for humans
# Prompts for API keys, saves to OpenClaw provider config, then runs agent-install.sh

set -e

OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "═══════════════════════════════════════════"
echo "  nova-cognition interactive setup"
echo "═══════════════════════════════════════════"
echo ""

# Check jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is required but not installed${NC}"
    echo "   Install: sudo apt install jq"
    exit 1
fi

# Read existing key if present
EXISTING_KEY=""
if [ -f "$OPENCLAW_CONFIG" ]; then
    EXISTING_KEY=$(jq -r '.models.providers.anthropic.apiKey // empty' "$OPENCLAW_CONFIG" 2>/dev/null)
fi

if [ -n "$EXISTING_KEY" ]; then
    echo -e "${GREEN}✅${NC} Anthropic API key already configured: ${EXISTING_KEY:0:8}..."
    echo ""
    read -p "Replace existing key? [y/N] " replace_key
    if [[ ! "$replace_key" =~ ^[Yy] ]]; then
        echo "Keeping existing key."
        echo ""
        exec "$(dirname "$0")/agent-install.sh" "$@"
    fi
fi

echo "Anthropic API key is required for nova-cognition (Claude)."
echo "Get your API key from: https://console.anthropic.com/"
echo ""
read -p "Enter your Anthropic API key (or press Enter to cancel): " user_api_key

if [ -z "$user_api_key" ]; then
    echo -e "${RED}❌ Cancelled - Anthropic API key is required${NC}"
    exit 1
fi

# Ensure config file exists
if [ ! -f "$OPENCLAW_CONFIG" ]; then
    echo "Creating config file: $OPENCLAW_CONFIG"
    mkdir -p "$(dirname "$OPENCLAW_CONFIG")"
    echo '{}' > "$OPENCLAW_CONFIG"
fi

# Backup before modification
cp "$OPENCLAW_CONFIG" "$OPENCLAW_CONFIG.backup-$(date +%s)"

# Save key to models.providers.anthropic.apiKey (preserve existing config)
TMP_CONFIG=$(mktemp)
jq --arg key "$user_api_key" \
    '.models.providers.anthropic.apiKey = $key' \
    "$OPENCLAW_CONFIG" > "$TMP_CONFIG"
mv "$TMP_CONFIG" "$OPENCLAW_CONFIG"

echo -e "${GREEN}✅${NC} Anthropic API key saved to provider config"
echo ""

# Run agent installer
exec "$(dirname "$0")/agent-install.sh" "$@"
