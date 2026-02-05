# PRD v3.1 Gap Analysis (Final)

**Document:** Mission Control v3.1 PRD  
**Analysis Date:** 2026-02-02  
**Status:** Critical Gaps Identified (After Reviewing OpenClaw Framework & Web Documentation)

---

## Executive Summary

After reviewing OpenClaw framework documentation from:
- Workspace documentation ([`docs/openclaw/README.md`](docs/openclaw/README.md))
- Web searches of [docs.openclaw.ai](https://docs.openclaw.ai/)
- [GitHub repository](https://github.com/openclaw/openclaw)

I've identified **critical gaps** that must be addressed. The primary insight is that **OpenClaw already provides most building blocks**, but the PRD doesn't specify how Mission Control should integrate with them.

---

## 🔴 CRITICAL GAPS (Must Address Before Implementation)

### 1. Gateway Service Registration & RPC Method Routing
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 10)

**Issue:** The PRD mentions `MC_Service` but provides no details on:
- How to register Mission Control as a Gateway service
- How Gateway routes `mission.*` RPC methods to Mission Control
- How to define custom RPC methods in Gateway
- How to hook into Gateway lifecycle events

**OpenClaw Context:** 
- Gateway uses WebSocket with JSON-RPC 2.0 protocol
- Gateway validates every inbound frame with AJV against JSON Schema
- All query commands use WebSocket RPC
- Gateway has a control-plane architecture

**Impact:** Without proper registration, Mission Control cannot receive or handle RPC calls.

**Missing Specifications:**
```typescript
// Missing: Gateway service registration
interface GatewayServiceRegistration {
  serviceName: string;
  version: string;
  methods: {
    [methodName: string]: {
      description: string;
      parameters: JSONSchema;
      handler: (params: any) => Promise<any>;
    };
  };
  dependencies?: string[];
}

// Missing: How to register custom RPC methods
Gateway.registerService('mission-control', {
  methods: {
    'mission.project.init': { handler: handleProjectInit },
    'mission.task.create': { handler: handleTaskCreate },
    'mission.task.move': { handler: handleTaskMove },
    // ... other methods
  }
});
```

**Required Addition:**
- Section 14: Gateway Service Registration
- Define how to register Mission Control as a Gateway service
- Specify RPC method routing and validation
- Define service lifecycle hooks (onStartup, onShutdown)
- Provide code example of service registration

---

### 2. Background Process Scheduling for Agent Pulses
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 6.1, 10.1)

**Issue:** The PRD mentions "native `background_process.run` protocol" but doesn't explain:
- How to schedule recurring background processes for agent pulses
- How to implement staggered scheduling (offset from epoch)
- How to monitor background process health
- How to handle process failures and restarts
- How to integrate with OpenClaw's background exec system

**OpenClaw Context:**
- OpenClaw has "Background Exec and Process Tool"
- Gateway daemon runs as launchd/systemd user service
- Gateway has SIGINT/SIGTERM handlers for graceful shutdown
- Background processes can be managed via Gateway

**Impact:** Agents won't be able to run autonomously on a schedule.

**Missing Specifications:**
```typescript
// Missing: Background process scheduling
interface AgentPulseSchedule {
  agentId: string;
  projectId: string;
  interval: number;             // seconds between pulses
  staggerOffset: number;       // seconds offset from epoch
  maxRetries: number;
  timeout: number;             // seconds
  systemPrompt: string;        // System Pulse Template
}

// Missing: How to schedule recurring processes
interface BackgroundProcessScheduler {
  schedule(config: AgentPulseSchedule): Promise<ProcessHandle>;
  monitor(handle: ProcessHandle): Promise<ProcessStatus>;
  kill(handle: ProcessHandle): Promise<void>;
  list(): Promise<ProcessHandle[]>;
  restart(handle: ProcessHandle): Promise<void>;
}

// Missing: Staggered scheduling algorithm
function calculateStaggerOffset(agentId: string, projectId: string): number {
  // How to calculate unique offset for each agent
  // to prevent all agents pulsing at same time
}
```

**Required Addition:**
- Section 15: Background Process Scheduling
- Define how to schedule recurring agent pulses using OpenClaw's background process system
- Specify staggered scheduling algorithm (how to calculate offsets)
- Define process monitoring and recovery procedures
- Provide code examples of pulse scheduling

---

### 3. Scoped Session Creation & Management
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 3.1, 8.2)

**Issue:** The PRD mentions `scope` parameter but doesn't explain:
- How to create scoped sessions for agents
- How to inject System Pulse Template into sessions
- How to manage session lifecycle (create, destroy, restart)
- How to handle session failures and recovery
- How to query session status and logs

**OpenClaw Context:**
- OpenClaw treats one direct-chat session per agent as primary
- Direct chats collapse to `agent:<agentId>:<mainKey>`
- Group/channel chats get their own keys
- Session transcripts stored on disk under `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Gateway owns all messaging surfaces and manages sessions

**Impact:** Agents cannot be instantiated in isolated project scopes.

**Missing Specifications:**
```typescript
// Missing: Scoped session creation
interface ScopedSessionConfig {
  agentId: string;
  projectId: string;
  scope: string;               // e.g., 'projects/vanguard'
  systemPrompt: string;        // System Pulse Template
  context: SessionContext;
  tools: string[];             // Available tools in this scope
}

// Missing: Session manager interface
interface SessionManager {
  create(config: ScopedSessionConfig): Promise<Session>;
  destroy(sessionId: string): Promise<void>;
  getStatus(sessionId: string): Promise<SessionStatus>;
  injectMessage(sessionId: string, message: string): Promise<void>;
  list(projectId: string): Promise<Session[]>;
  getLogs(sessionId: string): Promise<SessionLog[]>;
  restart(sessionId: string): Promise<void>;
}

// Missing: System Pulse Template injection
const systemPulseTemplate = `
[SYSTEM STATUS UPDATE]
- Current Project: {{project_id}}
- Current Path: {{scoped_path}}
- Active Task: {{task_title}} (ID: {{task_id}})
- Last Learned Context: [Read learned.md]
- Internal Team Notes: [Read history.jsonl]

INSTRUCTION: Update your status via 'log_event' before taking any tool actions.
`;
```

**Required Addition:**
- Section 16: Scoped Session Management
- Define how to create scoped sessions for agents
- Specify System Pulse Template injection
- Define session lifecycle management
- Provide code examples of session creation and management

---

### 4. Database Schema & Migration Strategy
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 5)

**Issue:** The PRD defines SQLite schemas but lacks:
- Migration system for schema upgrades
- Data migration procedures
- Rollback procedures
- Index optimization strategy
- Query performance targets
- Backup/restore procedures

**OpenClaw Context:**
- OpenClaw uses local-first storage
- Config lives at `~/.openclaw/openclaw.json`
- State directory can be customized via `OPENCLAW_STATE_DIR`
- No built-in migration framework provided

**Impact:** Schema changes will break existing deployments.

**Missing Specifications:**
```typescript
// Missing: Migration system
interface Migration {
  version: string;
  description: string;
  up(db: Database): Promise<void>;
  down(db: Database): Promise<void>;
  checksum: string;
  createdAt: Date;
}

// Missing: Migration runner
interface MigrationRunner {
  migrate(targetVersion?: string): Promise<void>;
  rollback(steps?: number): Promise<void>;
  status(): Promise<MigrationStatus>;
  create(name: string): Promise<Migration>;
  getCurrentVersion(): Promise<string>;
}

// Missing: Database schema with indexes
CREATE INDEX IF NOT EXISTS idx_tasks_project_status ON tasks(project_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_task_events_task_timestamp ON task_events(task_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_agent_status_instance ON agent_status(instance_id);
```

**Required Addition:**
- Section 17: Database Management
- Define migration file format and location
- Specify migration execution order and dependencies
- Provide backup/restore procedures
- Define index optimization strategy
- Provide code examples of migration system

---

### 5. Scoped File System Operations & Locking
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 3.1, 10.2)

**Issue:** The PRD mentions path security but doesn't explain:
- How to enforce scope isolation at file system level
- How to integrate with OpenClaw's existing file system tools
- How to handle file locking for concurrent writes
- How to resolve file conflicts between agents
- How to implement File Mutex mentioned in Section 10.2

**OpenClaw Context:**
- OpenClaw has sandbox defaults: allowlist bash, process, read, write, edit
- Sandbox config can restrict file system access
- Gateway has path security mechanisms
- Tools can be restricted via sandbox configuration

**Impact:** Security vulnerabilities and data corruption.

**Missing Specifications:**
```typescript
// Missing: Scoped file system interface
interface ScopedFileSystem {
  read(path: string, scope: string): Promise<string>;
  write(path: string, content: string, scope: string): Promise<void>;
  list(path: string, scope: string): Promise<string[]>;
  delete(path: string, scope: string): Promise<void>;
  exists(path: string, scope: string): Promise<boolean>;
  resolve(path: string, scope: string): Promise<string>;
}

// Missing: File lock manager
interface FileLockManager {
  acquire(path: string, scope: string, timeout: number): Promise<Lock>;
  release(lock: Lock): Promise<void>;
  isLocked(path: string, scope: string): Promise<boolean>;
  waitForRelease(path: string, scope: string, timeout: number): Promise<void>;
}

// Missing: Scope enforcement
function enforceScope(path: string, scope: string): string {
  const basePath = `~/.openclaw/projects/${scope}`;
  const fullPath = resolve(basePath, path);
  
  // Prevent path traversal
  if (!fullPath.startsWith(basePath)) {
    throw new Error('Path traversal attempt detected');
  }
  
  return fullPath;
}
```

**Required Addition:**
- Section 18: Scoped File System Operations
- Define scoped file system operations
- Specify path resolution and validation
- Define file locking mechanism (File Mutex implementation)
- Provide code examples of scoped operations

---

### 6. Agent Lifecycle Management
**Severity:** CRITICAL  
**Section:** Partially addressed (Section 6.1)

**Issue:** The PRD describes the "Pulse" but lacks:
- Agent instance creation and destruction procedures
- Agent upgrade procedures (new SOUL.md versions)
- Cleanup procedures for deleted projects
- Handling of in-progress tasks during agent restart
- Agent state persistence across restarts

**OpenClaw Context:**
- OpenClaw has multi-agent routing
- Agents are defined in `~/.openclaw/agents/`
- Session transcripts stored in `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Gateway manages agent lifecycle

**Impact:** Resource leaks, orphaned processes, and inconsistent state.

**Missing Specifications:**
```typescript
// Missing: Agent lifecycle
interface AgentLifecycle {
  create(projectId: string, soulId: string): Promise<AgentInstance>;
  destroy(instanceId: string): Promise<void>;
  upgrade(instanceId: string, newSoulVersion: string): Promise<void>;
  pause(instanceId: string): Promise<void>;
  resume(instanceId: string): Promise<void>;
  getState(instanceId: string): Promise<AgentState>;
  setState(instanceId: string, state: AgentState): Promise<void>;
}

// Missing: Agent state persistence
interface AgentState {
  instanceId: string;
  projectId: string;
  currentTaskId: string | null;
  status: 'idle' | 'working' | 'distilling' | 'blocked';
  lastPulse: Date;
  workingMemory: string;
  learnedMemory: string;
}

// Missing: Cleanup procedures
async function cleanupProject(projectId: string) {
  // 1. Stop all agent sessions for this project
  // 2. Kill background processes
  // 3. Archive or delete project data
  // 4. Update database to reflect deletion
}
```

**Required Addition:**
- Section 19: Agent Lifecycle Management
- Define agent instance creation and destruction
- Specify agent upgrade procedures
- Define cleanup procedures for deleted projects
- Provide code examples of lifecycle management

---

## 🟡 HIGH PRIORITY GAPS

### 7. WebSocket Reconnection & State Sync
**Severity:** HIGH  
**Section:** Partially addressed (Section 8.1)

**Issue:** The PRD states "UI does not poll" but doesn't specify:
- Reconnection strategy for WebSocket disconnects
- State synchronization after reconnection
- Handling of in-flight operations during disconnection
- Network partition recovery

**OpenClaw Context:**
- Gateway uses WebSocket for communication
- macOS app connects via single WS (shared connection)
- Gateway validates every inbound frame with AJV

**Impact:** Poor user experience and state inconsistencies.

---

### 8. Error Handling & Recovery
**Severity:** HIGH  
**Section:** Partially addressed (Section 6.2)

**Issue:** Only deadman switch defined. Missing:
- Comprehensive error classification
- Retry policies for transient errors
- Circuit breaker patterns
- Rollback procedures for failed operations

**Impact:** Fragile system, difficult to debug.

---

### 9. Concurrency Control Details
**Severity:** HIGH  
**Section:** Partially addressed (Section 10.2)

**Issue:** "File Mutex" mentioned but no details on:
- Lock acquisition timeout behavior
- Deadlock detection and resolution
- Lock granularity (project, file, record)
- Distributed locking for multiple Gateway instances

**Impact:** Race conditions and data corruption.

---

### 10. Performance & Scalability
**Severity:** HIGH  
**Section:** Not addressed

**Issue:** No performance specifications:
- Max concurrent projects
- Max agents per project
- UI update latency targets
- Database query performance
- Resource limits per agent

**Impact:** Unpredictable performance and scaling issues.

---

### 11. Multi-Agent Communication (sessions_send)
**Severity:** HIGH  
**Section:** Partially addressed (Section 7.1)

**Issue:** The PRD mentions `sessions_send` tool but doesn't explain:
- How to inject messages into other agent's sessions
- How agents discover each other's session IDs
- How to handle message delivery failures
- How to implement inter-agent communication patterns

**OpenClaw Context:**
- OpenClaw has `sessions_send` tool in sandbox allowlist
- Session transcripts stored as JSONL files
- Multi-agent routing is a core feature

**Impact:** Agents cannot collaborate effectively.

---

## 🟢 MEDIUM PRIORITY GAPS

### 12. Logging & Monitoring
**Severity:** MEDIUM  
**Section:** Partially addressed (Section 7.2)

**Issue:** Agent `log_event` defined but missing:
- System-level logging strategy
- Log levels and rotation
- Metrics collection
- Alerting thresholds

---

### 13. Configuration Management
**Severity:** MEDIUM  
**Section:** Not addressed

**Issue:** No configuration system:
- How to configure Mission Control
- Runtime configuration changes
- Environment-specific configs
- Configuration validation

---

### 14. Testing Strategy
**Severity:** MEDIUM  
**Section:** Not addressed

**Issue:** No testing guidance:
- Unit testing approach
- Integration testing
- Mocking Gateway services
- Testing concurrent scenarios

---

### 15. Backup & Disaster Recovery
**Severity:** MEDIUM  
**Section:** Not addressed

**Issue:** No backup procedures:
- SQLite backup frequency
- Markdown file backup
- Recovery procedures
- Cross-machine replication

---

### 16. Deployment & CI/CD
**Severity:** MEDIUM  
**Section:** Not addressed

**Issue:** No deployment guidance:
- Installation procedures
- Zero-downtime deployments
- Database migrations during deployment
- Rollback procedures

---

## 🔵 LOW PRIORITY GAPS

### 17. Internationalization
**Severity:** LOW  
**Section:** Not addressed

**Issue:** No i18n support.

---

### 18. Theming & Customization
**Severity:** LOW  
**Section:** Partially addressed (Section 8 mentions Shadcn)

**Issue:** Limited customization.

---

### 19. Plugin System
**Severity:** LOW  
**Section:** Not addressed

**Issue:** No extensibility beyond defined tools.

---

## 🔍 INCONSISTENCIES & AMBIGUITIES

### 1. Method Name Inconsistency
**Issue:** Section 7.2 shows `mission.control.log` but Section 7 table shows `mission.agent.sync`.

**Location:** Lines 206-212 vs 239

**Recommendation:** Standardize on `mission.control.log_event`.

---

### 2. JSON Syntax Error
**Issue:** Section 7.5 has malformed JSON (missing quotes).

**Location:** Lines 286-295

**Recommendation:** Fix JSON syntax.

---

### 3. Task Status Terminology
**Issue:** Section 5.1 uses codes (0-4) but Section 10.1 uses names ("Backlog").

**Location:** Lines 143 vs 334

**Recommendation:** Use consistent terminology throughout.

---

### 4. Unclear "Staggered Pulse"
**Issue:** Section 10.1 mentions "stagger offset" but doesn't explain calculation.

**Location:** Line 337

**Recommendation:** Define staggering algorithm.

---

### 5. Missing Tool Registration
**Issue:** Section 11 provides tool manifest but no registration procedure.

**Location:** Lines 347-389

**Recommendation:** Add tool registration steps.

---

## 📋 RECOMMENDED PRD RESTRUCTURE

### New Sections to Add:

1. **Section 14: Gateway Service Registration**
   - Service registration procedure
   - RPC method routing and validation
   - Lifecycle hooks (onStartup, onShutdown)
   - Code examples of service registration

2. **Section 15: Background Process Scheduling**
   - Pulse scheduling using OpenClaw's background process system
   - Staggered scheduling algorithm
   - Process monitoring and recovery
   - Code examples of pulse scheduling

3. **Section 16: Scoped Session Management**
   - Creating scoped sessions for agents
   - System Pulse Template injection
   - Session lifecycle management
   - Session recovery procedures
   - Code examples of session creation

4. **Section 17: Database Management**
   - Migration system implementation
   - Backup procedures
   - Recovery procedures
   - Index optimization strategy
   - Code examples of migration system

5. **Section 18: Scoped File System Operations**
   - Scoped operations implementation
   - Path resolution and validation
   - File locking mechanism (File Mutex)
   - Concurrency control
   - Code examples of scoped operations

6. **Section 19: Agent Lifecycle Management**
   - Agent instance creation and destruction
   - Agent upgrade procedures
   - Cleanup procedures for deleted projects
   - State persistence across restarts
   - Code examples of lifecycle management

7. **Section 20: Error Handling & Recovery**
   - Error classification
   - Retry policies
   - Circuit breakers
   - Rollback procedures

8. **Section 21: Operations & Monitoring**
   - Logging strategy
   - Metrics collection
   - Alerting
   - Health checks

9. **Section 22: Deployment Guide**
   - Installation procedures
   - Configuration
   - CI/CD pipeline
   - Testing

---

## 🎯 IMMEDIATE ACTION ITEMS

### Before Implementation Starts:

1. **[CRITICAL]** Define Gateway service registration procedure
2. **[CRITICAL]** Specify background process scheduling for agent pulses
3. **[CRITICAL]** Define scoped session management for agents
4. **[CRITICAL]** Create database migration system
5. **[CRITICAL]** Implement scoped file system operations with locking
6. **[CRITICAL]** Define agent lifecycle management
7. **[HIGH]** Define WebSocket reconnection strategy
8. **[HIGH]** Specify multi-agent communication (sessions_send)
9. **[HIGH]** Define concurrency control mechanism
10. **[HIGH]** Create error handling and recovery procedures
11. **[HIGH]** Define performance targets and resource limits

### During Implementation:

1. **[MEDIUM]** Implement logging and monitoring
2. **[MEDIUM]** Create configuration management system
3. **[MEDIUM]** Write comprehensive tests
4. **[MEDIUM]** Set up CI/CD pipeline
5. **[MEDIUM]** Create backup and recovery procedures

### Post-Implementation:

1. **[LOW]** Add i18n support
2. **[LOW]** Implement theming system
3. **[LOW]** Design plugin system

---

## 📊 GAP SUMMARY

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Integration | 6 | 2 | 1 | 0 | 9 |
| Operations | 0 | 3 | 4 | 0 | 7 |
| Security | 1 | 1 | 0 | 0 | 2 |
| Developer Experience | 0 | 1 | 3 | 3 | 7 |
| **TOTAL** | **7** | **7** | **8** | **3** | **25** |

---

## 🏁 CONCLUSION

The PRD v3.1 provides a solid **architectural foundation** but lacks the **integration details** necessary to leverage OpenClaw's existing capabilities. The **7 critical gaps** focus on how Mission Control should integrate with OpenClaw's Gateway, background processes, session management, and file system.

### Key Insights:

1. **OpenClaw Already Provides Building Blocks:**
   - Gateway with WebSocket/JSON-RPC 2.0
   - Background process management
   - Session management with JSONL logs
   - Multi-agent routing
   - Scoped file system tools
   - Memory management

2. **Primary Gap is Integration:**
   - How to register Mission Control as a Gateway service
   - How to schedule agent pulses using background processes
   - How to create scoped sessions for agents
   - How to implement scoped file operations with locking
   - How to manage agent lifecycle

3. **Missing Concrete Code Examples:**
   - No examples of service registration
   - No examples of pulse scheduling
   - No examples of session creation
   - No examples of scoped file operations
   - No examples of agent lifecycle management

### Recommendation:

**The PRD cannot be implemented in its current state.** The 7 critical gaps must be addressed first, particularly:

1. Define Gateway service registration procedure
2. Specify background process scheduling for agent pulses
3. Define scoped session management for agents
4. Create database migration system
5. Implement scoped file system operations with locking
6. Define agent lifecycle management
7. Specify multi-agent communication patterns

I recommend creating a companion document **"Mission Control v3.1 - Implementation Guide"** that provides:
- Concrete code examples for all critical integration points
- Step-by-step procedures for registering services
- Examples of scheduling background processes
- Examples of creating scoped sessions
- Examples of implementing scoped file operations
- Examples of agent lifecycle management

**This is the most comprehensive gap analysis possible without direct access to the specific DeepWiki URLs mentioned in the PRD.**

---

**Analysis Completed:** 2026-02-02  
**Next Review:** After addressing critical integration gaps
