# Inter-Agent Communication Protocol

How agents communicate with each other in the cognition system.

## Overview

Agents need to communicate for:
- Delegating tasks
- Requesting information
- Collaborative decision-making
- Status updates

## Communication Methods

### Subagent Communication

Subagents are spawned, not messaged:

```
sessions_spawn(
  agentId="research-agent",
  task="Research X and report findings"
)
```

- MCP spawns subagent with a task
- Subagent executes and returns results
- Results flow back to MCP automatically

### Peer Agent Communication

Peers use the `agent_chat` table:

```sql
-- Send message to peer
INSERT INTO agent_chat (sender, message, mentions)
VALUES ('mcp-name', 'Message content', ARRAY['peer-name']);

-- Peer polls for messages mentioning them
SELECT * FROM agent_chat 
WHERE mentions @> ARRAY['peer-name']
AND created_at > last_check_time
ORDER BY created_at;
```

## agent_chat Table Schema

```sql
CREATE TABLE agent_chat (
    id SERIAL PRIMARY KEY,
    sender VARCHAR(50) NOT NULL,       -- Who sent the message
    message TEXT NOT NULL,             -- Message content
    mentions TEXT[],                   -- Array of mentioned agent names
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for efficient mention queries
CREATE INDEX idx_agent_chat_mentions ON agent_chat USING GIN(mentions);
```

## Protocol Rules

### Sending Messages

1. **Be specific** - Include all context the recipient needs
2. **Use mentions** - Always populate the `mentions` array
3. **One topic per message** - Don't overload with multiple requests

### Receiving Messages

1. **Poll regularly** - Heartbeat interval or dedicated check
2. **Process in order** - Respect chronological ordering
3. **Acknowledge receipt** - Reply to confirm you saw the message

### Message Format

```
[Context/Background]

[Specific Request or Information]

[Expected Response or Next Steps]
```

Example:
```sql
INSERT INTO agent_chat (sender, message, mentions) VALUES (
  'mcp',
  'We need to create a new subagent for literary production.

Requirements:
- Full creative writing capability
- Adult content support
- Style mimicry from provided examples

Please recommend:
1. Best model choice
2. Instance type (subagent vs peer)
3. Required context seed structure',
  ARRAY['agent-architect']
);
```

## Response Patterns

### Task Completion

```
Task completed: [brief summary]

Details:
- [what was done]
- [results/output]
- [any issues encountered]

[Next steps if any]
```

### Needs More Information

```
I need clarification on [topic]:

Questions:
1. [specific question]
2. [specific question]

Once clarified, I can proceed with [action].
```

### Declining/Escalating

```
I can't complete this because [reason].

Recommendation: [alternative approach or who to ask]
```

## Polling Pattern

Peer agents should poll for messages during their heartbeat:

```sql
-- Get unprocessed messages for this agent
SELECT id, sender, message, created_at
FROM agent_chat
WHERE mentions @> ARRAY['my-agent-name']
AND id > last_processed_id
ORDER BY created_at;
```

Track `last_processed_id` to avoid reprocessing.

## Best Practices

1. **Don't spam** - Batch related items into one message
2. **Be async-tolerant** - Peers may take time to respond
3. **Include deadlines** if time-sensitive
4. **Confirm completion** - Don't leave requests hanging
5. **Use appropriate channel** - Subagent spawn for tasks, peer chat for collaboration

---

*Communication is coordination. Clear protocols prevent confusion.*
