---
name: db-bootstrap-context
version: 1.0.0
events:
  - agent:bootstrap
---

# Database Bootstrap Context Hook

Loads agent context from PostgreSQL database instead of filesystem files.

## How It Works

1. Intercepts `agent:bootstrap` event (fires before agent session starts)
2. Queries `get_agent_bootstrap(agent_name)` function in nova_memory database
3. Returns universal context + agent-specific context
4. Falls back to static files in `~/.openclaw/bootstrap-fallback/` if database unavailable
5. Uses emergency minimal context if everything fails

## Database Tables

- `bootstrap_context_universal` - Context for all agents (AGENTS.md, SOUL.md, etc.)
- `bootstrap_context_agents` - Per-agent context (SEED_CONTEXT.md, domain knowledge)
- `bootstrap_context_config` - System configuration
- `bootstrap_context_audit` - Change audit log

## Management

Update context via SQL functions:

```sql
-- Universal context
SELECT update_universal_context('AGENTS', $content$...$content$, 'Agent roster', 'newhart');

-- Agent-specific context
SELECT update_agent_context('coder', 'SEED_CONTEXT', $content$...$content$, 'Coder seed', 'newhart');

-- List all context
SELECT * FROM list_all_context();
```

## Fallback System

Three-tier fallback:
1. **Database** - Primary source
2. **Static files** - `~/.openclaw/bootstrap-fallback/*.md`
3. **Emergency context** - Minimal recovery instructions

## Installation

See `../INSTALLATION_SUMMARY.md` for setup instructions.

## Owner

Newhart (NHR Agent) - Non-Human Resources
