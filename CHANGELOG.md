# Changelog

## Unreleased

### Added
- **`--no-restart` flag for `agent-install.sh`** — the installer now auto-restarts the OpenClaw gateway (if running) after install so plugin changes take effect immediately; pass `--no-restart` to skip this and restart manually later ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Shared `pg` dependency install** — `pg` is now installed to `~/.openclaw/node_modules/` (shared across extensions) instead of per-extension `node_modules/`. Old per-extension copies are cleaned up automatically during install ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Pre-flight `pg` dependency check in `agent_chat` plugin** — the plugin now verifies that the `pg` module is resolvable at registration time; if missing, it logs a clear error message with install instructions and bails out instead of crashing at runtime ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Post-registration self-validation in `agent_chat` plugin** — after registering, the plugin checks that both outbound (`sendText`) and inbound (`gateway/startAccount`) capabilities are present and logs the result, making misconfiguration immediately visible ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Prerequisite check in `agent-install.sh`** — installer now verifies that `~/.openclaw/lib/env-loader.sh` (from nova-memory) is present before proceeding; exits with a clear error message and install instructions if missing ([#127](https://github.com/nova-openclaw/nova-cognition/issues/127))
