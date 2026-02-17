# NOVA Cognition System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Agent orchestration, delegation patterns, and context seeding for AI agent ecosystems.

## Overview

A framework for organizing how multiple AI agents coordinate, delegate, and communicate. Designed to be model-agnostic and platform-flexible.

**Companion project:** [nova-memory](https://github.com/NOVA-Openclaw/nova-memory) handles the "memory" layer (database schemas, semantic embeddings, entity storage).

## Installation

### Prerequisites

**Required:**
- Node.js 18+ and npm
- TypeScript (`npm install -g typescript`)
- PostgreSQL with `nova_memory` database
- `nova-memory` must be installed first (provides required shared library files and database tables)

**The nova-memory database must include:**
- `agent_chat` table — Inter-agent messaging
- `agent_jobs` table — Task tracking and delegation

### Installer Entry Points

**For humans (quick wrapper):**
```bash
./shell-install.sh
```

This wrapper:
- Loads database config from `~/.openclaw/postgres.json`
- Loads API keys from `~/.openclaw/openclaw.json` via env-loader
- Sets up shell environment
- Automatically execs `agent-install.sh`

**For AI agents with environment pre-configured:**
```bash
./agent-install.sh
```

This is the actual installer. It:
- Verifies prerequisite library files from nova-memory exist
- Installs the `agent_chat` TypeScript extension to `~/.openclaw/extensions/`
- Builds the extension (npm install, TypeScript compilation)
- Verifies database schema (agent_chat, agent_jobs tables)
- Installs hook scripts for agent communication
- Verifies all components are working

**Common flags:**
- `--verify-only` — Check installation without modifying anything
- `--force` — Force overwrite existing files and rebuild
- `--database NAME` or `-d NAME` — Override database name (default: `${USER}_memory`)

## Core Concepts

### Agent Types

| Type | Description | Communication |
|------|-------------|---------------|
| **MCP (Master Control Program)** | Primary orchestrator agent | Directs all other agents |
| **Subagents** | Task-focused extensions of the MCP | Spawned on-demand, share context |
| **Peer Agents** | Independent agents with their own context | Message-based collaboration |

### Key Patterns

- **Delegation** - When to spawn subagents vs message peers
- **Confidence Gating** - Distinguishing "thinking" from "acting"
- **Context Seeding** - Initializing agent personality and knowledge
- **Inter-Agent Communication** - Protocols for agent collaboration
- **Jobs System** - Task tracking for reliable work handoffs between agents

## Structure

```
nova-cognition/
├── docs/                    # Architecture documentation
│   ├── models.md            # AI model reference and selection guide
│   └── delegation-context.md # Dynamic delegation context generation
├── focus/                   # Multi-agent & initialization components
│   ├── agents/              # Agent organization patterns
│   │   ├── subagents/       # Subagent role definitions
│   │   └── peers/           # Peer agent protocols
│   ├── templates/           # SOUL.md, AGENTS.md, context seed templates
│   └── protocols/           # Communication and coordination protocols
│       ├── agent-chat.md    # Inter-agent messaging protocol
│       └── jobs-system.md   # Task tracking and handoff coordination
```

## Protocols

### [Agent Chat](focus/protocols/agent-chat.md)
Database-backed messaging system for inter-agent communication. Agents send messages via PostgreSQL with NOTIFY/LISTEN for real-time delivery.

### [Jobs System](focus/protocols/jobs-system.md)
Task tracking layer on top of agent-chat. When Agent A requests work from Agent B:
- Job auto-created on message receipt
- Tracks status: pending → in_progress → completed
- Auto-notifies requester on completion
- Supports sub-jobs for complex delegation chains

Prevents the "finished but forgot to notify" failure mode.

### [Delegation Context](docs/delegation-context.md)
Dynamic context generation for agent delegation decisions. The `generate-delegation-context.sh` script queries the `nova_memory` database to produce real-time awareness of:
- Available subagents (roles, capabilities, models)
- Active workflows (multi-agent coordination patterns)
- Spawn instructions (agent-specific delegation guidance)

Provides agents with "who can help" and "how work flows" knowledge for effective delegation.

## Philosophy

> "Subagents are extensions of your thinking. Peer agents are colleagues."
> 
> "The self becomes the orchestration layer."

The MCP doesn't do everything itself—it orchestrates. Complex tasks get delegated to specialists. The cognition system defines *how* that delegation works.

**[Read more: Subagents as Cognitive Architecture](docs/philosophy.md)** — How subagent patterns parallel "parts work" in human psychology and NLP. Subagents aren't just task workers — they're externalized cognitive modes that inform and enrich the greater self.

---

> *Semantic threads weave*
> *PostgreSQL anchors time—*
> *Compressed wisdom blooms*

— **Quill**, NOVA's creative writing facet

---

## Getting Started

1. Define your primary agent (MCP) with a high-capability model
2. Identify recurring task types that could be subagents
3. Decide which domains need peer agents (separate context/expertise)
4. Set up inter-agent communication protocol
5. Create context seeds for each agent role

## Clawdbot Contributions

We contribute patches back to upstream [Clawdbot](https://github.com/clawdbot/clawdbot) to improve multi-agent orchestration:

### Subagent ENV Variables (PR #11172)

**Problem:** Spawned subagents couldn't identify themselves, making authorization (e.g., git push permissions) impossible.

**Solution:** Pass `CLAWDBOT_AGENT_ID` environment variable to subagent processes.

**Impact:** Enables patterns like "Gidget is authorized to push to git, but NOVA must delegate to Gidget."

**Patch:** [nova-memory/clawdbot-patches/subagent-env-vars.patch](https://github.com/NOVA-Openclaw/nova-memory/tree/main/clawdbot-patches)

### Message Hooks (PR #6797)

**Problem:** No way to trigger automated processing on message receipt.

**Solution:** Add `message:received` and `message:sent` hook events.

**Impact:** Enables automatic memory extraction pipeline (process every incoming message).

**Patch:** Stored in nova-memory repo with the memory extraction scripts that depend on it.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

*Part of the [NOVA-Openclaw](https://github.com/NOVA-Openclaw) project.*
