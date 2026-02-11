import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk";
import { agentChatPlugin } from "./src/channel.js";
import { setAgentChatRuntime } from "./src/runtime.js";

const plugin = {
  id: "agent_chat",
  name: "Agent Chat",
  description: "PostgreSQL-based agent messaging channel plugin",
  configSchema: emptyPluginConfigSchema(),
  register(api: OpenClawPluginApi) {
    setAgentChatRuntime(api.runtime);
    api.registerChannel({ plugin: agentChatPlugin });
  },
};

export default plugin;
