# Mission Control v3.4 - Changes & Improvements

## Overview

v3.4 clarifies the architecture by explicitly defining the **two-layer system**:
1. **Orchestration Layer** (Nestor, the AI agent)
2. **Technical Layer** (MC_Service, the Gateway service)

This distinction was unclear in v3.3, leading to confusion about who coordinates agents.

---

## Key Changes

### 1. Nestor Orchestrator Agent (NEW)

**Problem in v3.3:** Missing explicit AI orchestrator specification. PRD described technical `MC_Service` but didn't define how AI coordination works.

**Solution in v3.4:**
- **Section 3:** Complete specification of Nestor as Squad Lead AI agent
- **Section 6:** Full SOUL.md template for Nestor
- **Section 3.3:** Task delegation workflow (Human → Nestor → Specialists)
- **Section 3.4:** Agent-to-agent communication rules (what's allowed, what needs Nestor)
- **Section 3.5:** Conflict resolution strategies
- **Section 3.6:** Daily standup format and delivery

**Impact:** Developers now have clear spec for implementing the AI coordination layer.

---

### 2. OpenClaw-Native Architecture

**Problem in v3.3:** Risk of reinventing tools that OpenClaw already provides.

**Solution in v3.4:** Explicit instruction to use OpenClaw native tools:

| Feature | v3.3 Approach | v3.4 Approach |
|----------|----------------|----------------|
| **Agent-to-Agent Comms** | Custom mention system | Native `sessions_send` |
| **Agent Status** | Custom `agent_status` table | Native `sessions_list` + DB mirror |
| **Agent Spawning** | Custom implementation | Native `sessions_spawn` |
| **Pulse Scheduling** | Custom background process | Native `cron` |
| **Session Management** | Custom implementation | OpenClaw native |

**Code Examples in v3.4:**
```typescript
// Agent communication (use native tool)
await sessions_send({
  sessionKey: 'agent:frontend-agent:...',
  message: '@db-agent: Need /api/tasks endpoint'
});

// Agent monitoring (use native tool)
const sessions = await sessions_list();
const agents = sessions.filter(s => s.kind === 'agent');

// Daily standup scheduling (use native tool)
await cron.add({
  job: {
    name: 'nestor-daily-standup',
    schedule: { kind: 'cron', expr: '0 9 * * *' },
    payload: { kind: 'systemEvent', text: 'TRIGGER_DAILY_STANDUP' },
    sessionTarget: 'main'
  }
});
```

**Impact:** Faster development, less code to maintain, leverages OpenClaw's battle-tested tools.

---

### 3. Agent-to-Agent Communication

**Problem in v3.3:** No specification for how agents should communicate.

**Solution in v3.4:** Hybrid approach with clear rules:

✅ **Allowed (Direct via `sessions_send`):**
- Technical collaboration: "@Elena, need /api/tasks endpoint"
- Context sharing: "@Sophie, backend API is ready"
- Status updates: "@Igor, I found a bug in auth module"

❌ **Requires Nestor:**
- **Task creation** - All tasks must be created via Nestor
- **Strategic decisions** - Major decisions go through Nestor
- **Escalation** - Unresolved conflicts escalate to Nestor

**Logging:**
- All `sessions_send` calls logged to `task_events` table
- Nestor monitors all agent communication
- Full observability maintained

**Impact:** Efficient collaboration without losing oversight.

---

### 4. Database Schema Clarification

**Problem in v3.3:** `agent_status` table tracked `pgid` (process group ID), but OpenClaw manages process tracking.

**Solution in v3.4:**
- `agent_status` table is now a **mirror/cache** of OpenClaw's native sessions
- Primary source of truth is `sessions_list()` from OpenClaw
- MC_Service syncs agent status periodically from native sessions
- Removed `pgid` column (not needed - OpenClaw manages processes)

**New schema:**
```sql
CREATE TABLE agent_status (
    instance_id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    last_pulse DATETIME,
    current_task_id TEXT REFERENCES tasks(id),
    status TEXT DEFAULT 'idle',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP  -- NEW: Track when synced
);
```

**Impact:** Clear separation of concerns. OpenClaw manages processes, Mission Control mirrors state.

---

### 5. Phase 0: Nestor Orchestrator Setup (NEW)

**Problem in v3.3:** No dedicated phase for setting up the AI orchestrator.

**Solution in v3.4:** Added Phase 0 to phases.md:

**Tasks:**
1. Create Nestor's SOUL.md
2. Test `sessions_send` to all 5 specialist agents
3. Test `sessions_list` for agent monitoring
4. Test agent-to-agent communication (e.g., Sophie → Elena)
5. Configure daily standup cron job
6. Verify all specialists are accessible

**Duration:** ~2 hours
**Owner:** Nestor (main agent)

**Impact:** AI coordination layer verified before building technical infrastructure.

---

### 6. Daily Standup Automation

**Problem in v3.3:** Mentioned in guide but not specified in PRD.

**Solution in v3.4:** Complete specification:

**Format:** Markdown with sections:
- ✅ Completed Today
- 🔄 In Progress
- 🚫 Blocked
- 🎯 Key Decisions
- 📊 Metrics

**Delivery:**
- Via `message` tool to configured channel (Telegram)
- Also logged to `CHRONICLE.md`

**Trigger:**
- Cron job: `0 9 * * *` (9:00 AM daily)
- Nestor compiles and sends report

**Impact:** Human gets daily visibility into agent activity without asking.

---

### 7. Frontend Examples

**Added to v3.4:**
- Complete project structure for `mission-control-ui/`
- WebSocket hook example (`useWebSocket.ts`)
- RPC client example (`useMissionControl.ts`)
- Cyber-minimalist CSS design tokens
- Component breakdown

**Impact:** Frontend developer has clear implementation path.

---

### 8. Testing Strategy

**Added to v3.4:**
- Unit tests for MC_Service RPC methods
- Integration tests for Nestor orchestration
- E2E tests for complete workflow
- Code examples for each test type

**Impact:** Quality assurance team has clear testing framework.

---

## Architecture Comparison

### v3.3 Architecture

```
Human → UI → MC_Service → DB
              ↓
         (missing AI orchestrator)
              ↓
         Agents (uncoordinated)
```

**Problems:**
- No AI layer to coordinate agents
- Agents work independently
- Task delegation undefined
- No conflict resolution

---

### v3.4 Architecture

```
Human → UI → MC_Service → DB
  ↓                 ↑
Nestor (AI) ←→ WebSocket broadcasts
  ↓
sessions_send → Specialist Agents → Native Tools
  ↓
sessions_list (monitor status)
```

**Benefits:**
- AI orchestrator coordinates agents
- Direct agent communication via native tools
- Full observability via task_events
- Strategic decision making
- Conflict resolution

---

## Implementation Path

### v3.3 Path
```
Phase 1: Environment
  ↓
Phase 2: Database
  ↓
Phase 3: Backend
  ↓
Phase 4: Orchestrator (but missing AI spec)
  ↓
Phase 5: Frontend
  ↓
...
```

**Risk:** Phase 4 would fail - no AI orchestrator spec to implement.

---

### v3.4 Path
```
Phase 0: Nestor Setup ← NEW: Configure AI orchestrator first
  ↓
Phase 1: Environment
  ↓
Phase 2: Database
  ↓
Phase 3: Backend (use native tools)
  ↓
Phase 4: Orchestrator (Nestor now configured)
  ↓
Phase 5: Frontend (parallel with Phase 3)
  ↓
...
```

**Benefit:** Clear path with AI orchestrator verified upfront.

---

## Migration from v3.3 to v3.4

If you've started implementing v3.3, here's how to adapt:

### For Backend Developers (Elena-DBA):
1. **No change to database schema** - tables are compatible
2. **Remove custom pulse scheduling** - Use `cron` instead
3. **Remove mention parsing** - Use native `sessions_send`
4. **Update `agent_status` table** - Remove `pgid`, add `updated_at`

### For Frontend Developers (Sophie-FE):
1. **No change** - WebSocket API unchanged
2. **Reference new examples** in v3.4 Section 8

### For Orchestrator (Nestor):
1. **Read Section 6** - Complete SOUL.md template
2. **Test `sessions_send`** to all specialists
3. **Configure daily standup** cron job
4. **Implement task delegation** workflow from Section 3.3

### For QA (David-QA):
1. **Add tests for Nestor** - See Section 12.2
2. **Test agent communication** - Verify `sessions_send` logging
3. **Test daily standup** - Verify cron trigger

---

## Summary

### What v3.4 Fixes:
1. ✅ **Missing AI orchestrator** - Complete Nestor specification
2. ✅ **Reinventing OpenClaw** - Explicit use of native tools
3. ✅ **Undefined agent comms** - Hybrid approach with clear rules
4. ✅ **No daily standup** - Complete automation spec
5. ✅ **Unclear architecture** - Two-layer model clarified

### What v3.4 Improves:
1. 🚀 **Faster development** - Use native tools, not custom code
2. 🔒 **Better architecture** - Separation of AI vs technical layers
3. 📊 **Full observability** - All communication logged
4. 🤝 **Efficient collaboration** - Agent-to-agent with oversight
5. 📋 **Clear implementation path** - Phase 0 sets up orchestrator first

### What Stays the Same:
1. ✅ Database schema (mostly compatible)
2. ✅ WebSocket protocol
3. ✅ RPC method signatures
4. ✅ Frontend design requirements
5. ✅ Testing strategy

---

## Recommendation

**Start fresh with v3.4.**

If you're mid-implementation of v3.3, it's worth pausing to align with v3.4. The changes are significant enough that adapting v3.3 code will likely take more effort than starting with v3.4.

**Exceptions:**
- If you've completed Phase 2 (Database), the schema is compatible
- If you've completed Phase 5 (Frontend), the WebSocket API is unchanged

---

**Version:** v3.4
**Date:** 2026-02-02
**Status:** Implementation Ready
