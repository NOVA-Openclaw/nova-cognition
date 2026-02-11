#!/bin/bash
# human-install.sh - Environment wrapper for humans
# Sets up shell environment before calling agent-install.sh

# Detect/export environment
export PGUSER="${PGUSER:-$(whoami)}"
export POSTGRES_DB="${POSTGRES_DB:-nova_memory}"
export OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace-claude-code}"

echo "Environment configured:"
echo "  PGUSER=$PGUSER"
echo "  POSTGRES_DB=$POSTGRES_DB"
echo "  OPENCLAW_WORKSPACE=$OPENCLAW_WORKSPACE"
echo ""

# Call the agent installer
exec "$(dirname "$0")/agent-install.sh" "$@"
