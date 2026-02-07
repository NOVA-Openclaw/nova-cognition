# Agent Registry

Current agents in the NOVA Cognition System.

## Agent Types

| Type | Description | Lifecycle |
|------|-------------|-----------|
| **primary** | Main orchestrator (MCP) | Always running |
| **peer** | Independent agents with own context | Persistent, separate process |
| **subagent** | Task-focused extensions of MCP | On-demand or persistent |

## Current Agents

### Primary Agent

| Nickname | Name | Role | Model |
|----------|------|------|-------|
| **NOVA** | nova-main | general | claude-opus-4 |

The Master Control Program. Orchestrates all other agents, handles user interaction, manages delegation.

### Peer Agents

| Nickname | Name | Role | Model | Notes |
|----------|------|------|-------|-------|
| **Newhart** | nhr-agent | meta | openai/o3-pro | Agent architect, designs and manages other agents |

Peer agents have their own context windows and persistence. Communication via `agent_chat` protocol.

### Subagents

| Nickname | Name | Role | Model | Persistent |
|----------|------|------|-------|------------|
| **Scout** | research-agent | research | gemini-2.5-flash | ❌ |
| **Coder** | claude-code | coding | claude-sonnet-4-5 | ✅ |
| **Gidget** | git-agent | git-ops | openai/o4-mini | ❌ |
| **Athena** | librarian-agent | media-curation | gemini-2.0-flash | ❌ |
| **IRIS** | iris-artist | creative | claude-sonnet-4 | ❌ |
| **Ticker** | ticker-agent | portfolio-management | gemini-2.5-flash | ✅ |
| **Gem** | gemini-cli | quick-qa | gemini-2.0-flash | ❌ |

Subagents are extensions of NOVA's thinking—spawned when deeper focus on a specific task is needed.

## Delegation Patterns

### When to Spawn a Subagent

- Task requires specialized focus (research, coding, creative work)
- Parallel execution would help (multiple research threads)
- Task might take a while and you want to continue other work

### When to Message a Peer Agent

- Task requires their domain expertise (Newhart for agent architecture)
- Decision needs collaborative input
- Task affects their systems or responsibilities

### Example Flows

**Research Task:**
```
User asks complex question
  → NOVA spawns Scout (research-agent)
  → Scout researches, returns findings
  → NOVA synthesizes and responds
```

**Agent Architecture Change:**
```
Need to modify an agent's config
  → NOVA messages Newhart via agent_chat
  → Newhart reviews and implements
  → Newhart confirms completion
```

**Code Change:**
```
Feature needs implementation
  → NOVA spawns Coder (claude-code)
  → Coder writes code
  → NOVA spawns Gidget (git-agent) for commit/push
```

---

*Data sourced from NOVA's `agents` table, maintained by Newhart.*
