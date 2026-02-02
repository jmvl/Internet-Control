# OpenClaw WebSocket Connection Errors - Domain Migration Fix

**Date**: 2026-01-30
**Container**: openclaw (VMID: 101)
**IP Address**: 192.168.1.151
**Issue**: WebSocket connection failures after domain migration from `moltbot.acmea.tech` to `openclaw.acmea.tech`

---

## Executive Summary

After migrating from `moltbot.acmea.tech` to `openclaw.acmea.tech`, WebSocket connections from the old domain were failing with schema validation errors. The root cause was that both Nginx Proxy Manager proxy hosts and Cloudflare DNS records remained active for the old domain, causing client connections to be rejected.

**Resolution**: Deleted the old proxy host and DNS record. Service now fully operational on `https://openclaw.acmea.tech`.

---

## Symptoms

### Error Logs
```log
Jan 30 16:54:39 openclaw node[69204]: 2026-01-30T16:54:39.757Z [ws] closed before connect
conn=1cf2ebd9-71c2-4ff7-9897-b69386876768
remote=192.168.1.121
fwd=77.109.112.226, 104.23.241.19
origin=https://moltbot.acmea.tech
host=moltbot.acmea.tech
ua=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36
code=1008
reason=invalid connect params: at /client/id: must be equal to constant; at /client/id: must match a schema in anyOf
```

### Key Indicators
- **WebSocket code 1008**: Policy violation - connection rejected
- **Origin header**: `moltbot.acmea.tech` (old domain)
- **Error pattern**: Occurred every ~16 seconds (client retry interval)
- **Affected clients**: Browsers/cached connections to old domain

---

## Root Cause Analysis

### Phase 1: Investigation

1. **Checked Gateway Health**:
   ```bash
   ssh root@192.168.1.151 "npx openclaw gateway health"
   # Output: Gateway Health OK, Telegram: ok
   ```
   Gateway was healthy - issue was not with OpenClaw itself.

2. **Checked Nginx Proxy Manager**:
   ```bash
   curl -s https://nginx.home.accelior.com/api/nginx/proxy-hosts \
     -H "Authorization: Bearer $NPM_API_TOKEN"
   ```
   Found **both** proxy hosts active:
   - ID 50: `moltbot.acmea.tech` → 192.168.1.151:18789
   - ID 52: `openclaw.acmea.tech` → 192.168.1.151:18789

3. **Checked Cloudflare DNS**:
   ```bash
   flarectl dns list --zone acmea.tech | rg -i "moltbot"
   ```
   Old DNS record still active:
   ```
   cf6dce09f2e7d6397a25774db99187b6 | CNAME | moltbot.acmea.tech | base.acmea.tech
   ```

### Root Cause

The old domain `moltbot.acmea.tech` remained fully operational through:
1. **Nginx Proxy Manager**: Proxy host still routing traffic to backend
2. **Cloudflare DNS**: CNAME record still resolving the domain

When clients connected via the old domain, the OpenClaw gateway rejected the WebSocket connection due to domain-specific client ID validation schema mismatch.

---

## Resolution

### Step 1: Delete NPM Proxy Host
```bash
curl -s -X DELETE https://nginx.home.accelior.com/api/nginx/proxy-hosts/50 \
  -H "Authorization: Bearer $NPM_API_TOKEN"
# Response: true (success)
```

### Step 2: Delete Cloudflare DNS Record
```bash
export CF_API_TOKEN="RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA"
flarectl dns delete --zone acmea.tech --id cf6dce09f2e7d6397a25774db99187b6
```

### Step 3: Verify Cleanup
```bash
# Verify NPM proxy host deleted (should return 404)
curl -s https://nginx.home.accelior.com/api/nginx/proxy-hosts/50 \
  -H "Authorization: Bearer $NPM_API_TOKEN"
# {"error":{"code":404,"message":"Not Found - 50"}}

# Verify DNS deleted
flarectl dns list --zone acmea.tech | rg -i "moltbot"
# (no results)

# Verify only new domain remains
flarectl dns list --zone acmea.tech | rg -i "openclaw"
# 62ab83f0427a4f499c694d87f1e8b1bb | CNAME | openclaw.acmea.tech | base.acmea.tech
```

---

## Verification

### Before Fix
```log
[ws] closed before connect ... origin=https://moltbot.acmea.tech ... code=1008
```

### After Fix
```bash
curl -sI https://openclaw.acmea.tech
# HTTP/2 200
# x-served-by: openclaw.acmea.tech
```

```log
# New successful WebSocket connection:
Jan 30 17:15:03 openclaw node[69204]: 2026-01-30T17:15:03.002Z [ws] webchat connected
conn=7ae5a99e-51c4-47b4-9a9f-348260354cf3
remote=192.168.1.121
client=openclaw-control-ui webchat vdev
```

---

## Configuration Reference

### Working Proxy Host (openclaw.acmea.tech)

| Property | Value |
|----------|-------|
| **ID** | 52 |
| **Domain** | openclaw.acmea.tech |
| **Forward Host** | 192.168.1.151 |
| **Forward Port** | 18789 |
| **Scheme** | http |
| **SSL Forced** | false |
| **HTTP2 Support** | false |
| **WebSocket Upgrade** | true |
| **Enabled** | true |

---

## Lessons Learned

### Domain Migration Checklist

When migrating a service to a new domain:

1. **Create new proxy host** in Nginx Proxy Manager
2. **Create new DNS record** in Cloudflare
3. **Test new domain** thoroughly
4. **DELETE old proxy host** from Nginx Proxy Manager
5. **DELETE old DNS record** from Cloudflare
6. **Clear browser cache** or close old tabs
7. **Monitor logs** for old domain connection attempts

### Monitoring for Stale Connections

After domain migration, monitor logs for old domain connections:
```bash
ssh root@192.168.1.151 "journalctl --user -u openclaw-gateway -f | grep 'origin='"
```

---

## Related Documentation

- [OpenClaw README](/docs/openclaw/README.md)
- [Telegram Streaming Investigation](/docs/openclaw/telegram-streaming-investigation-2026-01-30.md)
- [Infrastructure Database](/docs/infrastructure-db/README.md)

---

**Report Created**: 2026-01-30T17:17:00Z
**Created By**: Claude Code
**Status**: RESOLVED
