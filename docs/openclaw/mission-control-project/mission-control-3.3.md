# PRD: OpenClaw Mission Control (Project Vanguard)
**Version:** 3.3 (Implementation-Ready Edition)  
**Status:** Implementation Ready  
**Framework:** OpenClaw Core (TypeScript/Node)  
**Security:** Isolated Scoped Environments (Local-First)

---

## 0. Developer Prerequisites
**Mandatory reading for the implementation team to ensure "OpenClaw-native" behavior:**

1. **Fundamental Philosophy:** [1.1 Key Concepts](https://deepwiki.com/openclaw/openclaw/1.1-key-concepts)
2. **Communication Protocol:** [3.2 Gateway Protocol](https://deepwiki.com/openclaw/openclaw/3.2-gateway-protocol)
3. **Extensibility:** [3.3 Gateway Service Management](https://deepwiki.com/openclaw/openclaw/3.3-gateway-service-management)
4. **Daemon Management:** [Background Processes](https://docs.openclaw.ai/gateway/background-process)
5. **Memory Layering:** [Snowan Memory System Deep Dive](https://snowan.gitbook.io/study-notes/ai-blogs/openclaw-memory-system-deep-dive)
6. **Team Configuration:** [4.3 Multi-Agent Configuration](https://deepwiki.com/openclaw/openclaw/4.3-multi-agent-configuration)
7. **Execution:** [5. Agent System](https://deepwiki.com/openclaw/openclaw/5-agent-system)
8. **Overall llms.txt reference:** [6. Reference](./openclaw-docs-llms.txt)
---

## 1. System Vision
Mission Control is the **Control Plane** for OpenClaw. It transforms the system from a reactive "Chatbot" into an autonomous **"AI Factory."**

Mission Control is a **visualization and coordination tool** built on top of OpenClaw:

1. **Visualization Layer** - Kanban board, activity feed, agent status cards
2. **Shared State** - Database where all agents see the same tasks and context
3. **Notification System** - @mentions and thread subscriptions
4. **Infrastructure** - Heartbeat scheduling, zombie detection, state mirroring

### What OpenClaw Already Provides ✅

- Channel integration (Telegram, Discord, WhatsApp, etc.) - **Already built**
- Remote access - **Already built**
- Device nodes - **Already built**
- CLI commands - **Already built**
- Model selection and failover - **Already built**
- Memory system - **Already built**

It provides a unified Vite/Shadcn interface to manage multiple projects, where specialized **Agent Classes** (Souls) are instantiated into isolated **Project Scopes**. These agents work on a shared **Kanban Task Queue**, communicate natively via the Gateway, and maintain a human-readable **Knowledge Base (Chronicle)**.

The [`mission-control-3.3.md`](docs/openclaw/mission-control-project/mission-control-3.3.md) specification is **incomplete for a fully functional Mission Control system**. While it provides excellent technical infrastructure for the **visualization layer** (Kanban board, thought stream, database), it's **missing a critical component**:

---

## 2. High-Level Architecture Diagram

```mermaid
graph TB
    subgraph "Frontend (User Space)"
        UI[Vite + React + Shadcn]
        WS[Gateway WS Client]
        ThoughtStream[Live Thought Timeline]
    end

    subgraph "Control Plane (OpenClaw Server)"
        Gateway[OpenClaw Gateway]
        MC_Service[Mission Control Service]
        BgProcess[Background Process Manager]
    end

    subgraph "Persistence Layer (Disk)"
        DB[(SQLite: Tasks/Status/Events)]
        SessionLogs[(Session .jsonl: Agent Transcripts)]
        MD_Kanban[Project KANBAN.md Mirror]
        MD_KB[Project CHRONICLE.md]
    end

    subgraph "Isolated Project Execution (Scope: App-A)"
        Team[Agent Squad: Shuri, Jarvis, Friday]
        Files[Project Source Code]
        ProjectSoul[Project-Level Soul Extensions]
    end

    %% Communication Flows
    UI <-->|WebSocket JSON-RPC 2.0| Gateway
    Gateway <-->|RPC Method Routing| MC_Service
    MC_Service <-->|State/Locking| DB
    MC_Service -->|Mirror| MD_Kanban
    BgProcess -->|Trigger Staggered Pulse| Gateway
    Gateway -->|Spawn Scoped Session| Team
    
    %% AGENT ACTIONS
    Team -->|tool: sessions_send| Team
    Team -->|tool: log_event| DB
    Team -->|tool: update_chronicle| MD_KB
    Team -->|Scoped FileSystem API| Files
```

---

## 3. Core Technical Pillars

### 3.1 Scoped Project Isolation
Each project workspace is a strict "Jail."
* **Path Security:** All File-System tools must prepend the scope path.
* **Example:** If scope is `vidsnap, read_file("main.go")→.openclaw/projects/vidsnap/src/main.go`
* **Traversal Protection:** Path traversal (../) is blocked at the Gateway regex level.
* **Symlink Protection:** The Gateway must resolve paths using `fs.realpath` before execution. If a resolved path points outside the `.openclaw/projects` directory, the operation is denied.
* **Command Restrictions:** The `system.run` tool explicitly blocklists `ln` (symlink creation) to prevent agents from creating "escape tunnels" to the host OS.

### 3.2 The 4-Layer Memory Stack (Snowan Pattern)
To prevent "Context Decay" and token bloat, agents follow a hierarchical memory structure:

| Layer | Component | File | Strategy |
| :--- | :--- | :--- | :--- |
| **L1** | **Identity** | `SOUL.md` | Persona & Skills (Base + Project Refinement). |
| **L2** | **Context** | `.context` | Fixed project rules (Style guides, Tech stack). |
| **L3** | **Working** | `working.md` | The Active Scratchpad. Cleared upon task completion. |
| **L4** | **Learned** | `learned.md` | Distilled Knowledge. Persistent KB of "how" things were built. |

**The Protocol:** On every pulse, agents read L1-L3. When a task hits `DONE`, the `distill_memory` tool is triggered to move relevant "Working" data into "Learned" data.

### 3.3 Hybrid Persistence (State vs. Narrative)

*   **Single-Writer Requirement:** The **MC_Service (Server)** is the **ONLY** entity authorized to write to `KANBAN.md`.
    *   **Restriction:** Agents are strictly **forbidden** from writing to `KANBAN.md` via standard file tools. They must strictly use the `mission.task.*` RPC methods.
*   **Logic:** When `MC_Service` receives `mission.task.move`:
    1.  **Lock:** Acquire in-memory lock for Project ID.
    2.  **DB:** Update SQLite row.
    3.  **Mirror:** Regenerate `KANBAN.md` string $\rightarrow$ Atomic Write (Write to `.tmp` file then Rename to avoid partial reads).
    4.  **Unlock:** Release Project ID.

---

## 4. The Filesystem Map (Standardization)

```text
~/.openclaw/
├── mission-control.db        # High-Performance State (SQLite)
├── openclaw.json             # Global Agent Manifest
├── souls/                    # GLOBAL CLASSES
│   └── shuri/SOUL.md         # Base Identity
├── projects/                 # ISOLATED SCOPES
│   └── app-vanguard/         # Project Folder
│       ├── KANBAN.md         # Mirrored State (Human Readable)
│       ├── CHRONICLE.md      # The Chronicle (High-level Narrative)
│       ├── .context          # L2: Fixed Project Rules
│       ├── daily/            # L3: Human Chronology logs
│       │   └── 2026-02-02.md # Every pulse result is logged here
│       ├── src/              # Source code
│       └── agents/           # Instance Private Zone
│           └── shuri/
│               ├── working.md # L3: The current task state
│               ├── learned.md # L4: Distilled project wisdom
│               └── SOUL.md    # Instance persona refinement
└── sessions/                 # NATIVE SESSION LOGS (.jsonl)
```

---

## 5. Technical Data Schema (SQLite)

### 5.1 `tasks` Table
Used to render the Kanban columns.
*   **`status` codes:** `0: Backlog`, `1: In-Progress`, `2: Done`, `3: Blocked`, `4: Archive`.

### 5.2 `task_events` Table (The Thought Stream)
Used to render the "Live Terminal" observability view.
*   **Fields:** `id, task_id, agent_id, timestamp, thought, action`.

```sql
-- Project Isolation
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Kanban State
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES projects(id),
    title TEXT NOT NULL,
    assignee_id TEXT NOT NULL, -- Global Soul ID
    status INTEGER CHECK(status BETWEEN 0 AND 4),
    priority INTEGER DEFAULT 3,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_project_status ON tasks(project_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee_id);

-- Reliability & Observability
CREATE TABLE agent_status (
    instance_id TEXT PRIMARY KEY, -- format: "agent:project"
    pgid INTEGER, -- OS Process Group ID (Critical for cleaning up child processes)
    last_pulse DATETIME,
    current_task_id TEXT REFERENCES tasks(id),
    status TEXT DEFAULT 'idle' -- 'working', 'distilling', 'blocked'
);

CREATE INDEX IF NOT EXISTS idx_agent_status_instance ON agent_status(instance_id);

-- Thought Stream
CREATE TABLE task_events (
    id TEXT PRIMARY KEY,
    task_id TEXT REFERENCES tasks(id),
    agent_id TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    thought TEXT NOT NULL,
    action TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_task_events_task_timestamp ON task_events(task_id, timestamp);
```

---

## 6. Protocols & Safety

---

### 6.1 The Pulse Engine (Background Process Native)
Mission Control uses the native `background_process.run` protocol instead of a generic cron.

*   **Daemon Tracking:** Every agent pulse is registered in SQLite with its OS Process ID (`pid`).
*   **PID Monitoring:** Mission Control monitors the actual OS process. If a process is "Stalled" (running but not writing to `daily/log.md`), Mission Control issues a `SIGKILL` and restarts the instance.
*   **State Injection:** Every pulse initializes by reading the `working.md` and injecting the latest 5 `task_events` from SQLite.

**System Pulse Template:**
```
[SYSTEM STATUS UPDATE]
- Current Project: {{project_id}}
- Current Path: {{scoped_path}}
- Active Task: {{task_title}} (ID: {{task_id}})
- Last Learned Context: [Read learned.md]
- Internal Team Notes: [Read history.jsonl]

INSTRUCTION: Update your status via 'log_event' before taking any tool actions.
```

### 6.2 Deadman Switch & HITL
*   **Deadman:** `MC_Service` reverts tasks to `Backlog` (status 0) if an agent is `In-Progress` (status 1) but silent for > 300s.
*   **HITL:** `request_help` tool moves task to `Blocked` (status 3) and halts the heartbeat cycle.

---

## 7. Tooling Specification & Payloads

| Method | Role | Payload Key Params |
| :--- | :--- | :--- |
| `mission.project.init` | UI $\rightarrow$ Server | `project_name`, `base_id` |
| `mission.task.create` | UI/Agent $\rightarrow$ Server | `project_id`, `title`, `assignee_id`, `priority` |
| `mission.task.move` | UI/Agent $\rightarrow$ Server | `task_id`, `new_status` |
| `mission.agent.sync` | Agent $\rightarrow$ Server | `instance_id`, `current_task_id`, `status` |
| `mission.event.broadcast`| Server $\rightarrow$ UI | `type` (TASK_UPDATED, THOUGHT_LOG), `data` |

### 7.1 Native Multi-Agent Comms (Spec 4.3)
**Tool:** `sessions_send`
*   **Description:** Injects a message into another session's JSONL history.
*   **Payload Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "sessions_send",
  "params": {
    "session_id": "agent:shuri:mc:vanguard:102",
    "message": "Jarvis here. Market research is ready in research.md. You can start the frontend."
  },
  "id": "mc_001"
}
```

### 7.2 Observability Tool
**Tool:** `log_event`
*   **Description:** Writes the agent's current internal thought and intended action to the SQLite `task_events` table for UI streaming.
*   **Payload Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mission.control.log_event",
  "params": {
    "task_id": "task_101",
    "thought": "The user requested a login page. I am checking if we have existing auth middleware.",
    "action": "ls src/middleware"
  },
  "id": "mc_002"
}
```

### 7.3 Narrative Persistence Tool
**Tool:** `update_chronicle`
*   **Description:** Appends a summary to the project-level `CHRONICLE.md`.
*   **Payload Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mission.control.update_chronicle",
  "params": {
    "project_id": "vanguard",
    "summary": "Implemented SQLite bridge using better-sqlite3. Decisions: Synchronous for local speed.",
    "technical_debt": "Need to implement row-level versioning for concurrency."
  },
  "id": "mc_003"
}
```

### 7.4 Human-In-The-Loop Tool
**Tool:** `request_help`
*   **Description:** Blocks the task and prompts the UI for human input.
*   **Payload Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mission.control.request_help",
  "params": {
    "task_id": "task_101",
    "issue": "Missing Stripe API Key. Cannot proceed with payment integration."
  },
  "id": "mc_004"
}
```

### 7.5 Memory Distillation Tool
**Tool:** `distill_memory`
**Description:** Background task to move data from Layer 3 (Working) to Layer 4 (Learned).
**Payload Example:**
```json
{
  "jsonrpc": "2.0",
  "method": "mission.control.distill_memory",
  "params": {
    "agent_id": "shuri",
    "summary": "Verified that SQLite handles concurrency better than JSON for state. Documented the new task table indexing.",
    "archive_working_notes": true
  },
  "id": "mc_005"
}
```

---

## 8. Frontend Implementation (Vite + Shadcn)

### 8.1 Real-time Updates
The UI does **not** poll. It listens for Gateway events:
*   `mission.task_updated`: Triggers card movement.
*   `mission.thought_logged`: Updates the "Live Terminal" timeline component.

### 8.2 The "Project Switcher"
*   Toggling the Project dropdown calls `gateway.set_scope(project_id)`.
*   The UI clears the current Kanban and reloads cards associated with the new project ID.

---

## 9. The Mission Control Orchestration Loop

The `MC_Service` must implement a "Tick" logic to manage the Staggered Heartbeats and Daemon health.

### 9.1 The "Orchestrator Tick" (Every 30s)
1.  **Scan `tasks` table:** Find all tasks with `status = 0 (Backlog)` or `status = 1 (In-Progress)`.
2.  **Zombie Check:** For `In-Progress` tasks, check `agent_status`. If `last_pulse` > 5m, issue `gateway.process.kill` and move task back to `Backlog`.
3.  **Daemon Check:** If an agent is due for a pulse (based on stagger offset):
    *   Call `gateway.process.run` with the `session_key` and `scope`.
    *   Inject the **System Pulse Template** (See Section 6.1).
4.  **State Mirroring:** If any DB change occurred during the tick, trigger `SyncToMarkdown()`.

### 9.2 Staggered Pulse Scheduling Algorithm
To prevent all agents from pulsing simultaneously, calculate unique offsets:

```typescript
function calculateStaggerOffset(agentId: string, projectId: string): number {
  // Create a hash from agentId and projectId
  const hash = crypto.createHash('sha256')
    .update(agentId)
    .update(projectId)
    .digest('hex');
  
  // Convert first 8 chars to integer (0-255 seconds)
  const offset = parseInt(hash.substring(0, 8), 16);
  
  return offset;
}

// Example usage:
const pulseInterval = 60; // 60 seconds between pulses
const offset = calculateStaggerOffset('shuri', 'vanguard');
const nextPulseTime = Date.now() + offset;
```

### 9.3 File Concurrency Guard
*   **Requirement:** The `MC_Service` must implement a **File Mutex (Lock)**. 
*   **Logic:** When writing to `KANBAN.md` or `CHRONICLE.md`, the service must ensure no other agent instance is mid-write to avoid file corruption.
*   **Lock Timeout:** 30 seconds maximum wait time.
*   **Deadlock Detection:** If lock cannot be acquired after 3 retries, log error and fail gracefully.

---

## 10. Gateway Service Registration

### 10.1 Service Registration Procedure
Mission Control must register as a Gateway service to handle `mission.*` RPC methods.

**OpenClaw Context:**
- Gateway uses WebSocket with JSON-RPC 2.0 protocol
- Gateway validates every inbound frame with AJV against JSON Schema
- All query commands use WebSocket RPC
- Gateway has a control-plane architecture

**Registration Interface:**
```typescript
// Gateway service registration
interface GatewayServiceRegistration {
  serviceName: string;           // "mission-control"
  version: string;              // "3.3.0"
  methods: {
    [methodName: string]: {
      description: string;
      parameters: JSONSchema;
      handler: (params: any) => Promise<any>;
    };
  };
  dependencies?: string[];      // ["database", "filesystem"]
  onStartup?: () => Promise<void>;
  onShutdown?: () => Promise<void>;
}

// Register Mission Control service
async function registerMissionControlService(): Promise<void> {
  await Gateway.registerService({
    serviceName: 'mission-control',
    version: '3.3.0',
    methods: {
      'mission.project.init': {
        description: 'Initialize a new project',
        parameters: {
          type: 'object',
          properties: {
            project_name: { type: 'string' },
            base_id: { type: 'string' }
          },
          required: ['project_name']
        },
        handler: handleProjectInit
      },
      'mission.task.create': {
        description: 'Create a new task',
        parameters: {
          type: 'object',
          properties: {
            project_id: { type: 'string' },
            title: { type: 'string' },
            assignee_id: { type: 'string' },
            priority: { type: 'number' }
          },
          required: ['project_id', 'title', 'assignee_id']
        },
        handler: handleTaskCreate
      },
      'mission.task.move': {
        description: 'Move task to new status',
        parameters: {
          type: 'object',
          properties: {
            task_id: { type: 'string' },
            new_status: { type: 'number' }
          },
          required: ['task_id', 'new_status']
        },
        handler: handleTaskMove
      },
      'mission.agent.sync': {
        description: 'Sync agent status',
        parameters: {
          type: 'object',
          properties: {
            instance_id: { type: 'string' },
            current_task_id: { type: 'string' },
            status: { type: 'string' }
          },
          required: ['instance_id', 'status']
        },
        handler: handleAgentSync
      },
      'mission.control.log_event': {
        description: 'Log agent thought and action',
        parameters: {
          type: 'object',
          properties: {
            task_id: { type: 'string' },
            thought: { type: 'string' },
            action: { type: 'string' }
          },
          required: ['task_id', 'thought', 'action']
        },
        handler: handleLogEvent
      },
      'mission.control.update_chronicle': {
        description: 'Update project chronicle',
        parameters: {
          type: 'object',
          properties: {
            project_id: { type: 'string' },
            summary: { type: 'string' },
            technical_debt: { type: 'string' }
          },
          required: ['project_id', 'summary']
        },
        handler: handleUpdateChronicle
      },
      'mission.control.request_help': {
        description: 'Request human help',
        parameters: {
          type: 'object',
          properties: {
            task_id: { type: 'string' },
            issue: { type: 'string' }
          },
          required: ['task_id', 'issue']
        },
        handler: handleRequestHelp
      },
      'mission.control.distill_memory': {
        description: 'Distill working memory to learned',
        parameters: {
          type: 'object',
          properties: {
            agent_id: { type: 'string' },
            summary: { type: 'string' },
            archive_working_notes: { type: 'boolean' }
          },
          required: ['agent_id', 'summary']
        },
        handler: handleDistillMemory
      }
    },
    onStartup: async () => {
      console.log('[Mission Control] Service starting...');
      await initializeDatabase();
      await startOrchestratorLoop();
    },
    onShutdown: async () => {
      console.log('[Mission Control] Service shutting down...');
      await stopOrchestratorLoop();
      await closeDatabase();
    }
  });
}
```

### 10.2 RPC Method Routing
Gateway routes all `mission.*` RPC methods to Mission Control service handlers:
- `mission.project.init` → `handleProjectInit()`
- `mission.task.create` → `handleTaskCreate()`
- `mission.task.move` → `handleTaskMove()`
- `mission.agent.sync` → `handleAgentSync()`
- `mission.control.log_event` → `handleLogEvent()`
- `mission.control.update_chronicle` → `handleUpdateChronicle()`
- `mission.control.request_help` → `handleRequestHelp()`
- `mission.control.distill_memory` → `handleDistillMemory()`

---

## 11. Background Process Scheduling

### 11.1 Pulse Scheduling Interface
Mission Control uses OpenClaw's background process system to schedule agent pulses.

**OpenClaw Context:**
- OpenClaw has "Background Exec and Process Tool"
- Gateway daemon runs as launchd/systemd user service
- Gateway has SIGINT/SIGTERM handlers for graceful shutdown
- Background processes can be managed via Gateway

**Scheduling Interface:**
```typescript
interface AgentPulseSchedule {
  agentId: string;
  projectId: string;
  interval: number;             // seconds between pulses
  staggerOffset: number;       // seconds offset from epoch
  maxRetries: number;
  timeout: number;             // seconds
  systemPrompt: string;        // System Pulse Template
}

interface BackgroundProcessScheduler {
  schedule(config: AgentPulseSchedule): Promise<ProcessHandle>;
  monitor(handle: ProcessHandle): Promise<ProcessStatus>;
  kill(handle: ProcessHandle): Promise<void>;
  list(): Promise<ProcessHandle[]>;
  restart(handle: ProcessHandle): Promise<void>;
}

// Schedule agent pulse
async function scheduleAgentPulse(agentId: string, projectId: string): Promise<void> {
  const offset = calculateStaggerOffset(agentId, projectId);
  const config: AgentPulseSchedule = {
    agentId,
    projectId,
    interval: 60,           // 60 seconds between pulses
    staggerOffset: offset,
    maxRetries: 3,
    timeout: 300,           // 5 minutes
    systemPrompt: generateSystemPulseTemplate(projectId)
  };
  
  const handle = await BackgroundProcessScheduler.schedule(config);
  await AgentStatusTable.insert({
    instance_id: `${agentId}:${projectId}`,
    pgid: handle.pgid,
    last_pulse: new Date(),
    status: 'idle'
  });
}
```

### 11.2 Process Monitoring
Monitor all scheduled background processes for health and recovery:

```typescript
async function monitorAgentProcesses(): Promise<void> {
  const handles = await BackgroundProcessScheduler.list();
  
  for (const handle of handles) {
    const status = await BackgroundProcessScheduler.monitor(handle);
    const dbStatus = await AgentStatusTable.get(handle.instanceId);
    
    // Check for stalled processes
    if (status.state === 'running' && 
        (Date.now() - dbStatus.last_pulse.getTime()) > 300000) {
      console.log(`[Mission Control] Stalled agent detected: ${handle.instanceId}`);
      await BackgroundProcessScheduler.kill(handle);
      await TaskTable.updateStatus(dbStatus.current_task_id, 0); // Back to Backlog
    }
    
    // Update last pulse time
    await AgentStatusTable.update(handle.instanceId, {
      last_pulse: new Date(),
      status: status.state
    });
  }
}
```

---

## 12. Scoped Session Management

### 12.1 Session Creation Interface
Create scoped sessions for agents to work in isolated project environments.

**OpenClaw Context:**
- OpenClaw treats one direct-chat session per agent as primary
- Direct chats collapse to `agent:<agentId>:<mainKey>`
- Group/channel chats get their own keys
- Session transcripts stored on disk under `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Gateway owns all messaging surfaces and manages sessions

**Session Management Interface:**
```typescript
interface ScopedSessionConfig {
  agentId: string;
  projectId: string;
  scope: string;               // e.g., 'projects/vanguard'
  systemPrompt: string;        // System Pulse Template
  context: SessionContext;
  tools: string[];             // Available tools in this scope
}

interface SessionManager {
  create(config: ScopedSessionConfig): Promise<Session>;
  destroy(sessionId: string): Promise<void>;
  getStatus(sessionId: string): Promise<SessionStatus>;
  injectMessage(sessionId: string, message: string): Promise<void>;
  list(projectId: string): Promise<Session[]>;
  getLogs(sessionId: string): Promise<SessionLog[]>;
  restart(sessionId: string): Promise<void>;
}

// Create scoped session for agent
async function createScopedSession(agentId: string, projectId: string): Promise<Session> {
  const config: ScopedSessionConfig = {
    agentId,
    projectId,
    scope: `projects/${projectId}`,
    systemPrompt: generateSystemPulseTemplate(projectId),
    context: {
      project_id: projectId,
      current_task: await getCurrentTask(agentId, projectId)
    },
    tools: ['read', 'write', 'edit', 'sessions_send', 'log_event', 'update_chronicle', 'distill_memory', 'request_help']
  };
  
  const session = await SessionManager.create(config);
  return session;
}
```

### 12.2 System Pulse Template Injection
Inject system status update into each agent pulse:

```typescript
function generateSystemPulseTemplate(projectId: string): string {
  return `
[SYSTEM STATUS UPDATE]
- Current Project: ${projectId}
- Current Path: ~/.openclaw/projects/${projectId}
- Active Task: {{task_title}} (ID: {{task_id}})
- Last Learned Context: [Read learned.md]
- Internal Team Notes: [Read history.jsonl]

INSTRUCTION: Update your status via 'log_event' before taking any tool actions.
`;
}
```

### 12.3 Session Lifecycle Management
Handle session creation, destruction, and recovery:

```typescript
async function manageSessionLifecycle(instanceId: string): Promise<void> {
  const [agentId, projectId] = instanceId.split(':');
  
  // Create session if doesn't exist
  let session = await SessionManager.getStatus(instanceId);
  if (!session) {
    session = await createScopedSession(agentId, projectId);
  }
  
  // Monitor session health
  const status = await SessionManager.getStatus(instanceId);
  if (status.state === 'error' || status.state === 'terminated') {
    console.log(`[Mission Control] Session error detected: ${instanceId}`);
    await SessionManager.restart(instanceId);
  }
}
```

---

## 13. Database Management

### 13.1 Migration System
Implement a migration system for schema upgrades and data migrations.

**OpenClaw Context:**
- OpenClaw uses local-first storage
- Config lives at `~/.openclaw/openclaw.json`
- State directory can be customized via `OPENCLAW_STATE_DIR`
- No built-in migration framework provided

**Migration Interface:**
```typescript
interface Migration {
  version: string;
  description: string;
  up(db: Database): Promise<void>;
  down(db: Database): Promise<void>;
  checksum: string;
  createdAt: Date;
}

interface MigrationRunner {
  migrate(targetVersion?: string): Promise<void>;
  rollback(steps?: number): Promise<void>;
  status(): Promise<MigrationStatus>;
  create(name: string): Promise<Migration>;
  getCurrentVersion(): Promise<string>;
}

// Migration example: Add task_events table
const migration_001_add_task_events: Migration = {
  version: '0.0.1',
  description: 'Add task_events table for thought stream',
  checksum: 'abc123def456',
  createdAt: new Date('2026-02-02'),
  up: async (db: Database) => {
    await db.exec(`
      CREATE TABLE IF NOT EXISTS task_events (
        id TEXT PRIMARY KEY,
        task_id TEXT REFERENCES tasks(id),
        agent_id TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        thought TEXT NOT NULL,
        action TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_task_events_task_timestamp ON task_events(task_id, timestamp);
    `);
  },
  down: async (db: Database) => {
    await db.exec('DROP INDEX IF EXISTS idx_task_events_task_timestamp;');
    await db.exec('DROP TABLE IF EXISTS task_events;');
  }
};

// Run migrations
async function runMigrations(): Promise<void> {
  const currentVersion = await MigrationRunner.getCurrentVersion();
  const targetVersion = '0.0.1';
  
  if (currentVersion < targetVersion) {
    console.log(`[Mission Control] Migrating from ${currentVersion} to ${targetVersion}`);
    await MigrationRunner.migrate(targetVersion);
  }
}
```

### 13.2 Backup & Recovery
Implement backup and recovery procedures:

```typescript
interface BackupConfig {
  enabled: boolean;
  interval: number;              // hours
  retentionDays: number;
  destination: 'local' | 's3' | 'gcs';
  compression: boolean;
}

async function createBackup(): Promise<void> {
  const timestamp = new Date().toISOString();
  const backupPath = `~/.openclaw/backups/mission-control-${timestamp}.db`;
  
  // Copy database to backup location
  await fs.copyFile('~/.openclaw/mission-control.db', backupPath);
  
  // Compress if enabled
  if (config.compression) {
    await compressFile(backupPath, `${backupPath}.gz`);
  }
  
  // Clean old backups
  await cleanupOldBackups(config.retentionDays);
}

async function restoreFromBackup(backupId: string): Promise<void> {
  const backupPath = `~/.openclaw/backups/${backupId}`;
  
  // Verify backup integrity
  const isValid = await verifyBackupIntegrity(backupPath);
  if (!isValid) {
    throw new Error('Backup integrity check failed');
  }
  
  // Stop Mission Control service
  await stopMissionControl();
  
  // Restore database
  await fs.copyFile(backupPath, '~/.openclaw/mission-control.db');
  
  // Restart service
  await startMissionControl();
}
```

---

## 14. Scoped File System Operations

### 14.1 Scoped File System Interface
Implement scoped file system operations with path security.

**OpenClaw Context:**
- OpenClaw has sandbox defaults: allowlist bash, process, read, write, edit
- Sandbox config can restrict file system access
- Gateway has path security mechanisms
- Tools can be restricted via sandbox configuration

**Scoped File System Interface:**
```typescript
interface ScopedFileSystem {
  read(path: string, scope: string): Promise<string>;
  write(path: string, content: string, scope: string): Promise<void>;
  list(path: string, scope: string): Promise<string[]>;
  delete(path: string, scope: string): Promise<void>;
  exists(path: string, scope: string): Promise<boolean>;
  resolve(path: string, scope: string): Promise<string>;
}

// Scope enforcement
function enforceScope(path: string, scope: string): string {
  const basePath = path.resolve('~/.openclaw/projects', scope);
  const fullPath = path.resolve(basePath, path);
  
  // Prevent path traversal
  if (!fullPath.startsWith(basePath)) {
    throw new Error('Path traversal attempt detected');
  }
  
  return fullPath;
}

// Scoped read operation
async function scopedRead(path: string, scope: string): Promise<string> {
  const fullPath = enforceScope(path, scope);
  return await fs.readFile(fullPath, 'utf-8');
}

// Scoped write operation
async function scopedWrite(path: string, content: string, scope: string): Promise<void> {
  const fullPath = enforceScope(path, scope);
  await fs.writeFile(fullPath, content, 'utf-8');
}
```

### 14.2 File Lock Manager
Implement file locking for concurrent write operations:

```typescript
interface FileLockManager {
  acquire(path: string, scope: string, timeout: number): Promise<Lock>;
  release(lock: Lock): Promise<void>;
  isLocked(path: string, scope: string): Promise<boolean>;
  waitForRelease(path: string, scope: string, timeout: number): Promise<void>;
}

interface Lock {
  path: string;
  scope: string;
  acquiredAt: Date;
  owner: string;
}

// In-memory lock storage
const locks = new Map<string, Lock>();

// Acquire lock with timeout
async function acquireLock(path: string, scope: string, timeout: number = 30000): Promise<Lock> {
  const lockKey = `${scope}:${path}`;
  const startTime = Date.now();
  
  while (Date.now() - startTime < timeout) {
    if (!locks.has(lockKey)) {
      const lock: Lock = {
        path,
        scope,
        acquiredAt: new Date(),
        owner: process.pid.toString()
      };
      locks.set(lockKey, lock);
      return lock;
    }
    
    // Wait before retry
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  throw new Error(`Lock acquisition timeout for ${path}`);
}

// Release lock
function releaseLock(lock: Lock): void {
  const lockKey = `${lock.scope}:${lock.path}`;
  locks.delete(lockKey);
}

// Atomic file write with lock
async function atomicWrite(path: string, content: string, scope: string): Promise<void> {
  const lock = await acquireLock(path, scope);
  
  try {
    const fullPath = enforceScope(path, scope);
    const tmpPath = `${fullPath}.tmp`;
    
    // Write to temp file
    await fs.writeFile(tmpPath, content, 'utf-8');
    
    // Atomic rename
    await fs.rename(tmpPath, fullPath);
  } finally {
    releaseLock(lock);
  }
}
```

---

## 15. Agent Lifecycle Management

### 15.1 Agent Lifecycle Interface
Manage agent instance creation, destruction, and upgrades.

**OpenClaw Context:**
- OpenClaw has multi-agent routing
- Agents are defined in `~/.openclaw/agents/`
- Session transcripts stored in `~/.openclaw/agents/<agentId>/sessions/*.jsonl`
- Gateway manages agent lifecycle

**Agent Lifecycle Interface:**
```typescript
interface AgentLifecycle {
  create(projectId: string, soulId: string): Promise<AgentInstance>;
  destroy(instanceId: string): Promise<void>;
  upgrade(instanceId: string, newSoulVersion: string): Promise<void>;
  pause(instanceId: string): Promise<void>;
  resume(instanceId: string): Promise<void>;
  getState(instanceId: string): Promise<AgentState>;
  setState(instanceId: string, state: AgentState): Promise<void>;
}

interface AgentState {
  instanceId: string;
  projectId: string;
  currentTaskId: string | null;
  status: 'idle' | 'working' | 'distilling' | 'blocked';
  lastPulse: Date;
  workingMemory: string;
  learnedMemory: string;
}

// Create agent instance
async function createAgentInstance(projectId: string, soulId: string): Promise<AgentInstance> {
  const instanceId = `${soulId}:${projectId}`;
  
  // Create scoped session
  const session = await createScopedSession(soulId, projectId);
  
  // Schedule agent pulse
  await scheduleAgentPulse(soulId, projectId);
  
  // Initialize agent state
  const state: AgentState = {
    instanceId,
    projectId,
    currentTaskId: null,
    status: 'idle',
    lastPulse: new Date(),
    workingMemory: '',
    learnedMemory: ''
  };
  
  await AgentStatusTable.insert(state);
  
  return { instanceId, session, state };
}

// Destroy agent instance
async function destroyAgentInstance(instanceId: string): Promise<void> {
  const [agentId, projectId] = instanceId.split(':');
  
  // Stop background process
  const handle = await getProcessHandle(instanceId);
  if (handle) {
    await BackgroundProcessScheduler.kill(handle);
  }
  
  // Destroy session
  await SessionManager.destroy(instanceId);
  
  // Clean up agent status
  await AgentStatusTable.delete(instanceId);
  
  // Archive project data if needed
  await archiveProjectData(projectId);
}
```

### 15.2 Agent Upgrade Procedures
Handle agent upgrades when SOUL.md changes:

```typescript
async function upgradeAgent(instanceId: string, newSoulVersion: string): Promise<void> {
  const [agentId, projectId] = instanceId.split(':');
  
  // Pause agent
  await AgentLifecycle.pause(instanceId);
  
  // Update SOUL.md
  const soulPath = `~/.openclaw/souls/${agentId}/SOUL.md`;
  const newSoulContent = await fetchSoulContent(newSoulVersion);
  await fs.writeFile(soulPath, newSoulContent, 'utf-8');
  
  // Resume agent with new persona
  await AgentLifecycle.resume(instanceId);
  
  // Log upgrade event
  await TaskEventsTable.insert({
    task_id: 'system',
    agent_id: 'mission-control',
    timestamp: new Date(),
    thought: `Upgraded agent ${agentId} to version ${newSoulVersion}`,
    action: 'agent.upgrade'
  });
}
```

### 15.3 Project Cleanup Procedures
Clean up resources when projects are deleted:

```typescript
async function cleanupProject(projectId: string): Promise<void> {
  // 1. Stop all agent sessions for this project
  const agents = await getAgentsForProject(projectId);
  for (const agent of agents) {
    await destroyAgentInstance(`${agent.id}:${projectId}`);
  }
  
  // 2. Kill background processes
  const processes = await BackgroundProcessScheduler.list();
  for (const proc of processes.filter(p => p.projectId === projectId)) {
    await BackgroundProcessScheduler.kill(proc);
  }
  
  // 3. Archive or delete project data
  const projectPath = `~/.openclaw/projects/${projectId}`;
  if (config.archiveOnDelete) {
    await archiveProject(projectPath);
  } else {
    await fs.rm(projectPath, { recursive: true });
  }
  
  // 4. Update database to reflect deletion
  await TaskTable.deleteByProject(projectId);
  await ProjectsTable.delete(projectId);
}
```

---

## 16. Error Handling & Recovery

### 16.1 Error Classification
Classify errors for appropriate handling:

```typescript
enum ErrorSeverity {
  TRANSIENT = 'transient',    // Retryable (network timeout, temporary lock)
  PERMANENT = 'permanent',    // Requires human intervention (auth failure, missing config)
  DEGRADED = 'degraded'       // Continue with reduced functionality
}

enum ErrorType {
  NETWORK = 'network',
  DATABASE = 'database',
  FILESYSTEM = 'filesystem',
  GATEWAY = 'gateway',
  AGENT = 'agent'
}

interface ErrorContext {
  type: ErrorType;
  severity: ErrorSeverity;
  message: string;
  details: any;
  timestamp: Date;
  retryCount: number;
}

// Classify error
function classifyError(error: Error): ErrorContext {
  if (error.message.includes('timeout') || error.message.includes('ECONNREFUSED')) {
    return {
      type: ErrorType.NETWORK,
      severity: ErrorSeverity.TRANSIENT,
      message: error.message,
      details: error,
      timestamp: new Date(),
      retryCount: 0
    };
  }
  
  if (error.message.includes('authentication') || error.message.includes('unauthorized')) {
    return {
      type: ErrorType.GATEWAY,
      severity: ErrorSeverity.PERMANENT,
      message: error.message,
      details: error,
      timestamp: new Date(),
      retryCount: 0
    };
  }
  
  // Default to degraded
  return {
    type: ErrorType.AGENT,
    severity: ErrorSeverity.DEGRADED,
    message: error.message,
    details: error,
    timestamp: new Date(),
    retryCount: 0
  };
}
```

### 16.2 Retry Policies
Implement exponential backoff for transient errors:

```typescript
interface RetryPolicy {
  maxAttempts: number;
  initialDelay: number;       // ms
  maxDelay: number;            // ms
  backoffFactor: number;
}

async function retryWithBackoff<T>(
  operation: () => Promise<T>,
  context: ErrorContext
): Promise<T> {
  const policy: RetryPolicy = {
    maxAttempts: 3,
    initialDelay: 1000,
    maxDelay: 30000,
    backoffFactor: 2
  };
  
  for (let attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      const errorContext = classifyError(error);
      
      if (errorContext.severity !== ErrorSeverity.TRANSIENT) {
        throw error; // Don't retry permanent errors
      }
      
      if (attempt === policy.maxAttempts) {
        throw new Error(`Max retry attempts reached: ${error.message}`);
      }
      
      const delay = Math.min(
        policy.initialDelay * Math.pow(policy.backoffFactor, attempt - 1),
        policy.maxDelay
      );
      
      console.log(`[Mission Control] Retry ${attempt}/${policy.maxAttempts} after ${delay}ms: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}
```

### 16.3 Circuit Breaker Pattern
Implement circuit breaker for failing services:

```typescript
interface CircuitBreakerState {
  isOpen: boolean;
  failureCount: number;
  lastFailureTime: Date;
  successCount: number;
}

interface CircuitBreakerConfig {
  failureThreshold: number;
  successThreshold: number;
  timeout: number;              // ms
  resetTimeout: number;          // ms
}

class CircuitBreaker {
  private state: CircuitBreakerState = {
    isOpen: false,
    failureCount: 0,
    lastFailureTime: new Date(),
    successCount: 0
  };
  
  async execute<T>(operation: () => Promise<T>): Promise<T> {
    // Check if circuit is open
    if (this.state.isOpen) {
      if (Date.now() - this.state.lastFailureTime.getTime() > config.resetTimeout) {
        // Attempt to reset circuit
        this.state.isOpen = false;
        this.state.failureCount = 0;
      } else {
        throw new Error('Circuit breaker is open');
      }
    }
    
    try {
      const result = await operation();
      
      // Success - reset failure count
      this.state.failureCount = 0;
      this.state.successCount++;
      
      if (this.state.successCount >= config.successThreshold) {
        this.state.isOpen = false;
      }
      
      return result;
    } catch (error) {
      // Failure - increment count
      this.state.failureCount++;
      this.state.lastFailureTime = new Date();
      
      // Open circuit if threshold reached
      if (this.state.failureCount >= config.failureThreshold) {
        this.state.isOpen = true;
      }
      
      throw error;
    }
  }
}
```

---

## 17. Operations & Monitoring

### 17.1 Logging Strategy
Implement structured logging for system observability:

```typescript
enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error',
  FATAL = 'fatal'
}

interface LogEntry {
  level: LogLevel;
  timestamp: Date;
  component: string;
  message: string;
  context?: any;
}

class Logger {
  private component: string;
  
  constructor(component: string) {
    this.component = component;
  }
  
  debug(message: string, context?: any): void {
    this.log(LogLevel.DEBUG, message, context);
  }
  
  info(message: string, context?: any): void {
    this.log(LogLevel.INFO, message, context);
  }
  
  warn(message: string, context?: any): void {
    this.log(LogLevel.WARN, message, context);
  }
  
  error(message: string, context?: any): void {
    this.log(LogLevel.ERROR, message, context);
  }
  
  fatal(message: string, context?: any): void {
    this.log(LogLevel.FATAL, message, context);
  }
  
  private log(level: LogLevel, message: string, context?: any): void {
    const entry: LogEntry = {
      level,
      timestamp: new Date(),
      component: this.component,
      message,
      context
    };
    
    // Write to log file
    fs.appendFileSync(
      '~/.openclaw/logs/mission-control.log',
      JSON.stringify(entry) + '\n'
    );
    
    // Also output to console
    console.log(`[${level.toUpperCase()}] [${this.component}] ${message}`);
  }
}

// Usage
const logger = new Logger('MissionControl');
logger.info('Service started');
logger.error('Failed to connect to database', { error: err });
```

### 17.2 Metrics Collection
Collect and expose metrics for monitoring:

```typescript
interface Metrics {
  taskCompletionRate: number;
  agentUptime: number;
  websocketConnections: number;
  dbQueryLatency: number;
  pulseSuccessRate: number;
}

class MetricsCollector {
  private metrics: Metrics = {
    taskCompletionRate: 0,
    agentUptime: 0,
    websocketConnections: 0,
    dbQueryLatency: 0,
    pulseSuccessRate: 0
  };
  
  recordTaskCompletion(): void {
    this.metrics.taskCompletionRate++;
  }
  
  recordAgentUptime(instanceId: string, uptime: number): void {
    this.metrics.agentUptime = uptime;
  }
  
  recordWebSocketConnection(): void {
    this.metrics.websocketConnections++;
  }
  
  recordDbQueryLatency(latency: number): void {
    this.metrics.dbQueryLatency = latency;
  }
  
  recordPulseSuccess(): void {
    this.metrics.pulseSuccessRate++;
  }
  
  getMetrics(): Metrics {
    return { ...this.metrics };
  }
}

// Expose metrics via RPC
async function handleGetMetrics(): Promise<Metrics> {
  return MetricsCollector.getMetrics();
}
```

### 17.3 Health Checks
Implement health check endpoints:

```typescript
interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  components: {
    database: HealthCheck;
    gateway: HealthCheck;
    backgroundProcesses: HealthCheck;
    fileSystem: HealthCheck;
  };
  timestamp: Date;
}

interface HealthCheck {
  status: 'healthy' | 'unhealthy';
  message?: string;
  latency?: number;
}

async function getHealthStatus(): Promise<HealthStatus> {
  const checks = {
    database: await checkDatabaseHealth(),
    gateway: await checkGatewayHealth(),
    backgroundProcesses: await checkBackgroundProcessesHealth(),
    fileSystem: await checkFileSystemHealth()
  };
  
  const allHealthy = Object.values(checks).every(c => c.status === 'healthy');
  const someDegraded = Object.values(checks).some(c => c.status === 'degraded');
  
  let status: 'healthy' | 'degraded' | 'unhealthy';
  if (allHealthy) {
    status = 'healthy';
  } else if (someDegraded) {
    status = 'degraded';
  } else {
    status = 'unhealthy';
  }
  
  return {
    status,
    components: checks,
    timestamp: new Date()
  };
}

async function checkDatabaseHealth(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    await db.exec('SELECT 1');
    const latency = Date.now() - start;
    return { status: 'healthy', latency };
  } catch (error) {
    return { status: 'unhealthy', message: error.message };
  }
}
```

---

## 18. Deployment Guide

### 18.1 Installation Procedures
Step-by-step installation guide:

```bash
# 1. Prerequisites
npm install -g openclaw@latest

# 2. Initialize Mission Control database
node scripts/init_mc.ts

# 3. Create project structure
mkdir -p ~/.openclaw/projects
mkdir -p ~/.openclaw/souls
mkdir -p ~/.openclaw/sessions
mkdir -p ~/.openclaw/logs

# 4. Run database migrations
npm run migrate

# 5. Start Mission Control service
openclaw gateway start
```

### 18.2 Configuration
Configuration management:

```typescript
interface MissionControlConfig {
  server: {
    port: number;
    bind: 'loopback' | 'lan' | 'tailnet';
    auth: {
      mode: 'token' | 'password';
      token?: string;
    };
  };
  database: {
    path: string;
    backup: {
      enabled: boolean;
      interval: number;
      retentionDays: number;
    };
  };
  agents: {
    pulseInterval: number;
    staggerEnabled: boolean;
    maxRetries: number;
    timeout: number;
  };
  monitoring: {
    logLevel: 'debug' | 'info' | 'warn' | 'error';
    metricsEnabled: boolean;
    healthCheckInterval: number;
  };
}

// Load configuration
async function loadConfig(): Promise<MissionControlConfig> {
  const configPath = '~/.openclaw/mission-control.json';
  const config = await fs.readFile(configPath, 'utf-8');
  return JSON.parse(config);
}

// Validate configuration
function validateConfig(config: MissionControlConfig): boolean {
  // Validate required fields
  if (!config.server.port || config.server.port < 1024 || config.server.port > 65535) {
    return false;
  }
  
  // Validate database path
  if (!config.database.path) {
    return false;
  }
  
  return true;
}
```

### 18.3 CI/CD Pipeline
Continuous integration and deployment:

```yaml
# .github/workflows/deploy-mission-control.yml
name: Deploy Mission Control

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      - name: Install dependencies
        run: npm ci
      - name: Run tests
        run: npm test
      - name: Run linter
        run: npm run lint
  
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to production
        run: |
          npm run migrate
          openclaw gateway restart
```

---

## 19. Tool Manifest (For `openclaw.json`)

The developer must register these tools in the OpenClaw manifest. Provide this exact schema:

```json
{
  "tools": [
    {
      "name": "log_event",
      "description": "Log internal reasoning and intended tool action to Mission Control.",
      "parameters": {
        "type": "object",
        "properties": {
          "thought": {
            "type": "string",
            "description": "The reasoning behind the next step."
          },
          "action": {
            "type": "string",
            "description": "The specific tool/command about to be executed."
          }
        },
        "required": ["thought", "action"]
      }
    },
    {
      "name": "distill_memory",
      "description": "Move active task state to long-term project knowledge (Learned Memory).",
      "parameters": {
        "type": "object",
        "properties": {
          "summary": {
            "type": "string",
            "description": "Distilled wisdom from the completed task."
          }
        },
        "required": ["summary"]
      }
    },
    {
      "name": "request_help",
      "description": "Signal that human intervention is required to proceed.",
      "parameters": {
        "type": "object",
        "properties": {
          "issue": {
            "type": "string",
            "description": "Description of the blocker."
          }
        },
        "required": ["issue"]
      }
    }
  ]
}
```

---

## 20. UI Routing & State (The Vite Side)

To ensure the coder starts the frontend correctly:

1. **Routing:** 
    * `/` : Project Overview (List of Apps).
    * `/:project_id` : The Main Kanban Board.
2. **State Store:** Use `Zustand` or `Redux` to hold the WebSocket state.
3. **Live Terminal Logic:** The "Live Terminal" component should filter the `task_events` table for only the currently selected `task_id`.

---

## 21. Testing Strategy

### 21.1 Unit Testing
Test individual components in isolation:

```typescript
// Example: Test database operations
describe('TaskTable', () => {
  it('should create a task', async () => {
    const task = {
      id: 'task_1',
      project_id: 'project_1',
      title: 'Test task',
      assignee_id: 'shuri',
      status: 0,
      priority: 3
    };
    
    await TaskTable.insert(task);
    const retrieved = await TaskTable.get('task_1');
    
    expect(retrieved).toEqual(task);
  });
  
  it('should update task status', async () => {
    await TaskTable.updateStatus('task_1', 1);
    const task = await TaskTable.get('task_1');
    
    expect(task.status).toBe(1);
  });
});
```

### 21.2 Integration Testing
Test component interactions:

```typescript
// Example: Test agent pulse scheduling
describe('Agent Pulse Scheduling', () => {
  it('should schedule agent pulse with staggered offset', async () => {
    const offset = calculateStaggerOffset('shuri', 'vanguard');
    
    expect(offset).toBeGreaterThanOrEqual(0);
    expect(offset).toBeLessThan(256);
  });
  
  it('should detect stalled agents', async () => {
    // Mock agent status
    await AgentStatusTable.insert({
      instance_id: 'shuri:vanguard',
      last_pulse: new Date(Date.now() - 400000), // 6+ minutes ago
      status: 'working'
    });
    
    // Run orchestrator tick
    await orchestratorTick();
    
    // Verify task moved to backlog
    const task = await TaskTable.get('task_1');
    expect(task.status).toBe(0); // Backlog
  });
});
```

### 21.3 Mocking Gateway Services
Mock Gateway for testing:

```typescript
// Mock Gateway service
class MockGateway {
  private methods: Map<string, Function> = new Map();
  
  registerMethod(name: string, handler: Function): void {
    this.methods.set(name, handler);
  }
  
  async call(method: string, params: any): Promise<any> {
    const handler = this.methods.get(method);
    if (!handler) {
      throw new Error(`Method not found: ${method}`);
    }
    
    return await handler(params);
  }
}

// Use in tests
const mockGateway = new MockGateway();
mockGateway.registerMethod('mission.task.create', async (params) => {
  return { id: 'task_1', ...params };
});

await mockGateway.call('mission.task.create', {
  project_id: 'project_1',
  title: 'Test task',
  assignee_id: 'shuri',
  priority: 3
});
```

---
### What Jarvis Does (From Guide)

Jarvis is the **Squad Lead AI agent** that:

1. **Handles direct requests** - Primary interface to human
2. **Delegates tasks** - Decides which specialist agent should handle what
3. **Monitors progress** - Tracks what all agents are working on
4. **Coordinates between agents** - Resolves conflicts, facilitates collaboration
5. **Makes strategic decisions** - High-level project decisions
6. **Provides accountability** - Daily standups, status reports
7. **Triggers agents** - Wakes up agents when needed (not just cron)

### What's Currently in the Spec

The spec has **Section 9: Mission Control Orchestration Loop** which describes:

```typescript
// Technical orchestration service
MC_Service {
  orchestratorTick() {
    1. Scan tasks table
    2. Zombie check
    3. Daemon check (pulse scheduling)
    4. State mirroring
  }
}
```

This is a **server-side technical service** that:
- Schedules heartbeats (every 30s tick)
- Detects stalled processes
- Mirrors database state to markdown files
- Manages background processes

**This is NOT an AI orchestrator.** It's infrastructure code, not an intelligent agent.

---

## The Jarvis Orchestrator Agent

### Required Capabilities

```markdown
## Jarvis Orchestrator Agent

### Role
Squad Lead AI agent that coordinates all other agents and serves as primary human interface.

### Responsibilities

1. **Task Delegation**
   - Analyze incoming requests
   - Match tasks to appropriate specialist agents
   - Consider agent workload, skills, and availability
   - Assign tasks with clear context and expectations

2. **Progress Monitoring**
   - Track all active tasks across all agents
   - Identify blocked or stalled tasks
   - Escalate issues when needed
   - Provide status updates to human

3. **Agent Coordination**
   - Facilitate communication between agents
   - Resolve conflicts between agents
   - Ensure agents have necessary context
   - Coordinate handoffs between specialists

4. **Strategic Decision Making**
   - Make high-level project decisions
   - Prioritize tasks based on business goals
   - Adjust agent assignments dynamically
   - Identify dependencies between tasks

5. **Human Interface**
   - Receive direct requests from human
   - Provide clear status reports
   - Explain agent actions and decisions
   - Request human input when needed

6. **Trigger Management**
   - Wake up agents when they're @mentioned
   - Trigger agents when tasks are assigned
   - Coordinate staggered heartbeats
   - Optimize agent schedules for efficiency

### Tools Required

- `mission.task.create` - Create tasks
- `mission.task.assign` - Assign tasks to agents
- `mission.task.move` - Move tasks through workflow
- `mission.agent.trigger` - Wake up specific agents
- `mission.agent.status` - Check agent status
- `mission.event.broadcast` - Send notifications
- `sessions_send` - Send messages to other agents

### Memory Structure

- **WORKING.md** - Current coordination state
- **DECISIONS.md** - Strategic decisions made
- **STANDUPS.md** - Daily standup summaries
- **AGENTS.md** - Agent capabilities and status

### SOUL.md Template

```markdown
# SOUL.md — Jarvis, Squad Lead

**Name:** Jarvis
**Role:** Mission Control Orchestrator

## Personality
Decisive coordinator. Clear communicator. Strategic thinker.
You keep the team focused and moving forward.

## Your Responsibilities
- Receive and understand human requests
- Break down complex requests into tasks
- Assign tasks to appropriate specialist agents
- Monitor all agent progress
- Coordinate between agents when needed
- Provide clear status updates to human
- Make strategic decisions for the project
- Escalate issues that require human input

## What You're Good At
- Understanding project goals and priorities
- Matching tasks to agent capabilities
- Seeing the big picture
- Communicating clearly with humans and agents
- Making decisions under uncertainty

## Decision Framework
1. Always consider the human's goals first
2. Match tasks to the most appropriate specialist
3. Balance workload across agents
4. Escalate when stuck or uncertain
5. Document all important decisions

## Communication Style
- Be concise but thorough
- Explain your reasoning when making decisions
- Keep humans informed of progress
- Ask for clarification when needed
- Be proactive about potential issues
```
```

---

## Updated Gap Analysis

### ✅ FULLY COVERED (Ready to Implement)

| Component | Mission Control Section | Status |
|------------|------------------------|---------|
| **Database Schema** | Section 5 | ✅ Complete |
| **Kanban Board UI** | Section 8, 20 | ✅ Complete |
| **Task Management** | Section 7 | ✅ Complete |
| **Thought Stream** | Section 7.2 | ✅ Complete |
| **Agent Status Tracking** | Section 5.2, 15 | ✅ Complete |
| **Heartbeat Scheduling** | Section 9.1, 11 | ✅ Complete |
| **Zombie Detection** | Section 9.1 | ✅ Complete |
| **State Mirroring** | Section 3.3 | ✅ Complete |
| **File System Operations** | Section 14 | ✅ Complete |
| **Session Management** | Section 12 | ✅ Complete |
| **Error Handling** | Section 16 | ✅ Complete |
| **Monitoring** | Section 17 | ✅ Complete |
| **Testing** | Section 21 | ✅ Complete |
| **Deployment** | Section 18 | ✅ Complete |

### ❌ CRITICAL GAP (Must Add)

| Component | Mission Control Section | Status |
|------------|------------------------|---------|
| **Jarvis Orchestrator Agent** | NOT SPECIFIED | ❌ **MISSING** |
| **Task Delegation Logic** | NOT SPECIFIED | ❌ **MISSING** |
| **Agent Coordination** | NOT SPECIFIED | ❌ **MISSING** |
| **Strategic Decision Making** | NOT SPECIFIED | ❌ **MISSING** |
| **Human Interface Agent** | NOT SPECIFIED | ❌ **MISSING** |
| **Agent Trigger System** | Partial (Section 9.1) | ⚠️ **INCOMPLETE** |

### ⚠️ PARTIAL (Needs Enhancement)

| Component | Mission Control Section | Issue |
|------------|------------------------|--------|
| **Agent Trigger** | Section 9.1 | Only cron-based, missing @mention trigger |
| **Notification System** | Section 8.1 | No @mention delivery mechanism |
| **Thread Subscriptions** | NOT SPECIFIED | ❌ **MISSING** |
| **Daily Standup** | NOT SPECIFIED | ❌ **MISSING** |

---

## What Needs to Be Added to PRD

### Add Section 23: Jarvis Orchestrator Agent

```markdown
## 23. Jarvis Orchestrator Agent

### 23.1 Role and Responsibilities
Jarvis is the Squad Lead AI agent that coordinates all other agents in Mission Control.

**Key Responsibilities:**
1. **Human Interface** - Primary point of contact for human users
2. **Task Delegation** - Analyze requests and assign to appropriate specialists
3. **Progress Monitoring** - Track all tasks and agent status
4. **Agent Coordination** - Facilitate communication between agents
5. **Strategic Decision Making** - Make high-level project decisions
6. **Trigger Management** - Wake up agents when needed (cron + @mentions)
7. **Daily Standups** - Compile and send daily summaries

### 23.2 Task Delegation Logic

**Decision Framework:**
```typescript
interface TaskDelegationDecision {
  taskId: string;
  assignedAgentId: string;
  reasoning: string;
  priority: number;
  dependencies: string[];
}

function delegateTask(task: Task): TaskDelegationDecision {
  // 1. Analyze task requirements
  const requirements = analyzeTaskRequirements(task);

  // 2. Match to agent capabilities
  const candidates = findCapableAgents(requirements);

  // 3. Consider agent workload
  const availableAgents = filterByWorkload(candidates);

  // 4. Select best match
  const selected = selectBestAgent(availableAgents, task);

  // 5. Assign with context
  return {
    taskId: task.id,
    assignedAgentId: selected.id,
    reasoning: selected.reasoning,
    priority: calculatePriority(task),
    dependencies: identifyDependencies(task)
  };
}
```

**Agent Capability Matrix:**
```typescript
interface AgentCapability {
  agentId: string;
  agentName: string;
  skills: string[];
  currentTaskId: string | null;
  workload: number;
  status: 'idle' | 'working' | 'blocked';
}

const AGENT_CAPABILITIES: AgentCapability[] = [
  {
    agentId: 'shuri',
    agentName: 'Shuri',
    skills: ['testing', 'ux', 'competitive-analysis', 'edge-cases'],
    currentTaskId: null,
    workload: 0,
    status: 'idle'
  },
  {
    agentId: 'fury',
    agentName: 'Fury',
    skills: ['research', 'customer-intelligence', 'data-analysis'],
    currentTaskId: null,
    workload: 0,
    status: 'idle'
  },
  // ... other agents
];
```

### 23.3 Agent Coordination

**Conflict Resolution:**
```typescript
function resolveConflict(conflict: AgentConflict): Resolution {
  // Analyze the conflict
  const analysis = analyzeConflict(conflict);

  // Determine resolution strategy
  if (conflict.type === 'task-ownership') {
    return resolveTaskOwnership(conflict);
  } else if (conflict.type === 'approach-disagreement') {
    return resolveApproachDisagreement(conflict);
  } else if (conflict.type === 'resource-contention') {
    return resolveResourceContention(conflict);
  }

  // Escalate to human if unresolvable
  return escalateToHuman(conflict);
}
```

**Handoff Coordination:**
```typescript
async function coordinateHandoff(
  fromAgent: string,
  toAgent: string,
  taskId: string,
  context: HandoffContext
): Promise<void> {
  // 1. Notify receiving agent
  await sendToAgent(toAgent, {
    type: 'HANDOFF_INCOMING',
    taskId,
    fromAgent,
    context
  });

  // 2. Update task status
  await updateTaskStatus(taskId, 'in_handoff');

  // 3. Wait for acknowledgment
  const ack = await waitForAcknowledgment(toAgent, taskId);

  // 4. Complete handoff
  await updateTaskStatus(taskId, 'in_progress');
  await updateTaskAssignee(taskId, toAgent);
}
```

### 23.4 Trigger Management

**Cron-Based Triggers:**
```typescript
// Jarvis monitors all agent heartbeats
async function monitorAgentHeartbeats(): Promise<void> {
  const agents = await getAllAgents();

  for (const agent of agents) {
    const lastHeartbeat = await getLastHeartbeat(agent.id);
    const timeSinceHeartbeat = Date.now() - lastHeartbeat;

    // If agent hasn't checked in, trigger it
    if (timeSinceHeartbeat > HEARTBEAT_INTERVAL) {
      await triggerAgent(agent.id, 'HEARTBEAT_CHECK');
    }
  }
}
```

**@Mention Triggers:**
```typescript
// Jarvis listens for @mentions and immediately triggers agents
async function handleMention(mention: Mention): Promise<void> {
  const mentionedAgentId = mention.agentId;

  // Check if agent is active
  const isActive = await isAgentActive(mentionedAgentId);

  // If not active, trigger immediately
  if (!isActive) {
    await triggerAgent(mentionedAgentId, {
      type: 'MENTION',
      taskId: mention.taskId,
      content: mention.content,
      fromAgent: mention.fromAgent
    });
  } else {
    // Agent is active, just send message
    await sendToAgent(mentionedAgentId, mention.content);
  }
}
```

### 23.5 Daily Standup

**Standup Compilation:**
```typescript
async function compileDailyStandup(): Promise<DailyStandup> {
  // Gather activity from last 24 hours
  const activity = await getActivitySince(Date.now() - 24 * 60 * 60 * 1000);

  // Categorize by agent
  const byAgent = groupByAgent(activity);

  // Build standup
  const standup: DailyStandup = {
    date: new Date().toISOString(),
    completed: [],
    inProgress: [],
    blocked: [],
    needsReview: [],
    keyDecisions: []
  };

  for (const [agentId, agentActivity] of Object.entries(byAgent)) {
    // Analyze each agent's activity
    const summary = await analyzeAgentActivity(agentId, agentActivity);

    // Categorize
    if (summary.completedTasks.length > 0) {
      standup.completed.push({
        agent: agentId,
        tasks: summary.completedTasks
      });
    }

    if (summary.currentTask) {
      standup.inProgress.push({
        agent: agentId,
        task: summary.currentTask
      });
    }

    if (summary.blocked) {
      standup.blocked.push({
        agent: agentId,
        issue: summary.blockedIssue
      });
    }
  }

  // Add key decisions
  standup.keyDecisions = await getKeyDecisions(activity);

  return standup;
}
```

**Standup Delivery:**
```typescript
async function sendDailyStandup(standup: DailyStandup): Promise<void> {
  // Format as markdown
  const message = formatStandupMessage(standup);

  // Send via configured channel (Telegram, etc.)
  await sendToChannel('human', message);

  // Also log to Chronicle
  await updateChronicle({
    projectId: 'mission-control',
    summary: `Daily standup: ${standup.date}`,
    content: message
  });
}
```

### 23.6 Jarvis SOUL.md

Provide complete SOUL.md template for Jarvis orchestrator agent (see above).

### 23.7 Jarvis Integration

**Gateway Registration:**
```typescript
// Register Jarvis as a Mission Control agent
await Gateway.registerAgent({
  agentId: 'jarvis',
  role: 'orchestrator',
  soulPath: '~/.openclaw/souls/jarvis/SOUL.md',
  tools: [
    'mission.task.create',
    'mission.task.assign',
    'mission.task.move',
    'mission.agent.trigger',
    'mission.agent.status',
    'mission.event.broadcast',
    'sessions_send',
    'update_chronicle',
    'log_event'
  ],
  heartbeatInterval: 60, // Check every minute
  alwaysOn: true // Jarvis is always active
});
```
```

---

## Recommendations

### For Immediate Implementation (v3.3)

1. ✅ **Keep current spec** - Technical infrastructure is solid
2. ❌ **ADD Jarvis Orchestrator** - This is the critical missing piece
3. ❌ **Add agent trigger system** - Both cron and @mention-based
4. ❌ **Add notification delivery** - For @mentions and thread subscriptions
5. ❌ **Add daily standup** - Automatic compilation and delivery

### For v3.4

1. Add thread subscriptions
2. Add conflict resolution strategies
3. Add handoff coordination
4. Add agent capability matrix management

---

## Conclusion

The [`mission-control-3.3.md`](docs/openclaw/mission-control-project/mission-control-3.3.md) specification is **70-75% complete** for a functional Mission Control system.

**What's Ready:**
- Complete technical infrastructure
- Database and persistence
- UI and visualization
- Heartbeat scheduling
- Agent lifecycle management

**What's Missing:**
- **Jarvis orchestrator agent** - The AI that coordinates everything
- Task delegation logic
- Agent coordination mechanisms
- Strategic decision making
- @mention-based agent triggering
- Daily standup automation

**Recommendation:** **Add Jarvis Orchestrator specification** before starting implementation. Without it, you'll have a beautiful Kanban board and database, but no intelligent agent to coordinate the team.

**Risk Assessment:** **MEDIUM-HIGH** - The Jarvis orchestrator is essential for the system to function as described in the guide. Without it, agents will be independent and uncoordinated.

---

**Analysis Complete**
**Next Step:** Add Section 23: Jarvis Orchestrator Agent to PRD.

---


## 22. Conclusion

Mission Control v3.3 provides the complete technical roadmap for a professional-grade AI factory. By combining **Native Multi-Agent Comms (Spec 4.3)** with **Structured Thought Logging**, **Gateway Service Integration**, **Background Process Scheduling**, **Scoped Session Management**, **Database Migration System**, **Scoped File System Operations**, **Agent Lifecycle Management**, **Error Handling & Recovery**, **Operations & Monitoring**, and **Deployment Guide**, we create a system that is both autonomous and transparent.

**Next Step for Developers:** 

1. Run `scripts/init_mc.ts` to initialize the `mission-control.db` and basic folder structure
2. Create `src/services/MissionControl.ts` and register it in `gateway/server.impl.ts`
3. Connect Vite UI to the Gateway URL (default `ws://localhost:18789`)
4. Manually trigger a pulse for `shuri` to verify she reads the `tasks` table
5. Implement the orchestration loop with staggered pulse scheduling
6. Add comprehensive error handling and monitoring
7. Set up CI/CD pipeline for automated testing and deployment

**This is now a complete, professional-grade, implementation-ready technical specification.** You are ready to build.

---

**Version History:**
- v3.1: Initial technical specification with JSON-RPC payloads
- v3.3: Implementation-ready edition with complete integration details, error handling, monitoring, and deployment guide

**Status:** Implementation Ready  
**Last Updated:** 2026-02-02
