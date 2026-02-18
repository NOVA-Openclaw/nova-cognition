/**
 * Agent Config Database Hook
 *
 * Intercepts session:pre-spawn and agent:pre-run events to look up
 * agent model/thinking config from the database before spawning subagents.
 *
 * Enforces agentId presence — blocks spawn if agentId is missing.
 */

import { userInfo } from "os";
import pg from "pg";

const { Pool } = pg;

// Create connection pool (reused across invocations)
let pool: pg.Pool | null = null;

try {
  pool = new Pool({
    host: "localhost",
    database: "nova_memory",
    user: process.env.USER || userInfo().username || "nova",
    // No password needed (peer auth)
    max: 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  });
} catch (error) {
  console.warn(
    "[agent-config-db] Failed to create database pool:",
    error instanceof Error ? error.message : String(error),
  );
  console.warn("[agent-config-db] Hook will be inactive (no database connection)");
}

/**
 * Query database for agent configuration
 */
async function loadFromDatabase(
  agentName: string,
): Promise<{ model?: string; fallbackModel?: string; thinking?: string } | null> {
  if (!pool) {
    console.warn("[agent-config-db] Hook active but database pool not available");
    return null;
  }

  let client;
  try {
    client = await pool.connect();

    // Set statement timeout to 3 seconds to prevent slow queries from hanging spawn
    await client.query("SET LOCAL statement_timeout = '3000'");

    // Query with case-insensitive match (LOWER) to align with OpenClaw's normalizeAgentId
    const result = await client.query(
      "SELECT model, fallback_model, thinking FROM agents WHERE LOWER(name) = LOWER($1) LIMIT 1",
      [agentName],
    );

    if (result.rows.length === 0) {
      console.log(`[agent-config-db] Agent not found in DB: ${agentName}`);
      return null;
    }

    const row = result.rows[0];

    // Return the raw values (we'll process them in the handler)
    return {
      model: row.model,
      fallbackModel: row.fallback_model,
      thinking: row.thinking,
    };
  } catch (error) {
    // Gracefully handle database errors
    if ((error as any).code === "ECONNREFUSED") {
      console.error(
        "[agent-config-db] Database connection refused - spawn will proceed with original params",
      );
    } else if ((error as any).code === "42P01") {
      console.error(
        "[agent-config-db] Table 'agents' not found - database schema may need updating",
      );
    } else {
      console.error(
        "[agent-config-db] Database query failed:",
        error instanceof Error ? error.message : String(error),
      );
    }
    return null;
  } finally {
    if (client) {
      client.release();
    }
  }
}

/**
 * Check if a string value is effectively empty (null, undefined, empty string, or whitespace-only)
 */
function isEffectivelyEmpty(value: any): boolean {
  if (value === null || value === undefined) {
    return true;
  }
  if (typeof value === "string" && value.trim() === "") {
    return true;
  }
  return false;
}

/**
 * Main hook handler
 *
 * Receives an InternalHookEvent from OpenClaw with shape:
 *   { type, action, sessionKey, context: { agentId, model, thinking, ... } }
 */
export default async function handler(event: Record<string, any>) {
  // Only handle session:pre-spawn and agent:pre-run events
  if (
    !(
      (event.type === "session" && event.action === "pre-spawn") ||
      (event.type === "agent" && event.action === "pre-run")
    )
  ) {
    return;
  }

  const agentId = event.context?.agentId;

  // Enforce agentId presence — block spawn if missing
  if (!agentId || (typeof agentId === "string" && agentId.trim() === "")) {
    console.error(
      "[agent-config-db] agentId is required when hook is active — spawn blocked",
    );
    console.error(
      "[agent-config-db] Pass explicit agentId to sessions_spawn to prevent wrong config application",
    );
    event.context.blocked = true;
    event.context.blockReason =
      "agentId is required when agent-config-db hook is active — pass agentId to sessions_spawn";
    return;
  }

  const agentName = agentId.trim();

  // Query database for agent config
  const config = await loadFromDatabase(agentName);

  if (!config) {
    // No config found or database error — proceed without mutation
    return;
  }

  // Apply non-null, non-empty values from database (authoritative override)
  const updates: string[] = [];

  if (!isEffectivelyEmpty(config.model)) {
    event.context.model = config.model;
    updates.push(`model=${config.model}`);
  }

  if (!isEffectivelyEmpty(config.fallbackModel)) {
    event.context.fallbackModel = config.fallbackModel;
    updates.push(`fallbackModel=${config.fallbackModel}`);
  }

  if (!isEffectivelyEmpty(config.thinking)) {
    event.context.thinking = config.thinking;
    updates.push(`thinking=${config.thinking}`);
  }

  if (updates.length > 0) {
    console.log(`[agent-config-db] Applied config for ${agentName}: ${updates.join(", ")}`);
  } else {
    console.log(`[agent-config-db] Agent ${agentName} found in DB but all config values are NULL`);
  }
}
