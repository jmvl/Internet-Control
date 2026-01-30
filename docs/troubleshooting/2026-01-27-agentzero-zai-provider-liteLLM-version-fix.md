# Agent Zero - Z.ai Provider "LLM Provider NOT provided" Fix

**Issue Date**: 2026-01-27
**Resolution Date**: 2026-01-27
**Impact**: Agent Zero unable to use Z.ai GLM-4.7 model
**Affected Service**: Agent Zero (agent-zero container on PCT-111)

## Problem Description

Agent Zero was unable to use the Z.ai GLM-4.7 model despite correct configuration. The error occurred immediately after attempting to use the configured model.

### Error Message

```
litellm.BadRequestError: LLM Provider NOT provided. You passed model=zai/glm-4.7
 Pass model as E.g. For 'Huggingface' inference endpoints pass in `completion(model='huggingface/starcamer',..)`
 Learn more: https://docs.litellm.ai/docs/providers
```

### Error Location

- **File**: `/a0/agent.py`
- **Line**: 417
- **Function**: `monologue`

### Stack Trace

```
File "/a0/agent.py", line 417, in monologue
  agent_response, _reasoning = await self.call_chat_model(
File "/a0/agent.py", line 741, in call_chat_model
  response, reasoning = await model.unified_call(
File "/a0/models.py", line 502, in unified_call
  _completion = await acompletion(
File "/opt/venv-a0/lib/python3.12/site-packages/litellm/utils.py", line 1638, in wrapper_async
  raise e
File "/opt/venv-a0/lib/python3.12/site-packages/litellm/utils.py", line 1484, in wrapper_async
  result = await original_function(*args, **kwargs)
File "/opt/venv-a0/lib/python3.12/site-packages/litellm/main.py", line 552, in acompletion
  _, custom_llm_provider, _, _ = get_llm_provider(
File "/opt/venv-a0/lib/python3.12/site-packages/litellm/litellm_core_utils/get_llm_provider_logic.py", line 421, in get_llm_provider
  raise e
File "/opt/venv-a0/lib/python3.12/site-packages/litellm/litellm_core_utils/get_llm_provider_logic.py", line 398, in get_llm_provider
  raise litellm.exceptions.BadRequestError
```

## Root Cause Analysis

### Investigation Process

1. **Configuration Verification**
   - Verified `/a0/conf/model_providers.yaml` had correct `litellm_provider: zai`
   - Verified `/a0/.env` had correct `ZAI_API_KEY` environment variable
   - Verified model name format was correct: `zai/glm-4.7`
   - All configuration was correct

2. **LiteLLM Version Check**
   ```bash
   docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/ | grep -i litellm
   # Found: litellm-1.79.3.dist-info (dated Nov 19, 2025)
   ```

3. **Provider Search**
   ```bash
   docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/litellm/llms/ | grep -i zai
   # NO zai directory found
   ```

4. **LiteLLM Documentation Research**
   - Checked [LiteLLM Z.ai Provider Documentation](https://docs.litellm.ai/docs/providers/zai)
   - Confirmed `zai/glm-4.7` with `ZAI_API_KEY` is the correct format

5. **GitHub Research**
   - Searched for when `zai` provider was added to LiteLLM
   - Found commit [965406c](https://github.com/BerriAI/litellm/commit/965406c) dated **December 2, 2025**
   - Commit title: "feat(provider): add Z.AI (Zhipu AI) as built-in provider (#17307)"

### Root Cause

The Agent Zero container was running **LiteLLM version 1.79.3** from **November 19, 2025**, but the `zai` provider was not added to LiteLLM until **December 2, 2025** (commit 965406c, version 1.81.0+).

**Timeline**:
- **Nov 19, 2025**: Agent Zero container created with LiteLLM 1.79.3
- **Dec 2, 2025**: `zai` provider added to LiteLLM (version 1.81.0+)
- **Jan 27, 2026**: Attempted to configure Z.ai model with outdated LiteLLM

## Solution

### Upgrade LiteLLM

1. **SSH to Docker Host**
   ```bash
   ssh root@192.168.1.20
   ```

2. **Upgrade LiteLLM in Container's Virtual Environment**
   ```bash
   docker exec agent-zero /opt/venv-a0/bin/pip install --upgrade litellm
   ```

   **Output**:
   ```
   Requirement already satisfied: litellm in /opt/venv-a0/lib/python3.12/site-packages (1.79.3)
   Collecting litellm
     Downloading litellm-1.81.3-py3-none-any.whl (2.3 MB)
   Installing collected packages: litellm
   Attempting uninstall: litellm
     Found existing installation: litellm 1.79.3
     Uninstalling litellm-1.79.3:
       Successfully uninstalled litellm-1.79.3
   Successfully installed litellm-1.81.3
   ```

3. **Restart Container**
   ```bash
   docker restart agent-zero
   ```

4. **Verify Upgrade**
   ```bash
   # Check LiteLLM version
   docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/ | grep -i litellm
   # Should show: litellm-1.81.3.dist-info

   # Verify zai provider exists
   docker exec agent-zero ls -la /opt/venv-a0/lib/python3.12/site-packages/litellm/llms/ | grep -i zai
   # Should show: zai directory
   ```

### Verification Results

After upgrade and restart:
```bash
drwxr-xr-x 37 root root   4096 Jan 27 14:29 litellm
drwxr-xr-x  2 root root   4096 Jan 27 14:29 litellm-1.81.3.dist-info
drwxr-xr-x   4 root root 4096 Jan 27 14:29 zai
```

### Additional Notes

**Dependency Conflict Warning**:
```
ERROR: pip's dependency resolver does not currently take into account all the packages that are installed.
browser-use 0.5.11 requires openai==1.99.2, but you have openai 2.15.0 which is incompatible.
```

This warning indicates that `browser-use` requires `openai==1.99.2` but LiteLLM 1.81.3 requires `openai>=2.15.0`. This may cause issues if the `browser-use` extension is used in Agent Zero.

## Resolution

✅ **RESOLVED**: Z.ai provider is now available in LiteLLM
- LiteLLM upgraded from version 1.79.3 to 1.81.3
- `zai` provider directory exists in `/opt/venv-a0/lib/python3.12/site-packages/litellm/llms/`
- Container restarted successfully
- ✅ **Authentication working**: API key accepted by Z.ai
- ✅ **Connection successful**: Communicating with Z.ai API

## Follow-Up Issue: Rate Limiting

### New Error (2026-01-27 14:35 UTC)

After fixing the provider issue, encountered a new error:

```
litellm.RateLimitError: RateLimitError: ZaiException - High concurrency usage of this API,
please reduce concurrency or contact customer service to increase limits
```

**Error Details**:
- **Error Code**: 1302
- **Type**: Rate limit error from Z.ai API
- **Message**: "High concurrency usage of this API, please reduce concurrency or contact customer service to increase limits"

**Analysis**:
- ✅ This confirms the `zai` provider fix was successful
- ✅ Authentication is working (API key valid)
- ✅ Connection to Z.ai API is established
- ⚠️ Z.ai API has concurrency/rate limits in place

**Potential Solutions**:
1. **Reduce concurrency** in Agent Zero settings (if available)
2. **Contact Z.ai customer service** to increase rate limits
3. **Add retry logic with exponential backoff** for rate-limited requests
4. **Use a different model/provider** for high-concurrency operations

**Status**: Documented - requires further investigation

## Testing Required

To verify the fix works completely:

1. Navigate to **https://agentzero.acmea.tech**
2. Start a new chat
3. Send a test message that requires memory (e.g., "Remember my favorite color is blue")
4. In a new chat, ask: "What is my favorite color?"
5. Verify:
   - Responses are generated without "LLM Provider NOT provided" errors
   - Memory is stored and retrieved correctly
   - `recall_memories` extension functions properly with the Utility Model

## Related Documentation

- [Agent Zero Z.ai GLM-4.7 Configuration](/docs/agentzero/zai-glm-4.7-configuration.md) - Updated with this troubleshooting section
- [LiteLLM Z.ai Provider Documentation](https://docs.litellm.ai/docs/providers/zai)
- [GitHub Commit 965406c](https://github.com/BerriAI/litellm/commit/965406c) - Added Z.ai provider to LiteLLM

## Lessons Learned

1. **Version Compatibility**: Always verify that the LiteLLM version supports the provider you're configuring
2. **Container Images**: Docker containers may have outdated dependencies even if they're pulled as "latest"
3. **Provider Addition Timeline**: New providers are added to LiteLLM regularly - check the [LiteLLM changelog](https://github.com/BerriAI/litellm/commits/main) if a provider isn't available
4. **Verification Steps**: Always verify the provider directory exists in the LiteLLM installation after troubleshooting configuration issues
