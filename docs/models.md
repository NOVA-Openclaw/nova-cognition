# AI Model Reference

Model capabilities and recommendations for agent deployment.

## Model Registry

| Model ID | Provider | Display Name | Context | Cost | Strengths | Available |
|----------|----------|--------------|---------|------|-----------|-----------|
| anthropic/claude-opus-4-5 | anthropic | Claude Opus 4.5 | 200K | premium | reasoning, coding, analysis, creative | ✅ |
| anthropic/claude-sonnet-4-5 | anthropic | Claude Sonnet 4.5 | 200K | moderate | coding, general, fast | ✅ |
| anthropic/claude-sonnet-4-0 | anthropic | Claude Sonnet 4.0 | 200K | moderate | coding, general | ✅ |
| anthropic/claude-haiku-3-5 | anthropic | Claude Haiku 3.5 | 200K | cheap | fast, simple-tasks, high-volume | ✅ |
| google/gemini-2.5-flash | google | Gemini 2.5 Flash | 1M | cheap | fast, long-context, research | ✅ |
| google/gemini-2.0-flash | google | Gemini 2.0 Flash | 1M | cheap | fast, long-context | ✅ |
| google/gemini-2.0-pro | google | Gemini 2.0 Pro | 1M | moderate | reasoning, multimodal, long-context | ❌ |
| google/gemini-1.5-pro | google | Gemini 1.5 Pro | 2M | moderate | long-context, multimodal | ✅ |
| openai/gpt-4o | openai | GPT-4o | 128K | moderate | multimodal, general, fast | ✅ |
| openai/gpt-4o-mini | openai | GPT-4o Mini | 128K | cheap | fast, simple-tasks | ❌ |
| openai/gpt-4-turbo | openai | GPT-4 Turbo | 128K | moderate | general, coding | ❌ |
| openai/o1 | openai | o1 | 128K | premium | reasoning, math, coding | ❌ |
| openai/o1-mini | openai | o1 Mini | 128K | moderate | reasoning, math | ❌ |
| deepseek/deepseek-v3 | deepseek | DeepSeek V3 | 128K | cheap | coding, reasoning, cost-effective | ❌ |
| mistral/mistral-large | mistral | Mistral Large | 128K | moderate | multilingual, coding, general | ❌ |
| mistral/codestral | mistral | Codestral | 32K | cheap | coding, fast | ❌ |
| meta/llama-3.1-405b | meta | Llama 3.1 405B | 128K | moderate | open-source, general, coding | ❌ |
| xai/grok-2 | xai | Grok 2 | 128K | premium | realtime, uncensored | ❌ |

## Cost Tiers

| Tier | Description | Use Cases |
|------|-------------|-----------|
| **premium** | Highest capability, highest cost | Complex reasoning, critical tasks, creative work |
| **moderate** | Balanced capability/cost | General tasks, coding, daily operations |
| **cheap** | Cost-effective, good for volume | Quick queries, simple tasks, research sweeps |

## Model Selection Guidelines

### By Task Type

| Task | Recommended Models |
|------|-------------------|
| Complex reasoning | claude-opus-4-5, o1 |
| Coding | claude-sonnet-4-5, codestral, deepseek-v3 |
| Quick Q&A | gemini-2.0-flash, gpt-4o-mini, haiku |
| Research | gemini-2.5-flash (long context) |
| Creative writing | claude-opus-4-5 |
| Multimodal | gpt-4o, gemini-2.0-pro |
| Long documents | gemini-1.5-pro (2M context) |

### By Agent Role

| Agent Role | Primary Model | Fallback |
|------------|---------------|----------|
| MCP/Orchestrator | claude-opus-4-5 | claude-sonnet-4-5 |
| Coding | claude-sonnet-4-5 | gpt-4o |
| Research | gemini-2.5-flash | claude-sonnet-4-5 |
| Quick QA | gemini-2.0-flash | haiku |
| Git Operations | claude-sonnet-4-0 | gpt-4o |
| Creative | claude-sonnet-4-5 | gpt-4o |
| Media Curation | gemini-2.0-flash | claude-sonnet-4-0 |

## Notes

- **Available** = Configured and tested in current deployment
- Context windows are maximum; actual usable context may vary
- Cost tiers are relative; actual pricing varies by provider
- Some models require specific API access or agreements

---

*Data sourced from NOVA's `ai_models` table, maintained by Newhart.*
