# Agent Zero - Z.ai GLM-4.7 Configuration

**Configuration Date**: 2026-01-27
**Status**: Backend configured, UI selection required

## Overview

This document describes the configuration of Agent Zero to use Z.ai's (Zhipu AI) GLM-4.7 LLM model via LiteLLM.

**Important**: LiteLLM uses `zai` as the provider name for Z.ai (Zhipu AI).

## Agent Zero's Three-Model Architecture

**CRITICAL**: Agent Zero requires **THREE separate model configurations**, not just one:

| Model Type | Purpose | When Used | Required For |
|------------|---------|-----------|--------------|
| **Chat Model** | Primary reasoning engine | Complex tasks, main conversations | Basic chat functionality |
| **Utility Model** | Lightweight processing | Memory summarization, context compression, quick lookups | **recall_memories extension** |
| **Embedding Model** | Text-to-vector conversion | Memory search, semantic similarity | Memory retrieval |

**Common Error**: Configuring only the Chat Model causes extensions like `recall_memories` to fail with "LLM Provider NOT provided" errors because they use the Utility Model.

## Backend Configuration

### Provider Configuration

**File**: `/a0/conf/model_providers.yaml` (in container)

```yaml
zai:
  name: Z.ai
  litellm_provider: zai
```

**Note**: The provider key is `zai` (for the UI) and `litellm_provider` is also `zai` (LiteLLM's provider name for Zhipu AI).

### API Key Configuration

**File**: `/a0/.env` (in container)

```bash
ZAI_API_KEY=05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25
```

**Source**: The API key is also stored in `/Users/jm/Codebase/internet-control/.env.local` on the local machine.

**Environment Variable**: `ZAI_API_KEY` (LiteLLM standard for Z.ai/Zhipu AI)

## Available Models

Based on Z.ai's GLM-4.7 model family, the following models are available:

**IMPORTANT**: When Z.ai is selected as a provider in Agent Zero, enter model names WITHOUT the `zai/` prefix (Agent Zero adds it automatically based on the provider configuration).

| Model Name to Enter | Actual Model Called | Description | Best For |
|---------------------|-------------------|-------------|----------|
| `glm-4.7` | `zai/glm-4.7` | Full GLM-4.7 model | Chat Model - complex tasks, best quality |
| `glm-4.7-flash` | `zai/glm-4.7-flash` | Faster GLM-4.7 variant | Utility Model - quick responses, real-time |
| `glm-4.7-plus` | `zai/glm-4.7-plus` | Enhanced capabilities | Advanced reasoning tasks |
| `glm-4.7-air` | `zai/glm-4.7-air` | Lightweight version | Simple tasks, lower cost |

**Model Recommendations**:
- **Chat Model**: Use `glm-4.7` for best quality on complex reasoning tasks
- **Utility Model**: Use `glm-4.7-flash` for fast, lightweight processing (memory summarization)
- **Embedding Model**: Z.ai does not provide embedding models - use OpenAI, HuggingFace, or another provider

## UI Configuration Steps

To enable Z.ai in Agent Zero:

1. Navigate to **https://agentzero.acmea.tech**
2. Click the **Settings** button
3. Select the **Agent Settings** tab
4. Configure the following:

   ### Step 1: Chat Model Configuration
   - **Chat Provider**: Select `Z.ai`
   - **Chat Model**: Enter `glm-4.7` (without `zai/` prefix)

   ### Step 2: Utility Model Configuration (REQUIRED for recall_memories)
   - **Utility Provider**: Select `Z.ai`
   - **Utility Model**: Enter `glm-4.7-flash` (without `zai/` prefix)

   ### Step 3: Embedding Model Configuration
   - **Embedding Provider**: Select a provider that supports embeddings (e.g., `OpenAI`, `HuggingFace`)
   - **Embedding Model**: Enter the embedding model name (e.g., `text-embedding-3-small` for OpenAI)

5. Click **Save** to apply settings

⚠️ **Common Mistake**: Do NOT enter `zai/glm-4.7` or `zhipu/glm-4.7` as the model name when Z.ai is already selected as the provider. Just enter `glm-4.7` or `glm-4.7-flash`.

⚠️ **Critical**: ALL THREE model types must be configured for full functionality. The `recall_memories` extension specifically requires the Utility Model to be configured.

## Configuration Verification

To verify the configuration is working:

1. Start a new chat
2. Send a test message that requires memory (e.g., "Remember my favorite color is blue")
3. In a new chat, ask: "What is my favorite color?"
4. Check that:
   - Responses are generated without authentication errors
   - Memory is stored and retrieved correctly
   - No "LLM Provider NOT provided" errors in logs

## Troubleshooting

### Error: "LLM Provider NOT provided" in recall_memories extension

**Full Error**: `LLMProviderException: LLM Provider NOT provided. You passed model=zai/glm-4.7-flash`

**Cause**: Utility Model is not configured. The `recall_memories` extension uses the Utility Model, not the Chat Model.

**Solution**:
1. Navigate to **Settings → Agent Settings**
2. Find the **Utility Provider** section
3. Select `Z.ai` as the Utility Provider
4. Enter `glm-4.7-flash` as the Utility Model (no prefix)
5. Click **Save**
6. Test the recall_memories extension again

### Error: "LLM Provider NOT provided" with `zai/glm-4.7-flash`

**Cause**: Model name entered incorrectly in UI (included prefix when provider already selected).

**Solution**:
- When Z.ai is selected as the provider, enter just `glm-4.7` or `glm-4.7-flash` (no prefix)
- Do NOT enter `zai/glm-4.7`

### Error: "AuthenticationError"

**Cause**: API key not properly configured or wrong environment variable name.

**Solution**:
1. Verify `ZAI_API_KEY` exists in `/a0/.env`
2. Check that `litellm_provider: zai` in `/a0/conf/model_providers.yaml`
3. Check that Z.ai is selected in Agent Settings for the appropriate model type
4. Restart container: `ssh root@192.168.1.20 'docker restart agent-zero'`

### Error: "LLM Provider NOT provided. You passed model=zai/zai/glm-4.7"

**Cause**: Double prefix in model name.

**Solution**: Enter model name without any prefix (just `glm-4.7`) when Z.ai is selected as provider.

### Error: Embedding model not working with Z.ai

**Cause**: Z.ai (Zhipu AI) does not provide embedding models.

**Solution**: Use a different provider for embeddings:
1. In **Settings → Agent Settings**
2. Find **Embedding Provider**
3. Select `OpenAI` or `HuggingFace`
4. Enter appropriate embedding model (e.g., `text-embedding-3-small` for OpenAI)

### Error: "LLM Provider NOT provided" despite correct configuration

**Full Error**: `litellm.BadRequestError: LLM Provider NOT provided. You passed model=zai/glm-4.7`

**Cause**: LiteLLM version is too old and doesn't include the `zai` provider. The `zai` provider was added to LiteLLM on December 2, 2025 (commit 965406c). If your container was created before this date, you need to upgrade LiteLLM.

**Solution**: Upgrade LiteLLM to version 1.81.0 or later:
```bash
# SSH to docker host
ssh root@192.168.1.20

# Upgrade LiteLLM in the container's virtual environment
docker exec agent-zero /opt/venv-a0/bin/pip install --upgrade litellm

# Restart container to load new version
docker restart agent-zero

# Verify the upgrade
docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/ | grep -i litellm
# Should show: litellm-1.81.x.dist-info

# Verify zai provider exists
docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/litellm/llms/ | grep -i zai
# Should show: zai directory
```

**Verification**: After upgrading, you should see:
- `litellm-1.81.x.dist-info` directory in site-packages
- `zai` directory in `/opt/venv-a0/lib/python3.12/site-packages/litellm/llms/`

### Error: Rate limit from Z.ai API (Error Code 1302)

**Full Error**: `litellm.RateLimitError: RateLimitError: ZaiException - High concurrency usage of this API, please reduce concurrency or contact customer service to increase limits`

**Error Code**: 1302

**Cause**: Z.ai API has concurrency/rate limits in place. This error occurs when too many requests are made simultaneously.

**Note**: This error actually indicates that the configuration is working correctly - you're successfully communicating with Z.ai's API, but you've hit their rate limits.

**Solutions**:
1. **Wait and retry**: Rate limits are usually temporary. Wait a few seconds and try again.
2. **Reduce concurrency**: If Agent Zero has concurrency settings, reduce the number of simultaneous requests.
3. **Contact Z.ai**: Contact Z.ai customer service to increase your rate limits if you need higher throughput.
4. **Use different models**: Consider using a different provider for high-concurrency operations.

## Container Information

| Property | Value |
|----------|-------|
| **Container Name** | `agent-zero` |
| **Docker Host** | PCT-111 (192.168.1.20) |
| **Internal Port** | 80 |
| **Published Port** | 50080 |
| **Public URL** | https://agentzero.acmea.tech |
| **Image** | agent0ai/agent-zero:latest |

## Maintenance

### Update Model Providers

```bash
# SSH to docker host
ssh root@192.168.1.20

# Edit providers configuration
docker exec -it agent-zero vi /a0/conf/model_providers.yaml

# Restart container
docker restart agent-zero
```

### Update API Key

```bash
# SSH to docker host
ssh root@192.168.1.20

# Update .env file
docker exec -it agent-zero sh -c 'echo "ZHIPUAI_API_KEY=<new-key>" >> /a0/.env'

# Restart container
docker restart agent-zero
```

### View Current Configuration

```bash
# SSH to docker host
ssh root@192.168.1.20

# View providers configuration
docker exec -it agent-zero cat /a0/conf/model_providers.yaml

# View API key (redacted)
docker exec -it agent-zero sh -c 'echo $ZHIPUAI_API_KEY'
```

## Technical Details

### LiteLLM Provider Mapping

Agent Zero uses LiteLLM for provider abstraction. The mapping is:

| Agent Zero UI | LiteLLM Provider | Environment Variable | Supports Embeddings |
|---------------|------------------|---------------------|-------------------|
| `Z.ai` | `zai` | `ZAI_API_KEY` | No |

### Model Name Transformation

When you configure in the UI:
- **Provider**: `Z.ai`
- **Model**: `glm-4.7`

Agent Zero transforms this to LiteLLM call:
- **Provider**: `zai`
- **Model**: `zai/glm-4.7`

This is why you must NOT include the prefix in the UI - it's added automatically based on the provider configuration.

### Three-Model Architecture Details

**Chat Model**:
- Primary reasoning engine
- Handles complex tasks and main conversations
- Recommended: `glm-4.7` for best quality
- Settings: **Chat Provider** + **Chat Model**

**Utility Model**:
- Lightweight processing for internal operations
- Used by extensions like `recall_memories`, `summarize_context`
- Recommended: `glm-4.7-flash` for speed
- Settings: **Utility Provider** + **Utility Model**

**Embedding Model**:
- Converts text to vectors for semantic search
- Required for memory retrieval and similarity search
- Z.ai does not support embeddings - use OpenAI, HuggingFace, etc.
- Settings: **Embedding Provider** + **Embedding Model**

## References

- [Z.ai (Zhipu AI) Documentation](https://docs.z.ai)
- [GLM-4.7 Overview](https://docs.z.ai/guides/llm/glm-4.7)
- [Agent Zero Documentation](https://docs.agent-zero.ai)
- [LiteLLM Zhipu AI Provider](https://docs.litellm.ai/docs/providers/zhipu)
- [Agent Zero Get Started Guide](https://docs.agent-zero.ai/guides/get-started)

## Related Documentation

- [Agent Zero Deployment](/docs/agentzero/README.md)
- [Infrastructure Database](/infrastructure-db/README.md)
- [Docker Host PCT-111](/docs/docker/pct-111-docker-setup.md)

---

*Last Updated: 2026-01-27 14:30 UTC - Added LiteLLM version requirement troubleshooting section*
