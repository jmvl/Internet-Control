# OpenClaw Mission Control Implementation Strategy

**v3.4 — Nestor Orchestrator + OpenClaw-Native Architecture**

## Implementation Principles

1. **Use OpenClaw Native Tools** - Don't reinvent sessions_send, sessions_list, cron, etc.
2. **Nestor Orchestrates** - Main agent coordinates, not just technical infrastructure
3. **TDD First:** David-QA tests after EACH phase before proceeding
4. **Parallel Execution:** Backend (Phase 3) + Frontend (Phase 5) run simultaneously once API contract is defined
5. **Agent Ownership:** Each phase has a single clear owner
6. **Quality Gates:** Marco-reviewer reviews after each phase
7. **Incremental Delivery:** Working system after each phase

---

## Phase 0: Nestor Orchestrator Setup (NEW)

**Owner:** Nestor (main agent)
**Duration:** ~2 hours

**Tasks:**
- [ ] Create Nestor's SOUL.md with orchestration instructions (see v3.4 Section 6)
- [ ] Test `sessions_send` communication to specialist agents:
  ```typescript
  await sessions_send({
    sessionKey: 'agent:frontend-agent:...',
    message: 'Test message from Nestor'
  });
  ```
- [ ] Test `sessions_list` to monitor agent status:
  ```typescript
  const sessions = await sessions_list();
  const agents = sessions.filter(s => s.kind === 'agent');
  ```
- [ ] Test agent-to-agent communication:
  ```typescript
  // Sophie-FE @mentions Elena-DBA
  await sessions_send({
    sessionKey: 'agent:frontend-agent:...',
    message: '@db-agent: Need /api/tasks endpoint'
  });
  ```
- [ ] Configure daily standup cron job:
  ```typescript
  await cron.add({
    job: {
      name: 'nestor-daily-standup',
      schedule: { kind: 'cron', expr: '0 9 * * *' },
      payload: { kind: 'systemEvent', text: 'TRIGGER_DAILY_STANDUP' },
      sessionTarget: 'main'
    }
  });
  ```
- [ ] Verify all specialist agents are configured and accessible

**Output:**
- Nestor's SOUL.md configured with orchestration logic
- Verified `sessions_send` communication to all 5 specialists
- Verified `sessions_list` for agent monitoring
- Working daily standup trigger
- Test of agent-to-agent communication

**Tested by:** David-QA (agent communication, Nestor orchestration)
**Reviewed by:** Marco-reviewer (orchestration logic, communication patterns)

---

## Phase 1: Environment Verification

**Owner:** Nestor (coordinator)
**Duration:** ~30 minutes

**Tasks:**
- [ ] Verify OpenClaw version (`openclaw --version`)
- [ ] Check Gateway status (`openclaw gateway status`)
- [ ] Verify dependencies:
  - Node.js 18+ (`node --version`)
  - SQLite3 available
  - better-sqlite3 package (if using)
- [ ] Examine current directory structure:
  - `~/.openclaw/workspace/` exists
  - `~/.openclaw/agents/` exists
  - `~/.openclaw/openclaw.json` is valid
- [ ] Test network accessibility:
  - Gateway reachable at `ws://localhost:18789`
  - LAN access at `ws://192.168.1.151:18789`

**Output:** Environment verification report, dependency checklist, network status

**Tested by:** David-QA (environment smoke tests)
**Reviewed by:** Marco-reviewer (verification thoroughness)

---

## Phase 2: Database Schema & File System Setup

**Owner:** Elena-DBA (database specialist)
**Duration:** ~2 hours
**Dependencies:** None (can start after Phase 1)

**Tasks:**
- [ ] Create SQLite database `~/.openclaw/mission-control.db` with schema:
  ```sql
  -- Projects table
  CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  -- Tasks table (Kanban state)
  CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    assignee_id TEXT NOT NULL,
    status INTEGER CHECK(status BETWEEN 0 AND 4),
    priority INTEGER DEFAULT 3,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE INDEX idx_tasks_project_status ON tasks(project_id, status);
  CREATE INDEX idx_tasks_assignee ON tasks(assignee_id);

  -- Agent status table (mirror of OpenClaw native sessions)
  -- NOTE: Primary source of truth is OpenClaw's sessions_list()
  -- This table is a cache for faster queries and persistence
  CREATE TABLE agent_status (
    instance_id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    last_pulse DATETIME,
    current_task_id TEXT REFERENCES tasks(id),
    status TEXT DEFAULT 'idle', -- idle, working, blocked, distilling
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE INDEX idx_agent_status_instance ON agent_status(instance_id);
  CREATE INDEX idx_agent_status_status ON agent_status(status);

  -- Task events table (Thought Stream)
  CREATE TABLE task_events (
    id TEXT PRIMARY KEY,
    task_id TEXT REFERENCES tasks(id),
    agent_id TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    thought TEXT NOT NULL,
    action TEXT NOT NULL
  );

  CREATE INDEX idx_task_events_task_timestamp ON task_events(task_id, timestamp);
  ```
- [ ] Create directory structure:
  ```
  ~/.openclaw/
  ├── projects/          # Isolated project workspaces
  ├── souls/             # Agent identity files (SOUL.md)
  ├── sessions/           # Agent session transcripts
  └── logs/              # Mission Control logs
  ```
- [ ] Implement file mutex for concurrency control:
  ```typescript
  class FileLockManager {
    acquire(path: string, timeout: number): Promise<Lock>
    release(lock: Lock): void
    isLocked(path: string): Promise<boolean>
  }
  ```
- [ ] Implement migration system:
  ```typescript
  interface Migration {
    version: string;
    description: string;
    up(db: Database): Promise<void>;
    down(db: Database): Promise<void>;
  }
  ```

**Output:** 
- Working `mission-control.db` with all tables and indexes
- Directory structure created
- FileLockManager implementation
- MigrationRunner implementation

**Tested by:** David-QA (database operations, migrations, file locking)
**Reviewed by:** Marco-reviewer (schema normalization, indexes, constraints)

---

## Phase 3: Backend Gateway Service + API Contract

**Owner:** Elena-DBA (backend specialist)
**Duration:** ~4 hours
**Dependencies:** Phase 2 (database schema)
**Parallel:** Can run with Phase 5 (Frontend) once API contract is defined

**Tasks:**

### 3.1 Gateway Service Registration
- [ ] Create `src/services/MissionControl.ts` with Gateway service interface:
  ```typescript
  interface GatewayServiceRegistration {
    serviceName: string;           // "mission-control"
    version: string;              // "3.3.0"
    methods: { [method: string]: Handler };
    onStartup(): Promise<void>;
    onShutdown(): Promise<void>;
  }
  ```
- [ ] Register service in `gateway/server.impl.ts`

### 3.2 RPC Methods (Mission Control)
- [ ] Implement `mission.project.init`:
  ```typescript
  { project_name: string, base_id?: string } => { project_id: string }
  ```
- [ ] Implement `mission.task.create`:
  ```typescript
  { project_id: string, title: string, assignee_id: string, priority: number } => { task_id: string }
  ```
- [ ] Implement `mission.task.move`:
  ```typescript
  { task_id: string, new_status: number } => void
  ```
- [ ] Implement `mission.agent.sync`:
  ```typescript
  { instance_id: string, current_task_id: string, status: string } => void
  ```
- [ ] Implement `mission.control.log_event`:
  ```typescript
  { task_id: string, thought: string, action: string } => { event_id: string }
  ```
- [ ] Implement `mission.control.update_chronicle`:
  ```typescript
  { project_id: string, summary: string, technical_debt?: string } => void
  ```
- [ ] Implement `mission.control.request_help`:
  ```typescript
  { task_id: string, issue: string } => void
  ```
- [ ] Implement `mission.control.distill_memory`:
  ```typescript
  { agent_id: string, summary: string, archive_working_notes: boolean } => void
  ```

### 3.3 Real-time Updates (WebSocket)
- [ ] Implement WebSocket server for real-time updates:
  ```typescript
  // Broadcast events to UI
  interface MissionEvent {
    type: 'TASK_UPDATED' | 'THOUGHT_LOGGED' | 'AGENT_SYNCED';
    data: any;
    timestamp: Date;
  }
  ```
- [ ] Implement event broadcasting for:
  - Task created/updated/moved
  - Agent logged thought
  - Agent status changed

### 3.4 API Contract (for Parallel Frontend)
- [ ] Define TypeScript types for frontend:
  ```typescript
  // Shared types file: src/types/mission-control.ts
  export interface Task {
    id: string;
    project_id: string;
    title: string;
    assignee_id: string;
    status: TaskStatus;
    priority: number;
    updated_at: Date;
  }

  export interface TaskEvent {
    id: string;
    task_id: string;
    agent_id: string;
    timestamp: Date;
    thought: string;
    action: string;
  }

  export interface AgentStatus {
    instance_id: string;
    pgid: number;
    last_pulse: Date;
    current_task_id: string | null;
    status: 'idle' | 'working' | 'distilling' | 'blocked';
  }

  export enum TaskStatus {
    Backlog = 0,
    InProgress = 1,
    Done = 2,
    Blocked = 3,
    Archive = 4
  }

  export interface WebSocketMessage {
    type: 'TASK_UPDATED' | 'THOUGHT_LOGGED' | 'AGENT_SYNCED';
    data: Task | TaskEvent | AgentStatus;
    timestamp: Date;
  }
  ```
- [ ] Export shared types to `src/types/mission-control.ts` for frontend import

**Output:**
- Working Mission Control Gateway service
- All RPC methods registered and tested
- WebSocket server for real-time updates
- Shared TypeScript types file (API contract)

**Tested by:** David-QA (RPC methods, WebSocket, API contract types)
**Reviewed by:** Marco-reviewer (API design, error handling, security, type safety)

---

## Phase 4: Orchestrator Logic

**Owner:** Nestor (orchestrator)
**Duration:** ~3 hours
**Dependencies:** Phase 3 (RPC methods, agent_status table)

**Tasks:**

### 4.1 Orchestrator Tick
- [ ] Implement `orchestratorTick()` function (runs every 30s):
  ```typescript
  async function orchestratorTick() {
    // 1. Scan tasks table
    const backlogTasks = await getTasksByStatus(0); // Backlog
    const inProgressTasks = await getTasksByStatus(1); // In-Progress

    // 2. Zombie check
    for (const task of inProgressTasks) {
      const agentStatus = await getAgentStatus(task.assignee_id);
      const timeSincePulse = Date.now() - agentStatus.last_pulse.getTime();

      // Stalled agent (> 5 minutes)
      if (timeSincePulse > 300000) {
        await killAgentProcess(agentStatus.pgid);
        await updateTaskStatus(task.id, 0); // Back to Backlog
      }
    }

    // 3. Schedule pulses for backlog tasks
    for (const task of backlogTasks) {
      await scheduleAgentPulse(task.assignee_id, task.project_id);
    }

    // 4. State mirroring
    await syncToMarkdown();
  }
  ```

### 4.2 Staggered Pulse Scheduling
- [ ] Implement stagger offset algorithm:
  ```typescript
  function calculateStaggerOffset(agentId: string, projectId: string): number {
    const hash = crypto.createHash('sha256')
      .update(agentId)
      .update(projectId)
      .digest('hex');
    const offset = parseInt(hash.substring(0, 8), 16);
    return offset;
  }
  ```

### 4.3 Agent Coordination
- [ ] Implement task delegation logic:
  ```typescript
  function delegateTask(task: Task, agents: Agent[]): Agent {
    // Match task requirements to agent capabilities
    // Consider agent workload
    // Select best match
  }
  ```
- [ ] Implement handoff coordination:
  ```typescript
  async function coordinateHandoff(
    fromAgent: string,
    toAgent: string,
    taskId: string
  ): Promise<void>
  ```
- [ ] Implement conflict resolution (if needed)

### 4.4 Deadman Switch
- [ ] Implement deadman logic (> 300s idle):
  ```typescript
  async function checkDeadmanSwitch() {
    const inProgressTasks = await getTasksByStatus(1);

    for (const task of inProgressTasks) {
      const agentStatus = await getAgentStatus(task.assignee_id);
      const timeSincePulse = Date.now() - agentStatus.last_pulse.getTime();

      if (timeSincePulse > 300000) { // 5 minutes
        await updateTaskStatus(task.id, 0); // Backlog
        await logEvent({
          task_id: task.id,
          thought: `Deadman switch: Agent ${task.assignee_id} idle > 300s`,
          action: 'move_task_to_backlog'
        });
      }
    }
  }
  ```

**Output:**
- Working orchestrator loop with 30s tick
- Staggered pulse scheduling
- Zombie detection and recovery
- Agent coordination logic
- Deadman switch implementation

**Tested by:** David-QA (orchestrator tick, pulse scheduling, zombie detection)
**Reviewed by:** Marco-reviewer (logic correctness, error handling, edge cases)

---

## Phase 5: Frontend UI (Vite + React + Shadcn)

**Owner:** Sophie-FE (frontend specialist)
**Duration:** ~4 hours
**Dependencies:** Phase 3 (API contract defined)
**Parallel:** Can run with Phase 3 (Backend) using shared types file

**Tasks:**

### 5.1 Project Setup
- [ ] Initialize Vite + React + TypeScript project
- [ ] Install Shadcn UI
- [ ] Install Tailwind CSS v4
- [ ] Configure design tokens (cyber-minimalist theme):
  ```css
  :root {
    --bg-primary: #0a1a12;
    --bg-card: #0f2418;
    --bg-elevated: #142a1e;
    --accent-green: #00cc66;
    --text-primary: #ffffff;
    --text-secondary: #cccccc;
    --text-tertiary: #888888;
    --border-subtle: #1a3326;
  }
  ```

### 5.2 Import Shared Types
- [ ] Import API contract from `src/types/mission-control.ts`:
  ```typescript
  import { Task, TaskEvent, AgentStatus, TaskStatus, WebSocketMessage } from '../../../types/mission-control';
  ```

### 5.3 Kanban Board
- [ ] Create `KanbanBoard` component with:
  - 5 columns: Backlog, In-Progress, Done, Blocked, Archive
  - Drag-and-drop task movement
  - Project switcher dropdown
  - Agent status cards
- [ ] Implement `TaskCard` component:
  - Task title, assignee, priority, status
  - Click to view thought stream
  - Drag handle

### 5.4 Thought Stream (Live Terminal)
- [ ] Create `ThoughtStream` component:
  - Real-time feed of task events
  - Filters by task_id
  - Terminal-style UI (cyber-minimalist)
  - Auto-scroll to latest

### 5.5 Agent Status Grid
- [ ] Create `AgentStatusGrid` component:
  - 6 cards (one per agent)
  - Current task, status, last pulse
  - Activity metrics (today/week)

### 5.6 WebSocket Connection
- [ ] Connect to Gateway WebSocket:
  ```typescript
  const ws = new WebSocket('ws://localhost:18789');
  ws.onmessage = (event) => {
    const msg: WebSocketMessage = JSON.parse(event.data);
    // Update state based on msg.type
  };
  ```
- [ ] Handle real-time updates:
  - `TASK_UPDATED` → Update task in state
  - `THOUGHT_LOGGED` → Add to thought stream
  - `AGENT_SYNCED` → Update agent status

### 5.7 Routing
- [ ] Implement routing:
  - `/` → Project list
  - `/:project_id` → Kanban board for that project
- [ ] Add Project Switcher component

### 5.8 Cyber-Minimalist Design
- [ ] Apply design system consistently
- [ ] High contrast (WCAG AA+)
- [ ] Responsive (mobile < 640px, tablet 640-1024px, desktop > 1024px)
- [ ] Smooth animations (60fps)

**Output:**
- Working Kanban board with drag-and-drop
- Thought stream with real-time updates
- Agent status grid
- WebSocket integration
- Cyber-minimalist design applied

**Tested by:** David-QA (component behavior, WebSocket, drag-and-drop, accessibility)
**Reviewed by:** Marco-reviewer (component design, accessibility, performance, code quality)

---

## Phase 6: Agent Tool Integration

**Owner:** Elena-DBA (backend) + Igor-coder (agent-side)
**Duration:** ~3 hours
**Dependencies:** Phase 3 (RPC methods), Phase 4 (orchestrator)

**Tasks:**

### 6.1 Backend Tool Implementation (Elena-DBA)
- [ ] Implement tool registration in `openclaw.json`:
  ```json
  {
    "tools": [
      {
        "name": "log_event",
        "description": "Log internal reasoning and intended tool action to Mission Control.",
        "parameters": {
          "type": "object",
          "properties": {
            "thought": { "type": "string" },
            "action": { "type": "string" }
          },
          "required": ["thought", "action"]
        }
      },
      {
        "name": "distill_memory",
        "description": "Move active task state to long-term project knowledge.",
        "parameters": {
          "type": "object",
          "properties": {
            "summary": { "type": "string" }
          },
          "required": ["summary"]
        }
      },
      {
        "name": "request_help",
        "description": "Signal that human intervention is required.",
        "parameters": {
          "type": "object",
          "properties": {
            "issue": { "type": "string" }
          },
          "required": ["issue"]
        }
      }
    ]
  }
  ```

### 6.2 Agent-Side Implementation (Igor-coder)
- [ ] Implement `sessions_send` for agent communication:
  ```typescript
  await sessions_send({
    sessionKey: `agent:${toAgentId}:${projectId}`,
    message: "Handoff: Frontend is ready for integration testing"
  });
  ```
- [ ] Implement memory distillation logic:
  - Read `working.md`
  - Extract key insights
  - Write to `learned.md`
  - Clear `working.md`
- [ ] Implement `update_chronicle` for project-level knowledge

### 6.3 4-Layer Memory Stack
- [ ] Configure memory structure for agents:
  ```
  ~/.openclaw/projects/{project_id}/
  ├── SOUL.md           # L1: Identity
  ├── .context/          # L2: Fixed project rules
  ├── daily/             # L3: Daily logs
  │   └── 2026-02-02.md
  └── agents/
      └── {agent_id}/
          ├── working.md    # L3: The active scratchpad
          └── learned.md     # L4: Distilled wisdom
  ```

### 6.4 Scoped File System
- [ ] Implement path security for file operations:
  ```typescript
  function enforceScope(path: string, scope: string): string {
    const basePath = path.resolve('~/.openclaw/projects', scope);
    const fullPath = path.resolve(basePath, path);

    if (!fullPath.startsWith(basePath)) {
      throw new Error('Path traversal attempt detected');
    }

    return fullPath;
  }
  ```

**Output:**
- Working agent tools (log_event, distill_memory, request_help)
- Agent communication via sessions_send
- 4-layer memory stack configured
- Scoped file system with path security

**Tested by:** David-QA (agent tools, memory distillation, path security)
**Reviewed by:** Marco-reviewer (tool design, error handling, security, type safety)

---

## Phase 7: Testing & Quality Assurance

**Owner:** David-QA (testing specialist)
**Duration:** ~4 hours
**Dependencies:** All previous phases

**Tasks:**

### 7.1 Unit Tests
- [ ] Test database operations (CRUD, migrations)
- [ ] Test RPC methods (all 8 methods)
- [ ] Test orchestrator logic (tick, pulse scheduling)
- [ ] Test agent tools (log_event, distill_memory, request_help)
- [ ] Test file locking and concurrency
- [ ] Test WebSocket event broadcasting

### 7.2 Integration Tests
- [ ] Test complete workflow:
  - Create project → Create tasks → Assign agents → Agents work → Update status → Move to done
- [ ] Test WebSocket real-time updates
- [ ] Test agent coordination (handoffs, conflicts)
- [ ] Test zombie detection and recovery
- [ ] Test deadman switch

### 7.3 End-to-End Tests
- [ ] Test multi-agent workflow:
  - Sophie-FE builds UI → Elena-DBA creates backend → Agents communicate → David-QA tests
- [ ] Test parallel execution (Backend + Frontend running simultaneously)
- [ ] Test agent spawning and lifecycle management
- [ ] Test scoped file system isolation

### 7.4 Cross-Validation
- [ ] Cross-validate all agent submissions:
  - Sophie-FE: Component structure, accessibility, responsive design
  - Elena-DBA: Schema design, API endpoints, error handling
  - Igor-coder: TDD compliance, code quality, test coverage
  - Nestor: Orchestrator logic, agent coordination
- [ ] Verify 80%+ test coverage
- [ ] Check for regressions

**Output:**
- Unit test suite (80%+ coverage)
- Integration test suite
- E2E test suite
- Cross-validation report
- Test coverage report

**Reviewed by:** Marco-reviewer (test quality, coverage, flaky test detection, regression prevention)

---

## Phase 8: Deployment

**Owner:** Nestor (coordinator)
**Duration:** ~2 hours
**Dependencies:** Phase 7 (all tests passing)

**Tasks:**

### 8.1 CI/CD Pipeline
- [ ] Set up GitHub Actions workflow:
  ```yaml
  name: Deploy Mission Control

  on:
    push:
      branches: [main]

  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - Checkout code
        - Setup Node.js 20
        - npm ci
        - npm test
        - npm run lint

    deploy:
      needs: test
      runs-on: ubuntu-latest
      steps:
        - Checkout code
        - npm run migrate
        - openclaw gateway restart
  ```

### 8.2 Deployment
- [ ] Deploy to production server
- [ ] Verify Gateway is running
- [ ] Verify WebSocket is accessible
- [ ] Test production deployment

### 8.3 Monitoring
- [ ] Set up health check endpoint (`/health`)
- [ ] Configure logging (`~/.openclaw/logs/mission-control.log`)
- [ ] Set up metrics collection (task completion rate, agent uptime)
- [ ] Configure alerts (failed heartbeats, database errors)

### 8.4 Documentation
- [ ] Update README with installation instructions
- [ ] Document API endpoints
- [ ] Document agent SOUL.md files
- [ ] Create deployment guide

**Output:**
- Working CI/CD pipeline
- Production deployment verified
- Monitoring and logging configured
- Complete documentation

**Reviewed by:** Marco-reviewer (deployment process, monitoring setup, documentation completeness)

---

## Parallel Execution Matrix

| Phase | Can Run In Parallel With | Condition |
|--------|------------------------|-----------|
| 1 | - | None (environment) |
| 2 | - | None (database is dependency) |
| 3 | 5 | **API contract defined in Phase 3** |
| 4 | - | Phase 3 (needs RPC methods) |
| 5 | 3 | **API contract defined in Phase 3** |
| 6 | - | Phases 3, 4 (needs RPC + orchestrator) |
| 7 | - | All phases (need complete system) |
| 8 | - | Phase 7 (all tests passing) |

**Key Parallel Opportunity:** Phase 3 (Backend) and Phase 5 (Frontend) can run simultaneously once the API contract is defined at the start of Phase 3.

---

## Quality Gates

After EACH phase (except Phase 1):
1. **David-QA Tests:** Verify functionality, run test suite, check coverage (80%+)
2. **Marco-Reviewer Reviews:** Code quality, security, performance, type safety, accessibility
3. **Nestor Approves:** Move to next phase

---

## Summary

**Total Estimated Duration:** ~22-26 hours (spread across agents)

**Critical Path:**
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 6 → Phase 7 → Phase 8

**Parallel Opportunities:**
- Phase 3 (Backend) + Phase 5 (Frontend) = **4 hours instead of 8 hours**

**Agent Allocation:**
- Nestor: Phases 1, 4, 8
- Elena-DBA: Phases 2, 3, 6 (backend)
- Sophie-FE: Phase 5 (frontend)
- Igor-coder: Phase 6 (agent-side)
- David-QA: Phase 7 (testing)
- Marco-reviewer: Reviews after phases 2, 3, 4, 5, 6, 7, 8

**Ready to start Phase 1: Environment Verification?**
