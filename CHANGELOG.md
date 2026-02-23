# Changelog

## Unreleased

### Added
- **`agent-config-sync` extension plugin** — A gateway service that listens for PostgreSQL `LISTEN/NOTIFY` events on the `agent_config_changed` channel and writes `~/.openclaw/agents.json` with current agent model configurations. Uses atomic writes (temp + rename) and includes automatic reconnection with exponential backoff. Performs an initial sync on gateway startup. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))
- **`$include` directive for `agents.json`** — `openclaw.json` now includes `"$include": "./agents.json"` so that DB-synced agent configs are merged into the gateway config. Combined with `gateway.reload.mode = "hot"`, changes are picked up without a gateway restart. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))
- **Installer generates initial `agents.json`** — `agent-install.sh` now queries the `agents` table at install time to produce a ready-to-use `agents.json`, so the config is correct even before the gateway starts. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))
- **Installer sets `gateway.reload.mode`** — The installer ensures hot-reload is enabled (required for the config sync to work); if the mode is unset or `"off"`, it is set to `"hot"`. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))
- **`--no-restart` flag for `agent-install.sh`** — the installer now auto-restarts the OpenClaw gateway (if running) after install so plugin changes take effect immediately; pass `--no-restart` to skip this and restart manually later ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Shared `pg` dependency install** — `pg` is now installed to `~/.openclaw/node_modules/` (shared across extensions) instead of per-extension `node_modules/`. Old per-extension copies are cleaned up automatically during install ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Pre-flight `pg` dependency check in `agent_chat` plugin** — the plugin now verifies that the `pg` module is resolvable at registration time; if missing, it logs a clear error message with install instructions and bails out instead of crashing at runtime ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Post-registration self-validation in `agent_chat` plugin** — after registering, the plugin checks that both outbound (`sendText`) and inbound (`gateway/startAccount`) capabilities are present and logs the result, making misconfiguration immediately visible ([#149](https://github.com/nova-openclaw/nova-cognition/issues/149))
- **Prerequisite check in `agent-install.sh`** — installer now verifies that `~/.openclaw/lib/env-loader.sh` (from nova-memory) is present before proceeding; exits with a clear error message and install instructions if missing ([#127](https://github.com/nova-openclaw/nova-cognition/issues/127))

### Removed
- **`agent-config-db` pre-spawn/pre-run hook** — Replaced by the `agent-config-sync` extension plugin. The hook queried the database on every spawn and agent run, adding latency and risking failures; the new plugin syncs proactively via LISTEN/NOTIFY. The installer automatically removes the legacy hook directory and its config entry. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))

### Changed
- **`agent-install.sh` Part 4.5 rewritten** — The installer section formerly responsible for the `agent-config-db` hook now installs the `agent-config-sync` extension, builds its TypeScript, configures the plugin, sets up `$include` and hot-reload, and generates the initial `agents.json`. ([#146](https://github.com/nova-openclaw/nova-cognition/issues/146))
