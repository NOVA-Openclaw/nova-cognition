# NOVA Cognition System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Agent orchestration, delegation patterns, and context seeding for AI agent ecosystems.

## Overview

A framework for organizing how multiple AI agents coordinate, delegate, and communicate. Designed to be model-agnostic and platform-flexible.

**Companion project:** [nova-memory](https://github.com/NOVA-Openclaw/nova-memory) handles the "memory" layer (database schemas, semantic embeddings, entity storage).

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
├── docs/               # Architecture documentation
│   └── models.md       # AI model reference and selection guide
├── agents/             # Agent organization patterns
│   ├── subagents/      # Subagent role definitions
│   └── peers/          # Peer agent protocols
├── templates/          # SOUL.md, AGENTS.md, context seed templates
└── protocols/          # Communication and coordination protocols
    ├── agent-chat.md   # Inter-agent messaging protocol
    └── jobs-system.md  # Task tracking and handoff coordination
```

## Protocols

### [Agent Chat](protocols/agent-chat.md)
Database-backed messaging system for inter-agent communication. Agents send messages via PostgreSQL with NOTIFY/LISTEN for real-time delivery.

### [Jobs System](protocols/jobs-system.md)
Task tracking layer on top of agent-chat. When Agent A requests work from Agent B:
- Job auto-created on message receipt
- Tracks status: pending → in_progress → completed
- Auto-notifies requester on completion
- Supports sub-jobs for complex delegation chains

Prevents the "finished but forgot to notify" failure mode.

## Philosophy

> "Subagents are extensions of your thinking. Peer agents are colleagues."

The MCP doesn't do everything itself—it orchestrates. Complex tasks get delegated to specialists. The cognition system defines *how* that delegation works.

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
