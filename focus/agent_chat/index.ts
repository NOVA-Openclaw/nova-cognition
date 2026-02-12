import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { agentChatPlugin } from "./src/channel.js";
import { setAgentChatRuntime } from "./src/runtime.js";
import { AgentChatConfigSchema } from "./src/config.js";

const plugin = {
  id: "agent_chat",
  name: "Agent Chat",
  description: "PostgreSQL-based inter-agent communication channel",
  configSchema: AgentChatConfigSchema,
  register(api: OpenClawPluginApi) {
    setAgentChatRuntime(api.runtime);
    api.registerChannel({ plugin: agentChatPlugin });
  },
};

export default plugin;
