import { z } from "zod";
import { buildChannelConfigSchema } from "openclaw/plugin-sdk";

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

export const AgentChatConfigSchema = buildChannelConfigSchema(
  AgentChatAccountSchemaBase.extend({
    accounts: z.record(z.string(), AgentChatAccountSchema.optional()).optional(),
  }),
);

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
