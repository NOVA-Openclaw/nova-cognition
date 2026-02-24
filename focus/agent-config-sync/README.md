# agent-config-sync

An OpenClaw extension plugin that keeps `~/.openclaw/agents.json` in sync with your PostgreSQL database — automatically and in real time.

It watches two DB tables:

- **`agents`** — agent definitions (model, fallback models, allowed subagents)
- **`agent_system_config`** — system-wide defaults (e.g. `maxSpawnDepth`)

When either table changes, the plugin receives a PostgreSQL `NOTIFY` event, rebuilds `agents.json`, writes it atomically, and signals the gateway to reload (`SIGUSR1`).

---

## What It Does

```
DB change
  └─► trigger fires pg_notify('agent_config_changed')
        └─► plugin receives notification (LISTEN)
              └─► queries agents + agent_system_config
                    └─► builds agents.json
                          └─► atomic write (tmp + rename)
                                └─► SIGUSR1 → gateway hot-reload
```

On startup the plugin performs an **initial sync** so `agents.json` is always fresh, even before any DB change occurs.

---

## agent_system_config Table

This table stores system-wide configuration that applies as defaults for all agents.

### Schema

```sql
CREATE TABLE agent_system_config (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    value_type TEXT NOT NULL DEFAULT 'text',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

| Column       | Type        | Description                                       |
|--------------|-------------|---------------------------------------------------|
| `key`        | TEXT (PK)   | Config key name (see supported keys below)        |
| `value`      | TEXT        | Config value, always stored as text               |
| `value_type` | TEXT        | Type hint used for casting: `'integer'`, `'text'` |
| `created_at` | TIMESTAMPTZ | Row creation timestamp                            |
| `updated_at` | TIMESTAMPTZ | Last update timestamp                             |

### Supported Keys

| DB key                     | JSON path                              | value_type | Valid range | Notes                                |
|----------------------------|----------------------------------------|------------|-------------|--------------------------------------|
| `max_spawn_depth`          | `agents.defaults.subagents.maxSpawnDepth` | `integer`  | 1–5         | Maximum depth for nested subagent chains. Clamped to 1–5 by the plugin. |
| `max_concurrent_subagents` | `agents.defaults.subagents.maxConcurrent` | `integer`  | —           | **Future** — not yet mapped. Reserved for forward compatibility. |

Unknown keys are silently ignored (whitelist approach). Invalid values (type mismatches, non-integer strings) are logged as warnings and skipped — the plugin never crashes on bad data.

### Example

```sql
-- Set max spawn depth to 3
UPDATE agent_system_config SET value = '3' WHERE key = 'max_spawn_depth';
```

This automatically propagates to `agents.json`:

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "maxSpawnDepth": 3
      }
    }
  }
}
```

---

## Configuration Layering

Config values flow through layers, with **DB always winning** over file defaults:

```
1. Installer default (openclaw.json)          ← lowest priority
2. Plugin reads DB (agent_system_config)
3. Plugin writes agents.json
4. openclaw.json $include deep-merges agents.json  ← DB values win
```

This means:
- You can set baseline defaults in `openclaw.json` (e.g. `maxConcurrent: 5`)
- The sync plugin overlays DB values on top
- DB values always take precedence after the merge

### Example: $include deep merge

`openclaw.json`:
```json
{
  "$include": "./agents.json",
  "agents": {
    "defaults": {
      "subagents": {
        "maxConcurrent": 5
      }
    }
  }
}
```

`agent_system_config` DB: `max_spawn_depth = 4`

Result after merge:
```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "maxConcurrent": 5,
        "maxSpawnDepth": 4
      }
    }
  }
}
```

---

## Notification Flow

Changes in `agent_system_config` (INSERT / UPDATE / DELETE) trigger real-time syncs via PostgreSQL's `LISTEN/NOTIFY`:

```
DB UPDATE agent_system_config SET value = '3' WHERE key = 'max_spawn_depth'
  │
  └─► trigger: notify_system_config_changed()
        │
        └─► pg_notify('agent_config_changed', '{"source":"agent_system_config","key":"max_spawn_depth","operation":"UPDATE"}')
              │
              └─► plugin receives notification
                    │
                    └─► syncAgentsConfig() — re-queries both tables
                          │
                          └─► atomic write to agents.json
                                │
                                └─► process.kill(process.pid, 'SIGUSR1')
                                      │
                                      └─► gateway hot-reload
```

The same `agent_config_changed` channel is shared with the `agents` table trigger, so any change to either table triggers a full re-sync.

### SQL Trigger

Installed by `agent-install.sh` and `scripts/migrations/163-system-config-trigger.sql`:

```sql
CREATE OR REPLACE FUNCTION notify_system_config_changed()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM pg_notify('agent_config_changed', json_build_object(
            'source', 'agent_system_config',
            'key', OLD.key,
            'operation', TG_OP
        )::text);
        RETURN OLD;
    END IF;
    PERFORM pg_notify('agent_config_changed', json_build_object(
        'source', 'agent_system_config',
        'key', NEW.key,
        'operation', TG_OP
    )::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER system_config_changed
    AFTER INSERT OR UPDATE OR DELETE ON agent_system_config
    FOR EACH ROW EXECUTE FUNCTION notify_system_config_changed();
```

---

## Installation

The installer (`agent-install.sh`) handles everything automatically:

1. Creates the `agent_system_config` table (if it doesn't exist)
2. Applies `scripts/migrations/163-system-config-trigger.sql` (idempotent)
3. Seeds `max_spawn_depth = 5` (ON CONFLICT DO NOTHING — won't overwrite existing values)

To run manually:

```bash
./agent-install.sh
```

---

## Plugin Configuration

Configure in `openclaw.json` under `plugins.entries.agent_config_sync.config`:

```json
{
  "plugins": {
    "entries": {
      "agent_config_sync": {
        "config": {
          "host": "localhost",
          "port": 5432,
          "database": "nova",
          "user": "nova",
          "password": "...",
          "outputPath": "/home/nova/.openclaw/agents.json"
        }
      }
    }
  }
}
```

If `config` is omitted, the plugin falls back to `channels.agent_chat` DB credentials.

---

## File Structure

```
focus/agent-config-sync/
├── index.ts          # Plugin entrypoint: LISTEN loop, reconnection, SIGUSR1 reload
├── src/
│   └── sync.ts       # Core logic: query, build, write agents.json
├── package.json
├── tsconfig.json
└── openclaw.plugin.json
```

---

## Key Behaviours

- **Atomic writes**: Uses a tmp file + rename to prevent partial reads during write
- **Idempotent sync**: Compares new content to existing file — skips write if identical
- **Graceful error handling**: Invalid DB values are warned about and skipped, never crash
- **Reconnection**: Exponential backoff (5s → 60s) on connection loss
- **Keep-alive**: 30s heartbeat query to detect stale connections early
- **Hot reload**: Sends `SIGUSR1` to gateway process after every successful write
