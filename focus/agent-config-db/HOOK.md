---
name: agent-config-db
description: "Looks up agent model/thinking config from database before spawn and agent runs"
metadata: {"openclaw":{"emoji":"🔧","events":["session:pre-spawn","agent:pre-run"],"requires":{"bins":["psql"]}}}
---

# Agent Config Database Hook

Intercepts `session:pre-spawn` and `agent:pre-run` events to look up agent configuration
from the `nova_memory.agents` table before spawning subagents or running agent commands.

## What It Does

1. **Requires agentId** — If no agentId is present in the spawn context, the hook blocks the spawn with an error
2. **Queries `nova_memory.agents` table** — Looks up `model`, `fallback_model`, and `thinking` by agent name
3. **Authoritative override** — Database values OVERWRITE caller-provided params (DB is single source of truth)
4. **Only overrides non-null DB values** — If a DB field is NULL, that param is left unchanged
5. **Empty/whitespace handling** — Empty strings and whitespace-only values are treated as NULL (no override)

## Hook Events

- **`session:pre-spawn`** — Fires in `spawnSubagentDirect()` before model resolution
- **`agent:pre-run`** — Fires in gateway `agent` handler before LLM run starts

## Database Schema

```sql
SELECT model, fallback_model, thinking 
FROM agents 
WHERE LOWER(name) = LOWER($1) 
LIMIT 1;
```

## Error Handling

- No database configured → `console.warn()`, return without mutation (spawn proceeds)
- DB connection failure → `console.error()`, return without mutation (spawn proceeds)
- Agent not found in DB → `console.log()` (info), return without mutation (spawn proceeds)
- Query error → `console.error()`, return without mutation (spawn proceeds)
- **Missing agentId → `console.error()`, blocks spawn** (prevents wrong config application)

## Requirements

- PostgreSQL connection to `nova_memory` database
- Peer authentication (no password needed)
- `agents` table with columns: `name`, `model`, `fallback_model`, `thinking`
