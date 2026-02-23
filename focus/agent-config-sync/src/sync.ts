/**
 * Agent Config Sync — core logic
 *
 * Queries the `agents` table and builds the agents.json config structure.
 * Writes atomically (tmp + rename) to prevent partial reads.
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import type pg from "pg";

// ── Types ───────────────────────────────────────────────────────────────────

export type AgentRow = {
  name: string;
  model: string;
  fallback_models: string[] | null;
  thinking: string | null;
  instance_type: string;
  allowed_subagents: string[] | null;
};

type AgentListEntry = {
  id: string;
  model: string | { primary: string; fallbacks: string[] };
  thinking?: string;
  subagents?: { allowAgents: string[] };
};

type AgentsJson = {
  agents: {
    defaults: {
      models: Record<string, Record<string, never>>;
    };
    list: AgentListEntry[];
  };
};

// ── SQL ─────────────────────────────────────────────────────────────────────

const AGENTS_QUERY = `
  SELECT name, model, fallback_models, thinking, instance_type, allowed_subagents
  FROM agents
  WHERE instance_type IN ('primary', 'subagent')
    AND model IS NOT NULL
  ORDER BY name;
`;

// NOTE: Trigger dependency — Newhart needs to run:
// ALTER the notify_agent_config_changed() function to include:
// OR OLD.allowed_subagents IS DISTINCT FROM NEW.allowed_subagents

// ── Build ───────────────────────────────────────────────────────────────────

/**
 * Build the agents.json structure from raw DB rows.
 */
export function buildAgentsJson(rows: AgentRow[]): AgentsJson {
  const allModels = new Set<string>();
  const list: AgentListEntry[] = [];

  for (const row of rows) {
    // Collect primary model
    allModels.add(row.model);

    const hasFallbacks =
      Array.isArray(row.fallback_models) && row.fallback_models.length > 0;

    if (hasFallbacks) {
      // Collect fallback models into the allow-list
      for (const fb of row.fallback_models!) {
        allModels.add(fb);
      }
    }

    // Build list entry
    const entry: AgentListEntry = {
      id: row.name,
      model: hasFallbacks
        ? { primary: row.model, fallbacks: [...row.fallback_models!] }
        : row.model,
    };

    // Note: 'thinking' is not a valid per-agent config key in OpenClaw's schema.
    // Thinking level is set at spawn time via sessions_spawn(thinking=...), not in agent definitions.
    // The DB 'thinking' column stores the preferred level for reference, but it's not written to agents.json.

    // Include subagents.allowAgents if set
    if (Array.isArray(row.allowed_subagents) && row.allowed_subagents.length > 0) {
      entry.subagents = { allowAgents: [...row.allowed_subagents].sort() };
    }

    list.push(entry);
  }

  // Build the allow-list object (sorted for stable output)
  const models: Record<string, Record<string, never>> = {};
  for (const m of [...allModels].sort()) {
    models[m] = {};
  }

  return {
    agents: {
      defaults: { models },
      list,
    },
  };
}

// ── Query ───────────────────────────────────────────────────────────────────

/**
 * Fetch agent rows from the database.
 */
export async function fetchAgentRows(client: pg.Client): Promise<AgentRow[]> {
  const result = await client.query<AgentRow>(AGENTS_QUERY);
  return result.rows;
}

// ── Write ───────────────────────────────────────────────────────────────────

/**
 * Write agents.json atomically (write to temp, then rename).
 */
export async function writeAgentsJsonAtomically(
  filePath: string,
  data: AgentsJson,
): Promise<void> {
  const dir = path.dirname(filePath);
  await fs.promises.mkdir(dir, { recursive: true });

  const tmpFile = path.join(
    dir,
    `${path.basename(filePath)}.${crypto.randomUUID()}.tmp`,
  );

  const content = JSON.stringify(data, null, 2) + "\n";

  await fs.promises.writeFile(tmpFile, content, { encoding: "utf-8" });
  await fs.promises.rename(tmpFile, filePath);
}

// ── Full sync ───────────────────────────────────────────────────────────────

/**
 * Perform a full sync: query DB → build JSON → write file.
 * Returns true if the file was changed, false if identical.
 */
export async function syncAgentsConfig(
  client: pg.Client,
  outputPath: string,
): Promise<boolean> {
  const rows = await fetchAgentRows(client);
  const data = buildAgentsJson(rows);
  const newContent = JSON.stringify(data, null, 2) + "\n";

  // Check if file already matches (avoid unnecessary writes / watcher triggers)
  try {
    const existing = await fs.promises.readFile(outputPath, "utf-8");
    if (existing === newContent) {
      return false;
    }
  } catch {
    // File doesn't exist yet — continue to write
  }

  await writeAgentsJsonAtomically(outputPath, data);
  return true;
}
