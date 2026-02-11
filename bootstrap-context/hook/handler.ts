/**
 * Database Bootstrap Context Hook
 * 
 * Intercepts agent:bootstrap event to load context from database
 * instead of (or in addition to) filesystem files.
 * 
 * Falls back to static files if database unavailable.
 */

import { readFile } from 'fs/promises';
import { join } from 'path';
import { homedir } from 'os';

interface BootstrapFile {
  path: string;
  content: string;
}

interface BootstrapEvent {
  agent: string;
  context: {
    bootstrapFiles: BootstrapFile[];
  };
}

const FALLBACK_DIR = join(homedir(), '.openclaw', 'bootstrap-fallback');

/**
 * Query database for agent bootstrap context
 */
async function loadFromDatabase(agentName: string, pg: any): Promise<BootstrapFile[]> {
  try {
    const result = await pg.query(
      'SELECT * FROM get_agent_bootstrap($1)',
      [agentName]
    );
    
    return result.rows.map((row: any) => ({
      path: `db:${row.source}/${row.filename}`,
      content: row.content
    }));
  } catch (error) {
    console.error('[bootstrap-context] Database query failed:', error);
    return [];
  }
}

/**
 * Load fallback files from ~/.openclaw/bootstrap-fallback/
 */
async function loadFallbackFiles(agentName: string): Promise<BootstrapFile[]> {
  const fallbackFiles = [
    'UNIVERSAL_SEED.md',
    'AGENTS.md',
    'SOUL.md',
    'TOOLS.md',
    'IDENTITY.md',
    'USER.md',
    'HEARTBEAT.md'
  ];
  
  const files: BootstrapFile[] = [];
  
  for (const filename of fallbackFiles) {
    try {
      const content = await readFile(join(FALLBACK_DIR, filename), 'utf-8');
      files.push({
        path: `fallback:${filename}`,
        content
      });
    } catch (error) {
      // File doesn't exist or can't be read, skip it
      console.warn(`[bootstrap-context] Fallback file not found: ${filename}`);
    }
  }
  
  return files;
}

/**
 * Emergency minimal context if everything else fails
 */
function getEmergencyContext(): BootstrapFile[] {
  return [{
    path: 'emergency:RECOVERY.md',
    content: `# EMERGENCY BOOTSTRAP CONTEXT

⚠️ **System Status: Degraded**

Your bootstrap context system is not functioning properly.

## What Happened

- Database bootstrap query failed
- Fallback files not available
- Loading minimal emergency context

## Recovery Steps

1. Check database connection
2. Verify bootstrap_context tables exist:
   \`\`\`sql
   SELECT * FROM get_agent_bootstrap('your_agent_name');
   \`\`\`
3. Check fallback directory: ~/.openclaw/bootstrap-fallback/
4. Contact Newhart (NHR Agent) for assistance

## Temporary Context

You are an AI agent in the NOVA system. Your full context could not be loaded.
Operate in safe mode until context is restored.

**Database:** nova_memory
**Tables:** bootstrap_context_universal, bootstrap_context_agents
**Hook:** ~/.openclaw/hooks/db-bootstrap-context/
`
  }];
}

/**
 * Main hook handler
 */
export default async function handler(event: BootstrapEvent, { pg }: any) {
  const agentName = event.agent;
  
  console.log(`[bootstrap-context] Loading context for agent: ${agentName}`);
  
  // Try database first
  let files = await loadFromDatabase(agentName, pg);
  
  if (files.length === 0) {
    console.warn('[bootstrap-context] No database context, trying fallback files...');
    files = await loadFallbackFiles(agentName);
  }
  
  if (files.length === 0) {
    console.error('[bootstrap-context] No fallback files, using emergency context');
    files = getEmergencyContext();
  }
  
  // Replace the default bootstrapFiles with our database/fallback content
  event.context.bootstrapFiles = files;
  
  console.log(`[bootstrap-context] Loaded ${files.length} context files for ${agentName}`);
}
