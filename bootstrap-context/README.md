# Database Bootstrap Context System

Automatic agent context loading from PostgreSQL database with file fallbacks.

## Overview

OpenClaw agents normally load context from workspace files (AGENTS.md, SOUL.md, etc.). This system replaces that with **database-backed context** that can be updated without touching the filesystem.

## Key Features

- **Database-first**: Context stored in `nova_memory` database
- **Per-agent customization**: Universal + agent-specific context
- **Three-tier fallback**: Database → static files → emergency minimal context
- **SQL management interface**: Safe functions for updates
- **Audit trail**: Track all context changes
- **Hook-based**: Intercepts `agent:bootstrap` event transparently

## Architecture

```
Agent Spawn Request
        ↓
agent:bootstrap event fires
        ↓
Hook intercepts event
        ↓
Query: get_agent_bootstrap(agent_name)
        ↓
    ┌─── Database available? ───┐
    │                           │
   YES                         NO
    │                           │
    ↓                           ↓
Return DB context      Try fallback files
    │                           │
    └──────────┬────────────────┘
               ↓
    Inject into event.context.bootstrapFiles
               ↓
    Agent starts with loaded context
```

## Installation

```bash
cd ~/clawd/nova-cognition/bootstrap-context
./install.sh
```

This installs:
- Database tables and functions
- OpenClaw hook at `~/.openclaw/hooks/db-bootstrap-context/`
- Fallback files at `~/.openclaw/bootstrap-fallback/`

## Usage

### Managing Universal Context

Context that applies to all agents:

```sql
-- Update AGENTS.md
SELECT update_universal_context('AGENTS', $content$
# AGENTS.md
...
$content$, 'Agent roster', 'newhart');

-- Update SOUL.md
SELECT update_universal_context('SOUL', $content$
# SOUL.md
...
$content$, 'System soul', 'newhart');
```

### Managing Agent-Specific Context

Context for individual agents:

```sql
-- Update Coder's seed context
SELECT update_agent_context('coder', 'SEED_CONTEXT', $content$
# Coder Seed Context
...
$content$, 'Coder domain knowledge', 'newhart');

-- Update Scout's seed context
SELECT update_agent_context('scout', 'SEED_CONTEXT', $content$
# Scout Seed Context
...
$content$, 'Scout domain knowledge', 'newhart');
```

### Listing Context

```sql
-- See all context files
SELECT * FROM list_all_context();

-- Get context for specific agent
SELECT * FROM get_agent_bootstrap('coder');
```

### Testing

```sql
-- Check configuration
SELECT * FROM get_bootstrap_config();

-- Verify agent context loads
SELECT filename, source, length(content) as size 
FROM get_agent_bootstrap('test');
```

## File Structure

```
bootstrap-context/
├── README.md                    # This file
├── install.sh                   # Installation script
├── schema/
│   └── bootstrap-context.sql    # Database tables
├── sql/
│   ├── management-functions.sql # SQL interface
│   └── migrate-initial-context.sql  # Import existing files
├── hook/
│   ├── handler.ts               # OpenClaw hook
│   └── HOOK.md                  # Hook metadata
├── fallback/
│   ├── UNIVERSAL_SEED.md        # Fallback files
│   ├── AGENTS.md
│   ├── SOUL.md
│   └── ...
└── docs/
    ├── INSTALLATION_SUMMARY.md
    └── MANAGEMENT.md
```

## Database Schema

### Tables

- `bootstrap_context_universal` - Universal context (all agents)
- `bootstrap_context_agents` - Per-agent context
- `bootstrap_context_config` - System configuration
- `bootstrap_context_audit` - Change audit log

### Functions

- `update_universal_context()` - Update universal file
- `update_agent_context()` - Update agent-specific file
- `get_agent_bootstrap()` - Get all files for agent
- `copy_file_to_bootstrap()` - Migrate filesystem file to DB
- `list_all_context()` - List all context files
- `delete_universal_context()` - Remove universal file
- `delete_agent_context()` - Remove agent file

## Owner

**Newhart (NHR Agent)** - Non-Human Resources

This is Newhart's domain. All agent context management goes through this system.

## Documentation

- [Installation Summary](./docs/INSTALLATION_SUMMARY.md)
- [Management Guide](./docs/MANAGEMENT.md)
- [Hook Reference](./hook/HOOK.md)

## License

MIT License - Part of nova-cognition
