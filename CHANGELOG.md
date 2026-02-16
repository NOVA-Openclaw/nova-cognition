# Changelog

## Unreleased

### Changed — Provider Config Keys (#122)

- **agent-install.sh**: Reads Anthropic API key from `models.providers.anthropic.apiKey` in `~/.openclaw/openclaw.json` instead of environment variables or interactive prompts. Requires `jq`. Exits with clear error pointing to `shell-install.sh` if key is missing.
- **shell-install.sh**: Rewritten as interactive setup script. Prompts for Anthropic API key, saves to provider config, then delegates to `agent-install.sh`.
- Installer flow is now split: `shell-install.sh` for humans, `agent-install.sh` for agents.
