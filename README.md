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
```

## Philosophy

> "Subagents are extensions of your thinking. Peer agents are colleagues."

The MCP doesn't do everything itself—it orchestrates. Complex tasks get delegated to specialists. The cognition system defines *how* that delegation works.

## Getting Started

1. Define your primary agent (MCP) with a high-capability model
2. Identify recurring task types that could be subagents
3. Decide which domains need peer agents (separate context/expertise)
4. Set up inter-agent communication protocol
5. Create context seeds for each agent role

## License

MIT License - See [LICENSE](LICENSE) for details.

---

*Part of the [NOVA-Openclaw](https://github.com/NOVA-Openclaw) project.*
