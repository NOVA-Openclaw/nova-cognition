/**
 * Agent Config Sync — core logic
 *
 * Queries the `agents` table and `agent_system_config` table and builds the
 * agents.json config structure. Writes atomically (tmp + rename) to prevent
 * partial reads.
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

export type SystemConfigRow = {
  key: string;
  value: string;
  value_type: string;
};

type AgentListEntry = {
  id: string;
  model: string | { primary: string; fallbacks: string[] };
  thinking?: string;
  subagents?: { allowAgents: string[] };
};

type SystemDefaults = {
  maxSpawnDepth?: number;
  maxConcurrent?: number;
};

type AgentsJson = {
  agents: {
    defaults: {
      models: Record<string, Record<string, never>>;
      subagents?: { maxSpawnDepth?: number; maxConcurrent?: number };
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

// Whitelist approach: only fetch known keys from agent_system_config
const SYSTEM_CONFIG_QUERY = `
  SELECT key, value, value_type
  FROM agent_system_config
  WHERE key IN ('max_spawn_depth', 'max_concurrent_subagents');
`;

// ── Build ───────────────────────────────────────────────────────────────────

/**
 * Parse system config rows into a typed SystemDefaults object.
 * - Uses whitelisted key mapping only
 * - Casts values based on value_type column
 * - Logs warnings for invalid values and skips them (never crashes)
 * - Clamps maxSpawnDepth to 1–5 (OpenClaw's valid range)
 */
export function buildSystemDefaults(rows: SystemConfigRow[]): SystemDefaults {
  const defaults: SystemDefaults = {};

  for (const row of rows) {
    try {
      switch (row.key) {
        case "max_spawn_depth": {
          if (row.value_type !== "integer") {
            console.warn(
              `agent_config_sync: Unexpected value_type '${row.value_type}' for max_spawn_depth (expected 'integer') — skipping`,
            );
            break;
          }
          const parsed = parseInt(row.value, 10);
          if (isNaN(parsed)) {
            console.warn(
              `agent_config_sync: Invalid integer value '${row.value}' for max_spawn_depth — skipping`,
            );
            break;
          }
          // Clamp to OpenClaw's valid range 1–5
          const clamped = Math.max(1, Math.min(5, parsed));
          if (clamped !== parsed) {
            console.warn(
              `agent_config_sync: max_spawn_depth value ${parsed} clamped to ${clamped} (valid range: 1–5)`,
            );
          }
          defaults.maxSpawnDepth = clamped;
          break;
        }

        case "max_concurrent_subagents": {
          if (row.value_type !== "integer") {
            console.warn(
              `agent_config_sync: Unexpected value_type '${row.value_type}' for max_concurrent_subagents (expected 'integer') — skipping`,
            );
            break;
          }
          const parsed = parseInt(row.value, 10);
          if (isNaN(parsed)) {
            console.warn(
              `agent_config_sync: Invalid integer value '${row.value}' for max_concurrent_subagents — skipping`,
            );
            break;
          }
          defaults.maxConcurrent = parsed;
          break;
        }

        default:
          // Unknown key — whitelist approach, silently ignore
          break;
      }
    } catch (err) {
      console.warn(
        `agent_config_sync: Error processing system config key '${row.key}': ${err} — skipping`,
      );
    }
  }

  return defaults;
}

/**
 * Build the agents.json structure from raw DB rows and optional system defaults.
 */
export function buildAgentsJson(
  rows: AgentRow[],
  systemDefaults?: SystemDefaults,
): AgentsJson {
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

  // Build defaults section — only include subagents block if there are values
  const defaultsSection: AgentsJson["agents"]["defaults"] = { models };

  if (systemDefaults) {
    const subagentsBlock: { maxSpawnDepth?: number; maxConcurrent?: number } = {};

    if (systemDefaults.maxSpawnDepth !== undefined) {
      subagentsBlock.maxSpawnDepth = systemDefaults.maxSpawnDepth;
    }
    if (systemDefaults.maxConcurrent !== undefined) {
      subagentsBlock.maxConcurrent = systemDefaults.maxConcurrent;
    }

    // Only include the subagents block if it has at least one value
    if (Object.keys(subagentsBlock).length > 0) {
      defaultsSection.subagents = subagentsBlock;
    }
  }

  return {
    agents: {
      defaults: defaultsSection,
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

/**
 * Fetch system config rows from the database.
 * Returns an empty array if the table doesn't exist or query fails.
 */
export async function fetchSystemConfig(
  client: pg.Client,
): Promise<SystemConfigRow[]> {
  try {
    const result = await client.query<SystemConfigRow>(SYSTEM_CONFIG_QUERY);
    return result.rows;
  } catch (err) {
    // Table may not exist yet — log and return empty (don't crash)
    console.warn(
      `agent_config_sync: Could not fetch agent_system_config (table may not exist): ${err}`,
    );
    return [];
  }
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
  const [rows, systemConfigRows] = await Promise.all([
    fetchAgentRows(client),
    fetchSystemConfig(client),
  ]);

  const systemDefaults = buildSystemDefaults(systemConfigRows);
  const data = buildAgentsJson(rows, systemDefaults);
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
