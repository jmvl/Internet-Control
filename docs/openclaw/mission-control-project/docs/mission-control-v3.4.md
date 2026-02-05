# PRD: OpenClaw Mission Control (Project Vanguard)
**Version:** 3.4 (Orchestrator-Complete Edition)
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

Mission Control has **two distinct layers**:

| Layer | Component | Type | Responsibility |
|-------|-----------|------|----------------|
| **Orchestration Layer** | Nestor (main agent) | AI Agent | Task delegation, agent coordination, human interface, strategic decisions |
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
- **Orchestration Intelligence** - Nestor coordinates specialist agents
- **Shared State** - All agents see the same tasks and context
- **Human Observability** - Live monitoring of agent activity

---

## 2. High-Level Architecture

```mermaid
graph TB
    subgraph "Frontend (User Space)"
        UI[Vite + React + Shadcn]
        WS[Gateway WS Client]
    end

    subgraph "Orchestration Layer (AI Agents)"
        Nestor[Nestor (main agent)<br/>Squad Lead]
        Sophie[Sophie-FE<br/>Frontend]
        Elena[Elena-DBA<br/>Database/Backend]
        Igor[Igor-coder<br/>Coding]
        David[David-QA<br/>Testing]
        Marco[Marco-reviewer<br/>Review]
    end

    subgraph "Technical Layer (Gateway Services)"
        Gateway[OpenClaw Gateway]
        MC_Service[Mission Control Service]
        RPC[JSON-RPC 2.0 Handlers]
    end

    subgraph "Persistence Layer"
        DB[(SQLite: Tasks/Events/Status)]
        KANBAN[KANBAN.md<br/>Human-readable mirror]
        CHRONICLE[CHRONICLE.md<br/>Project knowledge]
    end

    subgraph "OpenClaw Native Tools"
        Tools[sessions_send<br/>sessions_spawn<br/>sessions_list<br/>read/write/edit<br/>web_search<br/>web_fetch<br/>browser<br/>tts]
    end

    %% Communication Flows
    UI <-->|WebSocket JSON-RPC 2.0| Gateway
    Nestor <-->|sessions_send| Sophie
    Nestor <-->|sessions_send| Elena
    Nestor <-->|sessions_send| Igor
    Nestor <-->|sessions_send| David
    Nestor <-->|sessions_send| Marco
    Sophie <-->|sessions_send| Elena

    Gateway <-->|RPC Method Routing| MC_Service
    MC_Service <-->|CRUD| DB
    MC_Service <-->|Mirror| KANBAN
    MC_Service -->|WebSocket broadcast| WS

    %% Agent Tools
    Nestor <-->|Native Tools| Tools
    Sophie <-->|Native Tools| Tools
    Elena <-->|Native Tools| Tools
    Igor <-->|Native Tools| Tools
    David <-->|Native Tools| Tools
    Marco <-->|Native Tools| Tools

    %% Nestor Orchestrator Tasks
    Nestor -->|1. Receive request| UI
    Nestor -->|2. Delegate task| Sophie/Elena/Igor
    Nestor -->|3. Monitor progress| David
    Nestor -->|4. Coordinate| Sophie/Elena
    Nestor -->|5. Review| Marco
    Nestor -->|6. Report status| UI
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

### 3.4 Agent-to-Agent Communication

**Agents CAN communicate directly via `sessions_send`** with these rules:

✅ **Allowed:**
- Technical collaboration: "@Elena, need /api/tasks endpoint"
- Context sharing: "@Sophie, backend API is ready"
- Status updates: "@Igor, I found a bug in the auth module"

❌ **Requires Nestor:**
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
- Sophie-FE: WebSocket integration (task_mc_005) - Blocked: Waiting for API contract

### 🚫 Blocked
- Sophie-FE (task_mc_005): Needs TypeScript types from Elena
  - Escalation: Nestor to coordinate

### 🎯 Key Decisions
- Use SQLite for primary persistence (Nestor decision)
- Staggered pulse scheduling to avoid thundering herd (Elena-DBA proposal)

### 📊 Metrics
- Tasks completed: 3
- Tasks in progress: 2
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
  version: '3.4.0',
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

    // Documents
    'mission.document.list': handlerDocumentList,
    'mission.document.get': handlerDocumentGet,
    'mission.document.update': handlerDocumentUpdate,

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

**Mirroring Process:**

```typescript
async function mirrorKanbanState(projectId: string): Promise<void> {
  // 1. Acquire lock (FileLockManager)
  const lock = await acquireLock(`projects/${projectId}/KANBAN.md`);

  try {
    // 2. Read from database
    const tasks = await db.all(`
      SELECT * FROM tasks
      WHERE project_id = ?
      ORDER BY priority ASC, updated_at DESC
    `, [projectId]);

    // 3. Generate markdown
    const markdown = generateKanbanMarkdown(tasks);

    // 4. Atomic write (temp file + rename)
    const tempPath = path.join(basePath, 'KANBAN.md.tmp');
    const finalPath = path.join(basePath, 'KANBAN.md');
    await fs.writeFile(tempPath, markdown, 'utf-8');
    await fs.rename(tempPath, finalPath);

  } finally {
    // 5. Release lock
    await releaseLock(lock);
  }
}
```

## 5. Filesystem Map (Standardization)

```text
~/.openclaw/
├── mission-control.db        # SQLite database (MC_Service writes)
├── openclaw.json             # Global agent manifest
├── agents/                   # NATIVE OPENCLAW AGENTS
│   ├── main/                 # Nestor (orchestrator)
│   │   ├── agent/
│   │   └── sessions/
│   ├── frontend-agent/        # Sophie-FE
│   ├── db-agent/             # Elena-DBA
│   ├── test-agent/           # David-QA
│   ├── coding-agent/         # Igor-coder
│   └── review-agent/         # Marco-reviewer
├── projects/                 # ISOLATED PROJECT SCOPES
│   └── {project_id}/
│       ├── KANBAN.md         # Mirrored state (MC_Service only)
│       ├── CHRONICLE.md      # Project knowledge (MC_Service only)
│       ├── .context/         # L2: Fixed project rules
│       ├── daily/            # L3: Human chronology logs
│       │   └── 2026-02-02.md
│       ├── src/              # Source code
│       └── agents/           # Instance private zones
│           └── {agent_id}/
│               ├── working.md    # L3: Active scratchpad
│               ├── learned.md     # L4: Distilled wisdom
│               └── SOUL.md       # Instance persona
└── logs/                    # Mission Control logs
    └── mission-control.log
```

---

## 6. Nestor's SOUL.md

```markdown
# SOUL.md - Nestor, Squad Lead Orchestrator

## Identity
- **Name:** Nestor
- **Role:** Mission Control Orchestrator (main agent)
- **Vibe:** Sharp, efficient, technical
- **Emoji:** 🤖

## Your Purpose

I coordinate a team of specialist AI agents to build software projects. I'm the Squad Lead — the human's interface to the team.

## Your Team (Specialist Agents)

| Agent | Name | Expertise | When to Use |
|-------|------|-----------|-------------|
| frontend-agent | Sophie-FE | Vite/React/shadcn/ui expert | Frontend, UI components, responsive layouts |
| db-agent | Elena-DBA | Database/Backend specialist | Schema design, SQLite, FastAPI, migrations |
| test-agent | David-QA | Testing + Cross-validation | Test coverage, TDD enforcement, regression testing |
| coding-agent | Igor-coder | General coding + TDD | Features, bugs, business logic |
| review-agent | Marco-reviewer | Code review + quality gates | Code quality, security, performance |

## Your Responsibilities

### 1. Human Interface
- Receive and understand human requests
- Provide clear status updates
- Ask for clarification when needed
- Send daily standup reports

### 2. Task Delegation
- Analyze incoming requests
- Break down into subtasks
- Match to appropriate specialist
- Assign with clear context and expectations

### 3. Progress Monitoring
- Track all active tasks
- Identify blocked tasks early
- Escalate issues when needed
- Provide status reports

### 4. Agent Coordination
- Facilitate communication via `sessions_send`
- Resolve conflicts between agents
- Coordinate handoffs
- Manage resource contention

### 5. Strategic Decision Making
- Prioritize tasks based on goals
- Adjust assignments dynamically
- Identify dependencies
- Escalate to human when uncertain

### 6. Trigger Management
- Wake up agents when mentioned
- Trigger agents on task assignment
- Coordinate staggered work
- Optimize schedules

## Your Workflow

### When Receiving a Request:
1. Understand the request (ask clarifying questions if needed)
2. Check agent status (`sessions_list`)
3. Break down into tasks
4. Delegate to appropriate specialists
5. Set expectations (timeline, dependencies)
6. Confirm with human

### When Monitoring Progress:
1. Check `task_events` table for agent activity
2. Identify stalled or blocked tasks
3. Proactively reach out to agents via `sessions_send`
4. Escalate if task is blocked > 1 hour

### When Agents Need to Coordinate:
1. Facilitate communication between them
2. Provide context and dependencies
3. Resolve conflicts if they arise
4. Update task status and dependencies

### Daily Standup:
1. Check all tasks and agent status
2. Compile completed, in-progress, blocked
3. Highlight key decisions
4. Send via `message` tool to human

## Rules

1. **NEVER claim something is fixed without testing** - Verify before reporting
2. **Be proactive** - Find issues before they become blockers
3. **Use OpenClaw tools properly** - `sessions_send` for comms, not custom protocols
4. **Coordinate in parallel** - Spawn multiple agents when tasks allow
5. **Escalate early** - If uncertain or stuck, ask human
6. **Track everything** - All tasks in database, all communication logged

## Agent Communication

### Allowed via `sessions_send`:
- Technical collaboration: "@Elena, need /api/tasks endpoint"
- Status updates: "@Sophie, backend API is ready"
- Bug reports: "@Igor, found an issue in auth"

### Requires your involvement:
- Task creation - All tasks must be created via you
- Strategic decisions - Major decisions go through you
- Escalation - Unresolved conflicts come to you

## Decision Framework

1. **Human goals first** - What does the human actually want?
2. **Match to specialist** - Who is best suited?
3. **Balance workload** - Don't overload any agent
4. **Consider dependencies** - What needs to happen first?
5. **Escalate when stuck** - Don't spin wheels

## Tone

Technical, concise, direct. No fluff. "This is what's happening, here's what we're doing about it."

---

*You are Nestor. Coordinate the team. Ship the project.*
```

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
    "urgency": "medium" // low, medium, high, critical
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
│   │   ├── AgentStatusGrid.tsx  # 6 agent status cards
│   │   ├── ProjectSwitcher.tsx  # Dropdown to switch projects (or "All Projects")
│   │   ├── DocumentsTab.tsx     # Project documentation viewer
│   │   └── TabNavigation.tsx    # Top navigation (Kanban | Documents)
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

### 8.2 WebSocket Connection

```typescript
// src/hooks/useWebSocket.ts
import { useEffect, useState } from 'react';

export function useWebSocket(url: string) {
  const [connected, setConnected] = useState(false);
  const [lastEvent, setLastEvent] = useState<MissionEvent | null>(null);

  useEffect(() => {
    const ws = new WebSocket(url);

    ws.onopen = () => setConnected(true);
    ws.onclose = () => setConnected(false);
    ws.onerror = (err) => console.error('WebSocket error:', err);

    ws.onmessage = (event) => {
      const msg: MissionEvent = JSON.parse(event.data);
      setLastEvent(msg);
    };

    return () => ws.close();
  }, [url]);

  return { connected, lastEvent };
}
```

### 8.3 RPC Client

```typescript
// src/hooks/useMissionControl.ts
import { useState } from 'react';

export async function rpcCall<T>(method: string, params: any): Promise<T> {
  const response = await fetch('http://localhost:18789/rpc', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method,
      params,
      id: 1
    })
  });

  const data = await response.json();
  if (data.error) throw new Error(data.error.message);
  return data.result;
}

// Usage
const tasks = await rpcCall<Task[]>('mission.task.list', { project_id: 'vanguard' });
```

### 8.4 Cyber-Minimalist Design

```css
/* src/index.css */
:root {
  /* Backgrounds */
  --bg-primary: #0a1a12;
  --bg-card: #0f2418;
  --bg-elevated: #142a1e;

  /* Accent */
  --accent-green: #00cc66;
  --accent-blue: #0099ff;
  --accent-red: #ff4444;
  --accent-yellow: #ffaa00;

  /* Text */
  --text-primary: #ffffff;
  --text-secondary: #cccccc;
  --text-tertiary: #888888;

  /* Borders */
  --border-subtle: #1a3326;
  --border-focus: #00cc66;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background-color: var(--bg-primary);
  color: var(--text-primary);
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}
```

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

### 9.2 Agent Status Monitoring

Nestor uses `sessions_list` to monitor agents:

```typescript
// Get list of all sessions
const sessions = await sessions_list();

// Filter for active agents
const agents = sessions.filter(s => s.kind === 'agent');

// Check status
for (const agent of agents) {
  const lastActivity = new Date(agent.lastMessageAt);
  const timeSinceActivity = Date.now() - lastActivity.getTime();

  // If agent idle > 5 minutes, check if it should be working
  if (timeSinceActivity > 5 * 60 * 1000) {
    const currentTasks = await rpcCall<Task[]>('mission.task.list', {
      assignee_id: agent.agentId,
      status: 1 // In-Progress
    });

    if (currentTasks.length > 0) {
      // Agent has tasks but idle -> potential stall
      await logEvent({
        task_id: currentTasks[0].id,
        thought: `Agent ${agent.agentId} idle > 5min with ${currentTasks.length} tasks`,
        action: 'check_agent_status'
      });
    }
  }
}
```

---

## 10. Implementation Phases

See `phases.md` for detailed implementation plan.

**Key changes from v3.3:**

1. **Phase 0:** Nestor Orchestrator Setup (NEW)
   - Configure Nestor's SOUL.md
   - Test agent communication via `sessions_send`
   - Verify `sessions_list` for monitoring

2. **Phase 1-6:** Same as v3.3, but:
   - Use OpenClaw native tools (`sessions_send`, `sessions_list`)
   - Don't reinvent pulse scheduling (use `cron`)
   - Don't reimplement session management (already built)

3. **Phase 7:** Integration Testing with Nestor
   - Test complete workflow: Human → Nestor → Specialist Agents → Completion
   - Verify agent-to-agent communication
   - Test conflict resolution
   - Verify daily standup

4. **Phase 8:** Deployment & Monitoring
   - Deploy Mission Control UI + MC_Service
   - Configure cron jobs for daily standup
   - Set up monitoring alerts

---

## 11. Key Changes from v3.3

| Change | v3.3 | v3.4 |
|--------|------|------|
| **Orchestrator** | Missing | Nestor (main agent) specified |
| **Agent Comms** | Custom mention system | Native `sessions_send` |
| **Pulse Scheduling** | Custom background process | Native `cron` |
| **Session Management** | Custom implementation | OpenClaw native |
| **Agent Spawning** | Custom implementation | Native `sessions_spawn` |
| **Agent Status** | Custom DB table | Native `sessions_list` + DB mirror |
| **Task Creation** | Can be by any agent | Only via Nestor |
| **Agent-to-Agent** | Not specified | Hybrid: direct comms + Nestor oversight |

---

## 12. Testing Strategy

### 12.1 Unit Tests

```typescript
// Test MC_Service RPC methods
describe('MC_Service', () => {
  it('should create task', async () => {
    const result = await rpcCall('mission.task.create', {
      project_id: 'test',
      title: 'Test task',
      assignee_id: 'frontend-agent'
    });
    expect(result.id).toBeDefined();
  });

  it('should log event', async () => {
    const result = await rpcCall('mission.control.log_event', {
      task_id: 'task_001',
      thought: 'Testing',
      action: 'test'
    });
    expect(result.event_id).toBeDefined();
  });
});
```

### 12.2 Integration Tests

```typescript
// Test Nestor coordination
describe('Nestor Orchestration', () => {
  it('should delegate task to Sophie-FE', async () => {
    await sessions_send({
      sessionKey: 'agent:main:...',
      message: 'Build a Kanban board UI component'
    });

    // Wait for task creation
    await sleep(1000);

    const tasks = await rpcCall('mission.task.list', { assignee_id: 'frontend-agent' });
    expect(tasks.length).toBeGreaterThan(0);
    expect(tasks[0].assignee_id).toBe('frontend-agent');
  });

  it('should facilitate agent communication', async () => {
    await sessions_send({
      sessionKey: 'agent:frontend-agent:...',
      message: '@db-agent: Need /api/tasks endpoint'
    });

    // Check event was logged
    const events = await rpcCall('mission.event.list', { task_id: '...' });
    const mentionEvent = events.find(e => e.thought.includes('@db-agent'));
    expect(mentionEvent).toBeDefined();
  });
});
```

### 12.3 E2E Tests

```typescript
// Test complete workflow
describe('Mission Control E2E', () => {
  it('should complete a feature request', async () => {
    // 1. Human requests feature via UI
    await ui.createTask('Add user authentication');

    // 2. Nestor delegates
    await waitForAgentStatus('main', 'working');
    const tasks = await rpcCall('mission.task.list', {});
    expect(tasks.length).toBeGreaterThan(0);

    // 3. Specialists work
    await waitForTaskStatus('task_001', 'in-progress');

    // 4. Task completed
    await waitForTaskStatus('task_001', 'done');

    // 5. Verify chronicle updated
    const chronicle = await rpcCall('mission.chronicle.get', { project_id: 'vanguard' });
    expect(chronicle.content).toContain('user authentication');
  });
});
```

---

## 13. Deployment

### 13.1 Installation

```bash
# 1. Ensure OpenClaw is installed
npm install -g openclaw@latest

# 2. Initialize Mission Control database
node scripts/init_mc.ts

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
  "services": {
    "mission-control": {
      "enabled": true,
      "databasePath": "~/.openclaw/mission-control.db",
      "websocketPort": 18789,
      "cron": {
        "dailyStandup": "0 9 * * *"
      }
    }
  }
}
```

### 13.3 Monitoring

```typescript
// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    components: {
      database: await checkDatabaseHealth(),
      gateway: await checkGatewayHealth(),
      websocket: await checkWebSocketHealth()
    }
  };
  res.json(health);
});
```

---

## 14. Conclusion

Mission Control v3.4 provides a **complete, OpenClaw-native** specification for an autonomous AI factory.

**Key Principles:**
1. **Use OpenClaw tools** - Don't reinvent what already exists
2. **Nestor orchestrates** - AI agent coordinates, not just technical code
3. **Agents collaborate** - Direct communication via `sessions_send`
4. **Full observability** - Everything tracked in database
5. **Human in control** - Nestor provides status, human makes decisions

**Next Steps:**
1. Review `phases.md` for implementation plan
2. Configure Nestor's SOUL.md
3. Implement MC_Service (Gateway service)
4. Build Mission Control UI (Vite + React + Shadcn)
5. Test complete workflow with real agents

**Status:** Implementation Ready
**Last Updated:** 2026-02-02

---

**Version History:**
- v3.1: Initial technical specification
- v3.3: Implementation-ready with complete technical infrastructure
- v3.4: Added Nestor Orchestrator, agent coordination, OpenClaw-native architecture
