# Doctoid - Complete Specification

**Android Background Usage Monitoring Dashboard**

Version: 1.0
Date: 2025-01-30
Status: Planning Complete

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Research Sources](#research-sources)
3. [Architecture](#architecture)
4. [Database Schema](#database-schema)
5. [API Specification](#api-specification)
6. [Frontend Specification](#frontend-specification)
7. [Skills Required](#skills-required)
8. [Implementation Agents](#implementation-agents)
9. [Implementation Phases](#implementation-phases)
10. [File Structure](#file-structure)

---

## Project Overview

**Doctoid** is a real-time Android background usage monitoring dashboard that connects via ADB (Android Debug Bridge) to track app behavior, battery drain, and suspicious background activity.

### Goals
| Goal | Description |
|------|-------------|
| **Battery Investigation** | Identify apps draining battery through excessive foreground service time |
| **Security/Audit** | Monitor for suspicious background activity and unusual app behavior |
| **Personal Dashboard** | Ongoing monitoring with configurable alerts when apps misbehave |

### Key Features
- Real-time monitoring with configurable refresh rate (1-60 seconds)
- Comprehensive metrics: CPU, memory, battery, temperature, foreground service time, wake locks
- Visual dashboard with interactive charts and sortable tables
- Smart alerts with color-coded severity (critical/warning/normal)
- Historical data retention (30 days by default)
- Metric toggles to show/hide different data groups
- Alert logging to file for audit trail

---

## Research Sources

### Backend & FastAPI
- [Building Real-Time Dashboards with FastAPI and Svelte](https://testdriven.io/blog/fastapi-svelte/)
- [FastAPI Observability with Grafana](https://grafana.com/grafana/dashboards/16110-fastapi-observability/)
- [10 FastAPI WebSocket Recipes for Real-Time Dashboards](https://medium.com/@Nexumo_/10-fastapi-websocket-recipes-for-real-time-dashboards-3f4fccbd9bcf)

### ADB & Android
- [Local Android metrics dashboard](https://www.reddit.com/r/Python/comments/1kxv6cr/i_built_a_local_livemetrics_dashboard_for_android_system/)
- [Automate Android Login Workflows with ADB and Python](https://proandroiddev.com/effortless-account-switching-automate-your-android-app-login-flow-with-python-and-adb-8a5aea83924d)
- [PAPIMonitor - Android API Monitor](https://github.com/0xdad0/PAPIMonitor)

### Frontend & Charts
- [Real-Time User Analytics Dashboard with Chart.js](https://dev.to/mayankchawdhari/building-a-real-time-user-analytics-dashboard-with-chartjs-track-active-inactive-users-11j7)
- [ReactJS for Real-Time Analytics Dashboards](https://makersden.io/blog/reactjs-dev-for-real-time-analytics-dashboards)
- [Top 5 React Chart Libraries 2026](https://www.syncfusion.com/blogs/post/top-5-react-chart-libraries)

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Mac (Doctoid)                             │
│                                                                     │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐      │
│  │   Collector  │─────▶│   SQLite DB  │◀─────│    Web API   │      │
│  │              │      │              │      │   (FastAPI)  │      │
│  │  • ADB queries      │  • metrics   │      │              │      │
│  │  • Parser    │      │  • app_stats │      │  • REST API  │      │
│  │  • Scheduler │      │  • alerts    │      │  • WebSocket │      │
│  └──────┬───────┘      └──────────────┘      └──────┬───────┘      │
│         │                                            │              │
│         ▼                                            ▼              │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    adb devices -l                          │   │
│  └───────────────────────────┬─────────────────────────────────┘   │
└──────────────────────────────┼─────────────────────────────────────┘
                               │ ADB over USB
                               ▼
                    ┌────────────────────┐
                    │  Android Device    │
                    │                    │
                    │  • dumpsys         │
                    │  • top             │
                    │  • /proc/*         │
                    └────────────────────┘
```

### Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Backend | Python 3.11+ | ADB interaction, async processing |
| Web Framework | FastAPI | Fast, async-native, auto API docs |
| ORM | SQLAlchemy | Type-safe queries, migrations |
| Database | SQLite | Zero configuration, efficient for time-series |
| Frontend | React + TypeScript | Type safety, component reusability |
| Charts | Chart.js | Lightweight, responsive, real-time capable |
| Async Driver | aiosqlite | Async SQLite operations |
| Config | YAML | Human-editable, comment support |

---

## Database Schema

### Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         metrics                                 │
├──────────────┬──────────────┬──────────────┬──────────────────┤
│ timestamp    │ DATETIME     │ PRIMARY KEY  │ Indexed          │
│ battery_level│ INTEGER      │ NOT NULL     │                  │
│ battery_temp │ REAL         │ NOT NULL     │                  │
│ cpu_percent  │ REAL         │              │                  │
│ memory_used  │ INTEGER      │ NOT NULL     │                  │
│ memory_free  │ INTEGER      │ NOT NULL     │                  │
└──────────────┴──────────────┴──────────────┴──────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         app_stats                               │
├──────────────┬──────────────┬──────────────┬──────────────────┤
│ id           │ INTEGER      │ PRIMARY KEY  │ AUTOINCREMENT    │
│ timestamp    │ DATETIME     │ INDEXED      │                  │
│ package_name │ TEXT         │ INDEXED      │                  │
│ fs_time_ms   │ BIGINT       │              │ Foreground service│
│ wake_lock    │ BOOLEAN      │              │                  │
│ last_used_ms │ BIGINT       │              │                  │
│ launch_count │ INTEGER      │              │                  │
│ notif_count  │ INTEGER      │              │                  │
└──────────────┴──────────────┴──────────────┴──────────────────┘
                              │
                              │ 1:N
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          alerts                                 │
├──────────────┬──────────────┬──────────────┬──────────────────┤
│ id           │ INTEGER      │ PRIMARY KEY  │ AUTOINCREMENT    │
│ timestamp    │ DATETIME     │ INDEXED      │                  │
│ severity     │ TEXT         │ CHECK        │ 'crit'\|'warn'  │
│ app_name     │ TEXT         │ INDEXED      │                  │
│ metric_name  │ TEXT         │              │                  │
│ value        │ TEXT         │              │                  │
│ threshold    │ TEXT         │              │                  │
└──────────────┴──────────────┴──────────────┴──────────────────┘
```

### SQLAlchemy Models

```python
from sqlalchemy import Column, Integer, String, DateTime, Boolean, BigInteger, Float, CheckConstraint
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class Metric(Base):
    """System metrics snapshot"""
    __tablename__ = 'metrics'
    timestamp = Column(DateTime, primary_key=True, default=datetime.utcnow)
    battery_level = Column(Integer, nullable=False)
    battery_temp = Column(Float, nullable=False)
    cpu_percent = Column(Float)
    memory_used_mb = Column(Integer, nullable=False)
    memory_free_mb = Column(Integer, nullable=False)

class AppStat(Base):
    """Per-app statistics"""
    __tablename__ = 'app_stats'
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, index=True)
    package_name = Column(String, index=True)
    foreground_service_ms = Column(BigInteger)
    wake_lock_held = Column(Boolean)
    last_used_ms = Column(BigInteger)
    launch_count = Column(Integer)
    notifications_count = Column(Integer)

class Alert(Base):
    """Alert history"""
    __tablename__ = 'alerts'
    __table_args__ = (
        CheckConstraint("severity IN ('critical', 'warning')", name='severity_check'),
    )
    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(DateTime, index=True, default=datetime.utcnow)
    severity = Column(String)
    app_name = Column(String, index=True)
    metric_name = Column(String)
    value = Column(String)
    threshold = Column(String)
```

---

## API Specification

### Endpoints

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| GET | `/api/metrics` | Current system metrics | `Metric` |
| GET | `/api/metrics/history` | Historical metrics (time range) | `Array[Metric]` |
| GET | `/api/apps` | All apps with current stats | `Array[AppStat]` |
| GET | `/api/apps/{package}` | Detailed app info | `AppStat + history` |
| GET | `/api/alerts` | Recent alerts | `Array[Alert]` |
| GET | `/api/config` | Current configuration | `Settings` |
| PUT | `/api/config` | Update configuration | `Settings` |
| WS | `/ws/updates` | Real-time metric updates | `Stream JSON` |

### Pydantic Models

```python
from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional, Literal

class Metric(BaseModel):
    timestamp: datetime
    battery_level: int = Field(ge=0, le=100)
    battery_temp: float = Field(ge=0, le=100)
    cpu_percent: Optional[float] = Field(None, ge=0, le=800)
    memory_used_mb: int
    memory_free_mb: int

class AppStat(BaseModel):
    timestamp: datetime
    package_name: str
    foreground_service_ms: int
    wake_lock_held: bool
    last_used_ms: int
    launch_count: int
    notifications_count: int

class Alert(BaseModel):
    timestamp: datetime
    severity: Literal["critical", "warning"]
    app_name: Optional[str]
    metric_name: str
    value: str
    threshold: str

class Settings(BaseModel):
    refresh_interval_seconds: int = Field(default=10, ge=1, le=60)
    device_id: Optional[str] = None
    retention_days: int = Field(default=30, ge=1, le=365)
```

### WebSocket Protocol

**Client → Server:**
```json
{"action": "subscribe", "metrics": ["system", "apps", "alerts"]}
{"action": "set_refresh_rate", "interval": 5}
```

**Server → Client:**
```json
{"type": "metrics", "data": {...}}
{"type": "apps", "data": [...]}
{"type": "alert", "data": {...}}
{"type": "status", "connected": true, "device": "SM-S911B"}
```

---

## Frontend Specification

### Component Hierarchy

```
App.tsx
├── Header.tsx
├── MetricToggles.tsx
├── RefreshSlider.tsx
├── ChartsRow
│   ├── BatteryGauge.tsx
│   └── CpuMemoryChart.tsx
├── TopAppsChart.tsx
├── AppRankingTable.tsx
└── AlertLog.tsx
```

### Custom Hooks

```typescript
// useWebSocket.ts
export function useWebSocket(url: string) {
  const [connected, setConnected] = useState(false);
  const [data, setData] = useState(null);
  // WebSocket with auto-reconnect
  return { connected, data, sendMessage };
}

// useMetrics.ts
export function useMetrics() {
  const { connected, data } = useWebSocket('ws://localhost:8000/ws/updates');
  const [metrics, setMetrics] = useState(null);
  const [apps, setApps] = useState([]);
  const [alerts, setAlerts] = useState([]);
  // Parse and update state from WebSocket
  return { connected, metrics, apps, alerts };
}

// useRefreshRate.ts
export function useRefreshRate(initial: number = 10) {
  const [rate, setRate] = useState(initial);
  const updateRate = async (newRate: number) => {
    await fetch('/api/config', {
      method: 'PUT',
      body: JSON.stringify({ refresh_interval_seconds: newRate })
    });
    setRate(newRate);
  };
  return [rate, updateRate];
}
```

### TypeScript Types

```typescript
interface Metric {
  timestamp: string;
  battery_level: number;
  battery_temp: number;
  cpu_percent: number | null;
  memory_used_mb: number;
  memory_free_mb: number;
}

interface AppStat {
  timestamp: string;
  package_name: string;
  foreground_service_ms: number;
  wake_lock_held: boolean;
  last_used_ms: number;
  launch_count: number;
  notifications_count: number;
}

interface Alert {
  timestamp: string;
  severity: 'critical' | 'warning';
  app_name: string | null;
  metric_name: string;
  value: string;
  threshold: string;
}

interface Settings {
  refresh_interval_seconds: number;
  device_id: string | null;
  retention_days: number;
}

interface MetricVisibility {
  system: boolean;
  appUsage: boolean;
  network: boolean;
  notifications: boolean;
}
```

---

## Skills Required

### Backend Skills

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| Async/await Python | Critical | `asyncio`, event loops, coroutines, futures |
| FastAPI framework | Critical | Routing, dependency injection, Pydantic models |
| RESTful API design | Critical | OpenAPI/Swagger docs, HTTP methods, status codes |
| WebSocket implementation | Critical | Real-time bidirectional communication |
| subprocess module | Critical | Executing ADB shell commands from Python |

### Frontend Skills

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| React with hooks | Critical | `useState`, `useEffect`, custom hooks |
| TypeScript | Critical | Type safety, interfaces, generics |
| Chart.js | Critical | Line charts, bar charts, real-time updates |
| WebSocket client | Critical | `WebSocket` API, reconnection logic |
| State management | Optional | Context API, Zustand, or Redux |

### Database Skills

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| SQLAlchemy async | Critical | ORM models, async sessions, queries |
| SQLite | Critical | Write-Ahead Logging, concurrent access |
| Time-series patterns | Critical | Efficient querying, aggregation, retention |

---

## Implementation Agents

### Agent Architecture

```
                    ┌─────────────────────┐
                    │  Project Manager    │
                    │    (You / Human)    │
                    └──────────┬──────────┘
                               │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Collector      │    │  Database       │    │  API &          │
│  Agent          │    │  Agent          │    │  WebSocket      │
│                 │    │                 │    │  Agent          │
│ • ADB client    │    │ • SQLAlchemy    │    │ • FastAPI       │
│ • Metrics       │    │ • Models        │    │ • Routes        │
│   parser        │    │ • Queries       │    │ • WebSocket     │
│ • Collector     │    │ • Sessions      │    │ • Validation    │
│   loop          │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  Frontend Dashboard     │
                    │  Agent                  │
                    │                         │
                    │ • React + TypeScript    │
                    │ • Chart.js integration  │
                    │ • WebSocket client      │
                    │ • State management      │
                    └─────────────────────────┘
```

### Agent 1: Collector Agent

**Purpose:** Implement ADB integration, data collection, and metrics parsing.

**Files to Create:**
```
collector/
├── __init__.py
├── adb_client.py      # ADB connection, device detection, safe queries
├── metrics.py         # Parse dumpsys output into Python dicts
└── collector.py       # Main async collection loop
```

**Key Functions:**
```python
class ADBClient:
    async def check_connection() -> bool
    async def query(command: str, timeout: int = 10) -> str | None
    async def get_device_id() -> str | None
    async def list_devices() -> List[str]

class MetricsParser:
    def parse_system_metrics(output: str) -> Metric
    def parse_app_stats(output: str) -> List[AppStat]
    def parse_battery_stats(output: str) -> BatteryStats

class DataCollector:
    async def collect_loop()
    async def collect_system_metrics() -> Metric
    async def collect_app_metrics() -> List[AppStat]
```

**Dependencies:** `asyncio`, `pydantic`

### Agent 2: Database Agent

**Purpose:** Implement SQLAlchemy models, database operations, and data retention.

**Files to Create:**
```
database/
├── __init__.py
├── models.py          # SQLAlchemy ORM models
├── db.py              # Database connection, session management
└── queries.py         # Common query functions
```

**Key Functions:**
```python
class Metric(Base): ...
class AppStat(Base): ...
class Alert(Base): ...

async def init_db()
async def get_session() -> AsyncSession
async def get_latest_metrics() -> Metric
async def get_metrics_history(start, end) -> List[Metric]
async def get_top_apps_by_fs_time(limit: int) -> List[AppStat]
async def store_metrics(metrics: Metric, apps: List[AppStat])
async def cleanup_old_data(days: int)
```

**Dependencies:** `sqlalchemy>=2.0`, `aiosqlite>=0.19.0`

### Agent 3: API Agent

**Purpose:** Implement FastAPI backend with WebSocket support for real-time updates.

**Files to Create:**
```
api/
├── __init__.py
├── main.py            # FastAPI app setup
├── routes.py          # API endpoints
├── websocket.py       # WebSocket handler
└── models.py          # Pydantic request/response models
```

**Key Functions:**
```python
app = FastAPI(title="Doctoid API")

@router.get("/api/metrics")
async def get_metrics() -> Metric

@router.get("/api/apps")
async def get_apps() -> List[AppStat]

@router.get("/api/alerts")
async def get_alerts(limit: int = 50) -> List[Alert]

@router.websocket("/ws/updates")
async def websocket_endpoint(websocket: WebSocket)
```

**Dependencies:** `fastapi>=0.104.0`, `uvicorn[standard]>=0.24.0`, `websockets>=12.0`, `pydantic>=2.0`

### Agent 4: Frontend Agent

**Purpose:** Implement React TypeScript dashboard with Chart.js visualization.

**Files to Create:**
```
frontend/
├── package.json
├── vite.config.ts
├── tsconfig.json
└── src/
    ├── main.tsx
    ├── App.tsx
    ├── components/
    │   ├── Header.tsx
    │   ├── MetricToggles.tsx
    │   ├── BatteryGauge.tsx
    │   ├── CpuMemoryChart.tsx
    │   ├── TopAppsChart.tsx
    │   ├── AppRankingTable.tsx
    │   ├── AlertLog.tsx
    │   └── RefreshSlider.tsx
    ├── hooks/
    │   ├── useMetrics.ts
    │   ├── useWebSocket.ts
    │   └── useRefreshRate.ts
    ├── types/
    │   └── index.ts
    └── styles/
        └── globals.css
```

**Key Components:**
```tsx
function App() {
  return (
    <div className="dashboard">
      <Header />
      <MetricToggles />
      <div className="charts-row">
        <BatteryGauge />
        <CpuMemoryChart />
      </div>
      <TopAppsChart />
      <AppRankingTable />
      <AlertLog />
    </div>
  );
}

function useWebSocket(url: string) {
  const [connected, setConnected] = useState(false);
  const [data, setData] = useState(null);
  // WebSocket with reconnection logic
  return { connected, data, sendMessage };
}
```

**Dependencies:**
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@vitejs/plugin-react": "^4.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

### Agent 5: Integration Agent

**Purpose:** Orchestrate all components, handle configuration, logging, and process management.

**Files to Create:**
```
doctoid/
├── config/
│   └── settings.yaml      # Alert thresholds, refresh rate
├── logs/                  # alerts.log, collector.log
├── data/                  # monitor.db (auto-created)
├── requirements.txt
└── run.py                 # Entry point
```

**Configuration:**
```yaml
device_id: null
refresh_interval_seconds: 10
retention_days: 30

alert_thresholds:
  foreground_service_time:
    critical: 72000000
    warning: 36000000
  cpu_percent:
    critical: 20
    warning: 10
  battery_temp:
    critical: 40.0
    warning: 35.0

logging:
  level: INFO
  alerts_log_file: logs/alerts.log
  collector_log_file: logs/collector.log
```

**Entry Point:**
```python
async def main():
    # Initialize database
    await init_db()

    # Start collector in background
    collector = DataCollector(settings)
    collector_task = asyncio.create_task(collector.collect_loop())

    # Start API server
    config = uvicorn.Config(app, host="0.0.0.0", port=8000)
    server = uvicorn.Server(config)
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
```

**Dependencies:** `pyyaml>=6.0`, `uvicorn`

---

## Implementation Phases

### Phase 1: Foundation (Parallel - 3 Agents)

| Agent | Tasks | Output |
|-------|-------|--------|
| **Collector** | ADB client, metrics parser, collection loop | `collector/` |
| **Database** | SQLAlchemy models, queries, sessions | `database/` |
| **API** | FastAPI routes, WebSocket, validation | `api/` |

### Phase 2: Frontend (1 Agent)

| Agent | Tasks | Output |
|-------|-------|--------|
| **Frontend** | React app, Chart.js, WebSocket client | `frontend/` |

### Phase 3: Integration (1 Agent)

| Agent | Tasks | Output |
|-------|-------|--------|
| **Integration** | Config, logging, orchestration, run.py | `config/`, `run.py`, `requirements.txt` |

---

## File Structure

```
doctoid/
├── collector/
│   ├── __init__.py
│   ├── adb_client.py      # ADB connection, device detection, safe queries
│   ├── metrics.py         # Parse dumpsys output
│   └── collector.py       # Main async collection loop
├── api/
│   ├── __init__.py
│   ├── main.py            # FastAPI app
│   ├── routes.py          # API endpoints
│   ├── websocket.py       # Real-time data push
│   └── models.py          # Pydantic models
├── frontend/
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   └── src/
│       ├── main.tsx
│       ├── App.tsx
│       ├── components/
│       │   ├── Header.tsx
│       │   ├── MetricToggles.tsx
│       │   ├── BatteryGauge.tsx
│       │   ├── CpuMemoryChart.tsx
│       │   ├── TopAppsChart.tsx
│       │   ├── AppRankingTable.tsx
│       │   ├── AlertLog.tsx
│       │   └── RefreshSlider.tsx
│       ├── hooks/
│       │   ├── useMetrics.ts
│       │   ├── useWebSocket.ts
│       │   └── useRefreshRate.ts
│       ├── types/
│       │   └── index.ts
│       └── styles/
│           └── globals.css
├── database/
│   ├── __init__.py
│   ├── models.py          # SQLAlchemy models
│   ├── db.py              # DB connection
│   └── queries.py         # Query functions
├── config/
│   └── settings.yaml      # Alert thresholds, refresh rate
├── logs/                  # alerts.log, collector.log
├── data/                  # monitor.db (auto-created)
├── requirements.txt
├── run.py                 # Entry point
└── README.md
```

---

## Custom Skills

All 5 skills are now active and can be invoked in any Claude session:

| Skill | Purpose | Invoke |
|-------|---------|--------|
| `doctoid-collector` | ADB integration, data collection, parsing | `Skill skill:doctoid-collector` |
| `doctoid-database` | SQLAlchemy models, async queries | `Skill skill:doctoid-database` |
| `doctoid-api` | FastAPI, WebSocket, REST endpoints | `Skill skill:doctoid-api` |
| `doctoid-frontend` | React TypeScript, Chart.js dashboard | `Skill skill:doctoid-frontend` |
| `doctoid-integration` | Config, logging, orchestration | `Skill skill:doctoid-integration` |

**Usage:**
```bash
# Examples:
"Use doctoid-collector skill to implement the ADB client"
"Use doctoid-database skill to create the SQLAlchemy models"
"Use doctoid-api skill to build the FastAPI routes"
"Use doctoid-frontend skill to create the React dashboard"
"Use doctoid-integration skill to set up run.py"
```

---

## Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Foreground Service Time | > 10 hours | > 20 hours |
| CPU Percent | > 10% | > 20% |
| Battery Temperature | > 35°C | > 40°C |
| Battery Level | < 30% | < 15% |

---

## Verification Checklist

- [ ] Run `python run.py` → Starts collector + API
- [ ] Open `http://localhost:8000` → Dashboard shows device metrics
- [ ] Change refresh slider → Data updates at new rate
- [ ] Toggle metrics off/on → Charts show/hide appropriately
- [ ] Trigger alert (high CPU app) → Alert appears in log + red badge
- [ ] Disconnect device → "Waiting for device..." banner
- [ ] Reconnect device → Auto-resume collection

---

## Documentation

- **Design**: `/Users/jm/Codebase/internet-control/docs/doctoid/design.md`
- **Skills Analysis**: `/Users/jm/Codebase/internet-control/docs/doctoid/skills-analysis.md`
- **Agents**: `/Users/jm/Codebase/internet-control/docs/doctoid/agents.md`
- **Consolidated Spec**: `/Users/jm/Codebase/internet-control/docs/doctoid/SPECIFICATION.md`

---

*End of Specification*
