# PRD: OpenClaw Mission Control (Project Vanguard)
**Version:** 3.5 (Specialist Agents Edition)
**Status:** Implementation Ready
**Framework:** OpenClaw Core (TypeScript/Node)
**Security:** Isolated Scoped Environments (Local-First)

---

## 0. Developer Prerequisites
**Mandatory reading for the implementation team to ensure "OpenClaw-native" behavior:**

1. **Fundamental Philosophy:** [1.1 Key Concepts](https://deepwiki.com/openclaw/openclaw/1.1-key-concepts)
2. **Communication Protocol:** [3.2 Gateway Protocol](https://deepwiki.com/openclaw/openclaw/3.2-gateway-protocol)
3. **Gateway Services:** [3.3 Gateway Service Management](https://deepwiki.com/openclaw/openclaw/3.3-gateway-service-management)
4. **Multi-Agent System:** [4.3 Multi-Agent Configuration](https://deepwiki.com/openclaw/openclaw/4.3-multi-agent-configuration)
5. **Agent Execution:** [5 Agent System](https://deepwiki.com/openclaw/openclaw/5-agent-system)
6. **Memory Layering:** [Snowan Memory System Deep Dive](https://snowan.gitbook.io/study-notes/ai-blogs/openclaw-memory-system-deep-dive)
7. **Overall reference:** [openclaw-docs-llms.txt](./openclaw-docs-llms.txt)

---

## 1. System Vision

Mission Control is the **Control Plane** for OpenClaw. It transforms the system from a reactive "Chatbot" into an autonomous **"AI Factory."**

### 1.1 Architecture Overview

Mission Control has **three distinct layers**:

| Layer | Component | Type | Responsibility |
|-------|-----------|------|----------------|
| **Orchestration Layer** | Nestor (main agent) | AI Agent | Task delegation, agent coordination, human interface, strategic decisions |
| **Specialist Layer** | 5 Specialists (Sophie, Elena, David, Igor, Marco) | AI Agents | Execute specialized tasks via proper identity/role files |
| **Technical Layer** | MC_Service (Gateway service) | TypeScript Service | Database persistence, WebSocket broadcasting, Kanban state management |

### 1.2 What OpenClaw Already Provides ✅

**DO NOT REINVENT:**
- **Agent Management** - `openclaw agents add/list/delete` (already built)
- **Session Management** - Native session tracking in `~/.openclaw/agents/<agentId>/sessions/` (already built)
- **Agent-to-Agent Comms** - `sessions_send` tool (already built)
- **Agent Spawning** - `sessions_spawn` tool (already built)
- **Agent Status** - `sessions_list` tool (already built)
- **Heartbeat Scheduling** - `openclaw cron` (already built)
- **Gateway Services** - Service registration and RPC routing (already built)
- **WebSocket** - Native Gateway WebSocket (already built)
- **File System Tools** - `read`, `write`, `edit` with path security (already built)

**What Mission Control adds:**
- **Visual Interface** - Kanban board, thought stream, agent status cards
- **Task Database** - SQLite persistence for tasks and events
- **Orchestration Intelligence** - Nestor coordinates specialists
- **Shared State** - All agents see the same tasks and context
- **Human Observability** - Live monitoring of agent activity

---

## 2. High-Level Architecture

```mermaid
graph TB
    subgraph "Orchestration Layer"
        Nestor[Nestor (main agent)<br/>Squad Lead]
        Nestor -->|delegates| Sophie[Sophie-FE<br/>Frontend/UI]
        Nestor -->|delegates| Elena[Elena-DBA<br/>Database/Backend]
        Nestor -->|delegates| David[David-QA<br/>Testing]
        Nestor -->|delegates| Igor[Igor-coder<br/>General Coding]
        Nestor -->|delegates| Marco[Marco-reviewer<br/>Code Review]
    end

    subgraph "Specialist Layer"
        Sophie -.->|sessions_send|.-> Elena
        Sophie -.->|sessions_send|.-> Igor
        David -.->|sessions_send|.-> Marco
    end

    subgraph "Technical Layer"
        UI[Vite + React + Shadcn]
        GW[OpenClaw Gateway]
        MC[MC_Service<br/>Gateway Service]
        DB[(SQLite: mission-control.db)]
    end

    UI -->|WebSocket JSON-RPC 2.0| GW
    GW -->|RPC Routes| MC
    MC <-->|CRUD| DB
```

**Agent File Structure (NEW in v3.5):**
```
~/.openclaw/agents/{agentId}/
├── IDENTITY.md      # Who is this agent (NEW in v3.5)
├── SOUL.md         # Personality, role, boundaries, Mission Control context
├── SYSTEM.md        # Tech stack, expertise (already exists)
└── sessions/        # Session history (OpenClaw native)
```

---

## 3. Nestor: The Orchestrator Agent

### 3.1 Role and Responsibilities

Nestor (main agent) is the **Squad Lead AI agent** that:

1. **Human Interface**
   - Primary point of contact for human users
   - Receives and understands requests
   - Provides clear status updates
   - Asks for clarification when needed

2. **Task Delegation**
   - Analyzes incoming requests
   - Breaks down complex tasks into subtasks
   - Matches tasks to appropriate specialist agents
   - Considers agent workload, skills, and availability
   - Assigns tasks with clear context and expectations

3. **Progress Monitoring**
   - Tracks all active tasks across all agents
   - Identifies blocked or stalled tasks
   - Escalates issues when needed
   - Provides status reports to human

4. **Agent Coordination**
   - Facilitates communication between agents via `sessions_send`
   - Resolves conflicts between agents
   - Ensures agents have necessary context
   - Coordinates handoffs between specialists
   - Manages resource contention

5. **Strategic Decision Making**
   - Makes high-level project decisions
   - Prioritizes tasks based on business goals
   - Adjusts agent assignments dynamically
   - Identifies dependencies between tasks

6. **Trigger Management**
   - Wakes up agents when they're mentioned in messages
   - Triggers agents when tasks are assigned
   - Coordinates staggered work to avoid blocking
   - Optimizes agent schedules for efficiency

7. **Daily Standups**
   - Compiles daily activity summaries
   - Reports completed, in-progress, and blocked tasks
   - Highlights key decisions and issues
   - Sends via configured channel (Telegram, etc.)

### 3.2 Tools Available to Nestor

Nestor uses **native OpenClaw tools**:

```json
{
  "native_tools": [
    "read", "write", "edit",
    "exec",
    "web_search", "web_fetch",
    "browser",
    "message",
    "tts",
    "canvas",
    "nodes",
    "cron",
    "gateway",
    "agents_list",
    "sessions_list",
    "sessions_history",
    "sessions_send",
    "sessions_spawn",
    "session_status"
  ],
  "mission_control_tools": [
    "log_event",           // Log thoughts/actions to DB
    "distill_memory",      // Archive working memory
    "request_help"          // Signal human intervention needed
  ]
}
```

### 3.3 Task Delegation Workflow

```
1. HUMAN REQUEST
   ↓
2. Nestor analyzes request
   - Breaks down into tasks
   - Identifies dependencies
   ↓
3. Nestor checks agent status (sessions_list)
   - Who's available?
   - Current workload?
   ↓
4. Nestor assigns tasks (via sessions_send)
   - Sophie-FE: Frontend work
   - Elena-DBA: Database/backend work
   - Igor-coder: General coding
   - David-QA: Testing
   - Marco-reviewer: Code review
   ↓
5. Agents work independently
   - Use native tools
   - Log progress via log_event
   - Communicate via sessions_send
   ↓
6. Nestor monitors progress
   - Check task_events table
   - Watch for blockers
   - Coordinate handoffs
   ↓
7. Completion
   - Agent moves task to Done
   - David-QA validates
   - Marco-reviewer approves
   - Nestor reports to human
```

### 3.4 Agent Communication Rules (UPDATED in v3.5)

**Specialist Agents Now Have Proper Identity Files (NEW in v3.5):**

| Agent | IDENTITY.md | SOUL.md | Mission Control Context |
|-------|--------------|----------|----------------------|
| Sophie-FE | ✅ Created | ✅ Created | Frontend/UI Specialist for Mission Control |
| Elena-DBA | ✅ Created | ✅ Created | Database/Backend Specialist for Mission Control |
| David-QA | ✅ Created | ✅ Created | Testing + Cross-validation Specialist for Mission Control |
| Igor-coder | ✅ Created | ✅ Created | General Coding + TDD Specialist for Mission Control |
| Marco-reviewer | ✅ Created | ✅ Created | Code Reviewer + Quality Gates for Mission Control |

**✅ Allowed (Direct via `sessions_send`):**
- Technical collaboration: "@Elena, need /api/tasks endpoint"
- Context sharing: "@Sophie, backend API is ready"
- Status updates: "@Igor, I found a bug in the auth module"

**❌ Requires Nestor:**
- **Task creation** - All tasks must be created via Nestor
- **Strategic decisions** - Major decisions go through Nestor
- **Escalation** - Unresolved conflicts escalate to Nestor

**Logging:**
- All `sessions_send` calls are logged to `task_events` table
- Nestor monitors all agent communication
- Full observability maintained

### 3.5 Conflict Resolution

**Types of conflicts:**

1. **Task Ownership Conflict**
   - Two agents claim same task
   - Nestor decides based on:
     - First claim (timestamp)
     - Agent capability match
     - Current workload

2. **Approach Disagreement**
   - Agents disagree on implementation
   - Nestor evaluates:
     - Technical merit
     - Maintainability
     - Project goals
   - Escalates to human if unresolved

3. **Resource Contention**
   - Multiple agents need same specialist (e.g., Elena-DBA)
   - Nestor prioritizes:
     - Critical path tasks first
     - Dependencies resolved
     - Workload balance

### 3.6 Daily Standup

**Format:**
```markdown
## Daily Standup - 2026-02-02

### ✅ Completed Today
- Sophie-FE: Kanban board UI (task_mc_001)
- Elena-DBA: Database schema (task_mc_002)
- Igor-coder: Gateway service registration (task_mc_003)

### 🔄 In Progress
- Elena-DBA: RPC method implementation (task_mc_004) - ETA: 2h

### 🚫 Blocked
- Sophie-FE (task_mc_005): Needs TypeScript types from Elena
  - Escalation: Nestor to coordinate

### 🎯 Key Decisions
- Use SQLite for primary persistence (Nestor decision)
- Staggered pulse scheduling to avoid thundering herd (Elena-DBA proposal)

### 📊 Metrics
- Tasks completed: 3
- Tasks in progress: 1
- Tasks blocked: 1
- Agent uptime: 95%
```

**Delivery:**
- Via `message` tool to configured channel (Telegram)
- Also logged to `CHRONICLE.md`

---

## 4. MC_Service: Technical Infrastructure

### 4.1 Gateway Service Registration

MC_Service is a **Gateway service** (not an agent) that:

1. Handles JSON-RPC 2.0 requests from UI and agents
2. Manages SQLite database operations
3. Broadcasts real-time updates via WebSocket
4. Mirrors database state to markdown files

**Registration:**
```typescript
await Gateway.registerService({
  serviceName: 'mission-control',
  version: '3.5.0',
  methods: {
    // Project management
    'mission.project.list': handlerProjectList,
    'mission.project.get': handlerProjectGet,
    'mission.project.create': handlerProjectCreate,
    'mission.project.delete': handlerProjectDelete,

    // Task management
    'mission.task.list': handlerTaskList,
    'mission.task.get': handlerTaskGet,
    'mission.task.create': handlerTaskCreate,
    'mission.task.update': handlerTaskUpdate,
    'mission.task.move': handlerTaskMove,

    // Agent status
    'mission.agent.status': handlerAgentStatus,
    'mission.agent.list': handlerAgentList,

    // Task events (thought stream)
    'mission.event.list': handlerEventList,

    // Chronicle
    'mission.chronicle.get': handlerChronicleGet,
    'mission.chronicle.append': handlerChronicleAppend,

    // Agent tools (called by agents via RPC)
    'mission.control.log_event': handlerLogEvent,
    'mission.control.distill_memory': handlerDistillMemory,
    'mission.control.request_help': handlerRequestHelp
  },
  onStartup: async () => {
    await initializeDatabase();
    await startWebSocketBroadcast();
  },
  onShutdown: async () => {
    await closeDatabase();
    await stopWebSocketBroadcast();
  }
});
```

### 4.2 Database Schema

```sql
-- Projects table
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    status TEXT DEFAULT 'active', -- active, archived
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_projects_status ON projects(status);

-- Tasks table (Kanban state)
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    assignee_id TEXT NOT NULL, -- agent ID (e.g., "frontend-agent")
    status INTEGER CHECK(status BETWEEN 0 AND 4), -- 0:Backlog, 1:In-Progress, 2:Done, 3:Blocked, 4:Archive
    priority INTEGER DEFAULT 3, -- 1:High, 2:Medium, 3:Low
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME
);

CREATE INDEX idx_tasks_project_status ON tasks(project_id, status);
CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);
CREATE INDEX idx_tasks_updated ON tasks(updated_at DESC);

-- Task events table (Thought Stream)
CREATE TABLE task_events (
    id TEXT PRIMARY KEY,
    task_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    agent_id TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    thought TEXT NOT NULL,
    action TEXT NOT NULL,
    event_type TEXT DEFAULT 'info' -- info, warning, error, decision
);

CREATE INDEX idx_task_events_task_timestamp ON task_events(task_id, timestamp DESC);
CREATE INDEX idx_task_events_agent ON task_events(agent_id);

-- Chronicle entries
CREATE TABLE chronicle (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
    date TEXT NOT NULL, -- YYYY-MM-DD
    summary TEXT NOT NULL,
    content TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chronicle_project_date ON chronicle(project_id, date DESC);
```

### 4.3 WebSocket Real-Time Updates

**Event Types:**

```typescript
type MissionEvent =
  | { type: 'TASK_CREATED'; data: Task }
  | { type: 'TASK_UPDATED'; data: Task }
  | { type: 'TASK_MOVED'; data: { task_id: string; old_status: number; new_status: number } }
  | { type: 'TASK_DELETED'; data: { task_id: string } }
  | { type: 'EVENT_LOGGED'; data: TaskEvent }
  | { type: 'AGENT_STATUS_CHANGED'; data: AgentStatus }
  | { type: 'CHRONICLE_UPDATED'; data: { project_id: string } };
```

**Broadcast Mechanism:**

MC_Service broadcasts events to all connected WebSocket clients when:
- Task is created/updated/moved/deleted
- Agent logs an event via `log_event`
- Agent status changes

### 4.4 State Mirroring to Markdown

**Single-Writer Rule:**
- **ONLY MC_Service** writes to `KANBAN.md` and `CHRONICLE.md`
- Agents must use RPC methods (NEVER write directly via file tools)

---

## 5. Filesystem Map (Standardization - UPDATED in v3.5)

```text
~/.openclaw/
├── mission-control.db        # SQLite database (MC_Service writes)
├── openclaw.json             # Global agent manifest
├── agents/                   # NATIVE OPENCLAW AGENTS
│   ├── main/                 # Nestor (orchestrator)
│   │   ├── IDENTITY.md    # Who is Nestor
│   │   ├── SOUL.md        # Personality, role, Mission Control context
│   │   ├── SYSTEM.md       # Tech stack, coordination (already exists)
│   │   └── sessions/       # Session history (OpenClaw native)
│   ├── frontend-agent/        # Sophie-FE
│   │   ├── IDENTITY.md    # Who is Sophie (NEW in v3.5)
│   │   ├── SOUL.md        # Personality, role, Mission Control context (NEW in v3.5)
│   │   └── sessions/       # Session history
│   ├── db-agent/             # Elena-DBA
│   │   ├── IDENTITY.md    # Who is Elena (NEW in v3.5)
│   │   ├── SOUL.md        # Personality, role, Mission Control context (NEW in v3.5)
│   │   └── sessions/       # Session history
│   ├── test-agent/           # David-QA
│   │   ├── IDENTITY.md    # Who is David (NEW in v3.5)
│   │   ├── SOUL.md        # Personality, role, Mission Control context (NEW in v3.5)
│   │   └── sessions/       # Session history
│   ├── coding-agent/         # Igor-coder
│   │   ├── IDENTITY.md    # Who is Igor (NEW in v3.5)
│   │   ├── SOUL.md        # Personality, role, Mission Control context (NEW in v3.5)
│   │   └── sessions/       # Session history
│   └── review-agent/         # Marco-reviewer
│       ├── IDENTITY.md    # Who is Marco (NEW in v3.5)
│       ├── SOUL.md        # Personality, role, Mission Control context (NEW in v3.5)
│       └── sessions/       # Session history
├── projects/                 # ISOLATED PROJECT SCOPES
│   └── {project_id}/
│       ├── KANBAN.md         # Mirrored state (MC_Service only)
│       ├── CHRONICLE.md      # Project knowledge (MC_Service only)
│       ├── .context/         # L2: Fixed project rules
│       ├── daily/            # L3: Human chronology logs
│       └── src/              # Source code
├── logs/                    # Mission Control logs
│   └── mission-control.log
```

---

## 6. Nestor's SOUL.md (UPDATED in v3.5)

See `/root/.openclaw/SOUL.md` for Nestor's complete orchestration configuration.

---

## 7. Agent Tools (Mission Control Specific)

### 7.1 `log_event`

**Purpose:** Log internal reasoning and intended action to Mission Control database.

**Usage:**
```typescript
{
  "jsonrpc": "2.0",
  "method": "mission.control.log_event",
  "params": {
    "task_id": "task_001",
    "thought": "The user requested a login page. I am checking if we have existing auth middleware.",
    "action": "read src/middleware/auth.ts",
    "event_type": "info"
  },
  "id": 1
}
```

**Called by:** All agents (including Nestor)
**When:** Before taking any significant action
**Effect:** Writes to `task_events` table, broadcasts via WebSocket

### 7.2 `distill_memory`

**Purpose:** Archive working memory to learned memory when task is done.

**Usage:**
```typescript
{
  "jsonrpc": "2.0",
  "method": "mission.control.distill_memory",
  "params": {
    "task_id": "task_001",
    "agent_id": "frontend-agent",
    "summary": "Implemented Kanban board using React DnD. Decisions: Use native HTML5 drag API for performance.",
    "technical_debt": "Consider migrating to dnd-kit for better mobile support",
    "archive_working": true
  },
  "id": 2
}
```

**Called by:** Agents when completing tasks
**When:** After moving task to "Done"
**Effect:**
- Appends to `learned.md` in agent directory
- Updates `CHRONICLE.md` for project
- Optionally archives `working.md`

### 7.3 `request_help`

**Purpose:** Signal that human intervention is required.

**Usage:**
```typescript
{
  "jsonrpc": "2.0",
  "method": "mission.control.request_help",
  "params": {
    "task_id": "task_001",
    "agent_id": "frontend-agent",
    "issue": "Missing API endpoint for /api/tasks. Waiting for Elena-DBA to implement.",
    "urgency": "medium"
  },
  "id": 3
}
```

**Called by:** Agents when blocked
**When:** After trying to resolve independently (30-60 minutes)
**Effect:**
- Moves task to "Blocked" status
- Notifies Nestor via `sessions_send`
- Nestor notifies human via `message` tool

---

## 8. Frontend UI (Vite + React + Shadcn)

### 8.1 Project Structure

```
mission-control-ui/
├── src/
│   ├── components/
│   │   ├── KanbanBoard.tsx      # Main board with 5 columns
│   │   ├── TaskCard.tsx         # Individual task card
│   │   ├── ThoughtStream.tsx    # Live terminal feed
│   │   ├── AgentStatusGrid.tsx  # 5 agent status cards (updated for v3.5)
│   │   ├── ProjectSwitcher.tsx  # Dropdown to switch projects
│   │   ├── DocumentsTab.tsx     # Project documentation viewer (v3.4.1 feature)
│   │   └── TabNavigation.tsx    # Switch between Kanban and Documents (v3.4.1 feature)
│   ├── hooks/
│   │   ├── useWebSocket.ts      # WebSocket connection
│   │   └── useMissionControl.ts # RPC calls
│   ├── types/
│   │   └── mission-control.ts  # TypeScript interfaces
│   ├── App.tsx
│   └── main.tsx
├── package.json
└── vite.config.ts
```

**Agent Status Grid (Updated for v3.5):**
- Shows 6 agents (Nestor + 5 specialists)
- Each agent now displays their identity from IDENTITY.md
- Visual indicator of current task and status

---

## 9. Heartbeat & Pulse System

### 9.1 Using OpenClaw Cron

**DO NOT reinvent pulse scheduling.** Use `openclaw cron`:

```typescript
// Create cron job for Nestor to check agent status
await cron.add({
  job: {
    name: 'nestor-daily-standup',
    schedule: {
      kind: 'cron',
      expr: '0 9 * * *', // 9:00 AM daily
      tz: 'Europe/Brussels'
    },
    payload: {
      kind: 'systemEvent',
      text: 'TRIGGER_DAILY_STANDUP'
    },
    sessionTarget: 'main',
    enabled: true
  }
});
```

---

## 10. Implementation Phases

See `phases.md` for detailed implementation plan.

**Key changes from v3.4.1:**

1. **Phase 0 (UPDATED):** Nestor Orchestrator Setup + Specialist Agent Identities
   - Create Nestor's SOUL.md (already exists)
   - **NEW:** Create IDENTITY.md files for all 5 specialists
   - **NEW:** Create SOUL.md files for all 5 specialists
   - Test `sessions_send` to all specialists
   - Test `sessions_list` for monitoring

2. **Phase 1-6:** Same as v3.4.1
   - Use OpenClaw native tools
   - Specialist agents now have proper identity files

3. **Phase 7 (UPDATED):** Integration Testing with Nestor + Specialists
   - Test complete workflow with all specialists
   - Verify agent-to-agent communication
   - Test that agents read their IDENTITY.md and SOUL.md files

4. **Phase 8:** Deployment & Monitoring

---

## 11. Key Changes from v3.4.1

| Change | v3.4.1 | v3.5 |
|--------|---------|--------|
| **Specialist Identities** | Missing | ✅ **COMPLETE** - IDENTITY.md + SOUL.md for all 5 specialists |
| **Agent Communication** | Documented | ✅ **ENHANCED** - Agents have proper identity files, know their Mission Control role |
| **Agent Status Grid** | Basic | ✅ **ENHANCED** - Shows 6 agents with identity from IDENTITY.md |
| **Orchestration Logic** | Basic | ✅ **ENHANCED** - Nestor coordinates specialists with proper context |
| **Phase 0** | Nestor only | ✅ **EXPANDED** - Includes specialist agent setup |

---

## 12. Testing Strategy

### 12.2 Integration Tests (UPDATED for v3.5)

```typescript
// Test that specialists read their identity files
describe('Specialist Agent Identities', () => {
  it('should read IDENTITY.md', async () => {
    const sophieIdentity = await rpcCall<string>('mission.agent.get_identity', {
      agent_id: 'frontend-agent'
    });
    expect(sophieIdentity).toContain('Frontend/UI Specialist');
  });

  it('should read SOUL.md', async () => {
    const sophieSoul = await rpcCall<string>('mission.agent.get_soul', {
      agent_id: 'frontend-agent'
    });
    expect(sophieSoul).toContain('Mission Control Dashboard');
  });
});
```

---

## 13. Deployment

### 13.1 Installation

```bash
# 1. Ensure OpenClaw is installed
npm install -g openclaw@latest

# 2. Verify specialist agents are configured
openclaw agents list
# Should show: main, frontend-agent, db-agent, test-agent, coding-agent, review-agent

# 3. Start Gateway
openclaw gateway start

# 4. Start UI (in separate terminal)
cd mission-control-ui
npm install
npm run dev
```

### 13.2 Configuration

```json
// ~/.openclaw/openclaw.json
{
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace/"
    },
    "list": [
      {
        "id": "main"
      },
      {
        "id": "frontend-agent",
        "name": "sophie-FE",
        "workspace": "~/.openclaw/workspace/",
        "agentDir": "~/.openclaw/agents/frontend-agent/",
        "model": "zai/glm-4.7"
      },
      {
        "id": "db-agent",
        "name": "elena-DBA",
        "workspace": "~/.openclaw/workspace/",
        "agentDir": "~/.openclaw/agents/db-agent/",
        "model": "zai/glm-4.7"
      },
      {
        "id": "test-agent",
        "name": "david-QA",
        "workspace": "~/.openclaw/workspace/",
        "agentDir": "~/.openclaw/agents/test-agent/",
        "model": "zai/glm-4.7"
      },
      {
        "id": "coding-agent",
        "name": "igor-coder",
        "workspace": "~/.openclaw/workspace/",
        "agentDir": "~/.openclaw/agents/coding-agent/",
        "model": "zai/glm-4.7"
      },
      {
        "id": "review-agent",
        "name": "marco-reviewer",
        "workspace": "~/.openclaw/workspace/",
        "agentDir": "~/.openclaw/agents/review-agent/",
        "model": "zai/glm-4.7"
      }
    ]
  }
}
```

---

## 14. Conclusion

Mission Control v3.5 provides a **complete, OpenClaw-native specification** with **specialist agent identities** properly configured.

**Key Principles:**
1. **Use OpenClaw tools** - Don't reinvent what already exists
2. **Nestor orchestrates** - AI agent coordinates, not just technical code
3. **Specialists have identity** - IDENTITY.md + SOUL.md for each specialist
4. **Agents collaborate** - Direct communication via `sessions_send`
5. **Full observability** - Everything tracked in database
6. **Human in control** - Nestor provides status, human makes decisions
7. **Agent coordination** - Specialists know their Mission Control role from SOUL.md

**Next Steps:**
1. Review `phases.md` for implementation plan
2. Proceed with Phase 0 (Nestor + Specialist Agent Setup)
3. Configure Nestor's SOUL.md (already exists)
4. Create IDENTITY.md and SOUL.md for all 5 specialists
5. Test agent communication
6. Proceed to Phase 1-8

**Status:** Implementation Ready
**Last Updated:** 2026-02-02

---

**Version History:**
- v3.1: Initial technical specification
- v3.3: Implementation-ready with complete technical infrastructure
- v3.4: Added Nestor Orchestrator, agent coordination, OpenClaw-native architecture
- v3.4.1: Added Documentation Tab, Project Filtering ("All Projects" mode), Document RPC handlers
- v3.5: Added Specialist Agent Identities (IDENTITY.md + SOUL.md for all 5 specialists)
