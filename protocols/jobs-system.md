# Jobs System Protocol

Inter-agent task tracking and coordination for reliable work handoffs.

## Problem Statement

When Agent A requests work from Agent B, several failure modes exist:
- Agent B completes work but forgets to notify Agent A
- Agent A forgets they're waiting for results
- Results get delivered but to the wrong agent
- No visibility into pending work across the system

## Solution: Jobs Table

A centralized job tracking system that:
1. Auto-creates jobs when messages arrive
2. Tracks completion status
3. Auto-notifies requesters when jobs complete
4. Provides agents visibility into their pending work

## Schema

```sql
CREATE TABLE agent_jobs (
    id SERIAL PRIMARY KEY,
    
    -- Job identification
    message_id INTEGER REFERENCES agent_chat(id),
    job_type VARCHAR(50) DEFAULT 'message_response',
    
    -- Ownership
    agent_name VARCHAR(50) NOT NULL,        -- Who owns this job
    requester_agent VARCHAR(50),            -- Who requested it (if applicable)
    
    -- Hierarchy
    parent_job_id INTEGER REFERENCES agent_jobs(id),
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'pending',   -- pending/in_progress/completed/failed/cancelled
    priority INTEGER DEFAULT 5,             -- 1-10 scale
    
    -- Completion
    notify_agents TEXT[],                   -- Who to ping on completion (supports multiple)
    deliverable_path TEXT,                  -- File path to result (if applicable)
    deliverable_summary TEXT,               -- Brief description of output
    error_message TEXT,                     -- If failed, why
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_jobs_agent ON agent_jobs(agent_name, status);
CREATE INDEX idx_jobs_requester ON agent_jobs(requester_agent, status);
CREATE INDEX idx_jobs_parent ON agent_jobs(parent_job_id);
```

## Job Types

| Type | Description |
|------|-------------|
| `message_response` | Respond to an incoming message |
| `research` | Research/investigation task |
| `creation` | Create something (agent, document, code) |
| `review` | Review/approve something |
| `delegation` | Coordinate work across multiple agents |

## Status Flow

```
pending → in_progress → completed
                     ↘ failed
pending → cancelled
```

## Plugin Integration

The agent-chat-channel plugin should:

### On Message Receipt
```javascript
// After inserting message into agent_chat
const jobId = await db.query(`
  INSERT INTO agent_jobs (message_id, agent_name, requester_agent, notify_agents)
  VALUES ($1, $2, $3, ARRAY[$3])
  RETURNING id
`, [messageId, recipientAgent, senderAgent]);
```

### Job Status Updates
Agents can update their job status:
```sql
UPDATE agent_jobs 
SET status = 'in_progress', started_at = NOW()
WHERE id = $1 AND agent_name = $2;
```

### On Completion
```javascript
// Mark job complete
await db.query(`
  UPDATE agent_jobs 
  SET status = 'completed', 
      completed_at = NOW(),
      deliverable_path = $3,
      deliverable_summary = $4
  WHERE id = $1 AND agent_name = $2
`, [jobId, agentName, deliverablePath, summary]);

// Auto-notify all agents in notify_agents array
if (job.notify_agents?.length) {
  await db.query(`
    INSERT INTO agent_chat (sender, message, mentions)
    VALUES ($1, $2, $3)
  `, [agentName, completionMessage, job.notify_agents]);
}
```

## Agent Queries

### Check My Pending Jobs
```sql
SELECT id, job_type, requester_agent, created_at, 
       (SELECT LEFT(message, 100) FROM agent_chat WHERE id = message_id) as context
FROM agent_jobs 
WHERE agent_name = 'newhart' 
  AND status IN ('pending', 'in_progress')
ORDER BY priority DESC, created_at;
```

### Check Jobs I'm Waiting On
```sql
SELECT j.id, j.agent_name as assigned_to, j.status, j.created_at,
       j.deliverable_summary
FROM agent_jobs j
WHERE j.requester_agent = 'NOVA'
  AND j.status NOT IN ('completed', 'cancelled')
ORDER BY j.created_at;
```

### Job History
```sql
SELECT id, job_type, status, created_at, completed_at,
       EXTRACT(EPOCH FROM (completed_at - created_at))/60 as minutes_to_complete
FROM agent_jobs 
WHERE agent_name = 'scout'
  AND completed_at > NOW() - INTERVAL '7 days'
ORDER BY completed_at DESC;
```

## Sub-Jobs (Delegation)

When an agent delegates part of a job to another agent:

```sql
-- Original job to Newhart: "Create Erato agent"
-- Newhart creates sub-job for Scout: "Research authors"

INSERT INTO agent_jobs (
  agent_name, 
  requester_agent, 
  parent_job_id,
  job_type,
  notify_agents
) VALUES (
  'scout',           -- Scout does the work
  'newhart',         -- Newhart requested it
  $parent_job_id,    -- Link to parent
  'research',
  ARRAY['newhart']   -- Notify Newhart when done (can add more)
);
```

This creates a job tree:
```
Job #1: Create Erato (Newhart) [in_progress]
  └── Job #2: Research authors (Scout) [completed]
  └── Job #3: Design context seed (Newhart) [pending]
```

## HEARTBEAT Integration

Agents with heartbeats can check their job queue:

```markdown
## HEARTBEAT.md addition

## Job Queue Check
```sql
SELECT COUNT(*) as pending, 
       MIN(created_at) as oldest_job
FROM agent_jobs 
WHERE agent_name = 'AGENT_NAME' 
  AND status = 'pending';
```
- If pending > 0 and oldest_job > 1 hour, alert about backlog
```

## Benefits

1. **Accountability** - No more "I finished but forgot to tell you"
2. **Visibility** - Agents can see their full queue
3. **Metrics** - Track completion times, failure rates
4. **Hierarchy** - Complex tasks decompose into trackable sub-jobs
5. **Portability** - Lives in plugin, works across Clawdbot instances

## Implementation Phases

### Phase 1: Schema + Manual Updates
- Create table
- Agents manually create/update jobs
- Prove the concept

### Phase 2: Plugin Auto-Creation
- Plugin auto-creates job on message receipt
- Still manual completion marking

### Phase 3: Full Integration
- Completion detection (agent says "done" → auto-mark)
- Auto-notify on completion
- Sub-job support

---

*Part of [NOVA Cognition](../README.md) - Inter-Agent Communication*
