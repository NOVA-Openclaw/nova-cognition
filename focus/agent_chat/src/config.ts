import { z } from "zod";
import type { ChannelConfigSchema } from "openclaw/plugin-sdk";

/**
 * Zod schema for agent_chat account configuration
 */
export const AgentChatAccountSchemaBase = z
  .object({
    name: z.string().optional(),
    enabled: z.boolean().optional(),
    agentName: z.string(),
    database: z.string(),
    host: z.string(),
    port: z.number().int().positive().optional().default(5432),
    user: z.string(),
    password: z.string(),
    pollIntervalMs: z.number().int().positive().optional().default(1000),
  })
  .strict();

export const AgentChatAccountSchema = AgentChatAccountSchemaBase;

// Create the full config schema with accounts - use passthrough to avoid strict schema issues
const AgentChatFullSchema = z.object({
  name: z.string().optional(),
  enabled: z.boolean().optional(),
  agentName: z.string(),
  database: z.string(),
  host: z.string(),
  port: z.number().int().positive().optional().default(5432),
  user: z.string(),
  password: z.string(),
  pollIntervalMs: z.number().int().positive().optional().default(1000),
  accounts: z.record(z.string(), AgentChatAccountSchema.optional()).optional(),
}).passthrough();

// Manually construct the ChannelConfigSchema to avoid Zod type casting issues
export const AgentChatConfigSchema: ChannelConfigSchema = {
  schema: {
    type: "object",
    properties: {
      name: { type: "string" },
      enabled: { type: "boolean" },
      agentName: { type: "string" },
      database: { type: "string" },
      host: { type: "string" },
      port: { type: "integer", default: 5432 },
      user: { type: "string" },
      password: { type: "string" },
      pollIntervalMs: { type: "integer", default: 1000 },
      accounts: {
        type: "object",
        additionalProperties: {
          type: "object",
          properties: {
            name: { type: "string" },
            enabled: { type: "boolean" },
            agentName: { type: "string" },
            database: { type: "string" },
            host: { type: "string" },
            port: { type: "integer" },
            user: { type: "string" },
            password: { type: "string" },
            pollIntervalMs: { type: "integer" },
          },
        },
      },
    },
    required: ["agentName", "database", "host", "user", "password"],
  },
};

export type ResolvedAgentChatAccount = {
  accountId: string;
  name: string;
  enabled: boolean;
  config: {
    agentName: string;
    database: string;
    host: string;
    port: number;
    user: string;
    password: string;
    pollIntervalMs: number;
  };
};
