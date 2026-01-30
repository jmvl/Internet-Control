# Doctoid - Parallel Implementation Agents

**Purpose**: Define specialized agents for parallel development of Doctoid components.

## Agent Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Orchestration Layer                          │
│                    (Project Manager / Human)                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
          ┌──────────────────────┼──────────────────────┐
          ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Collector      │    │  API &          │    │  Database       │
│  Agent          │    │  WebSocket      │    │  Agent          │
│                 │    │  Agent          │    │                 │
│ • ADB client    │    │ • FastAPI       │    │ • SQLAlchemy    │
│ • Metrics       │    │ • Routes        │    │ • Models        │
│   parser        │    │ • WebSocket     │    │ • Queries       │
│ • Collector     │    │ • Validation    │    │ • Migrations    │
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

---

## Agent 1: Collector Agent

**Purpose**: Implement ADB integration, data collection, and metrics parsing.

### Responsibilities
- ADB connection management and device detection
- Execute ADB commands with timeout handling
- Parse `dumpsys` output into structured data
- Implement async collection loop
- Handle disconnection/reconnection logic

### Skills Required
- Python `asyncio` and subprocess management
- ADB command knowledge (`dumpsys`, `top`, `/proc` filesystem)
- String parsing and regex for unstructured output
- Error handling and retry logic

### Files to Create
```
collector/
├── __init__.py
├── adb_client.py      # ADB connection, device detection, safe queries
├── metrics.py         # Parse dumpsys output into Python dicts
└── collector.py       # Main async collection loop
```

### Key Functions to Implement
```python
# collector/adb_client.py
class ADBClient:
    async def check_connection() -> bool
    async def query(command: str, timeout: int = 10) -> str | None
    async def get_device_id() -> str | None
    async def list_devices() -> List[str]

# collector/metrics.py
class MetricsParser:
    def parse_system_metrics(output: str) -> Metric
    def parse_app_stats(output: str) -> List[AppStat]
    def parse_battery_stats(output: str) -> BatteryStats
    def parse_wake_locks(output: str) -> List[WakeLock]

# collector/collector.py
class DataCollector:
    async def collect_loop()
    async def collect_system_metrics() -> Metric
    async def collect_app_metrics() -> List[AppStat]
    async def check_alerts() -> List[Alert]
```

### Dependencies
- `asyncio` - Async subprocess execution
- `pydantic` - Data validation models
- No external ADB libraries - use subprocess directly

### Success Criteria
- [ ] Can detect connected Android devices
- [ ] Can execute ADB commands and get output
- [ ] Can parse dumpsys output into structured data
- [ ] Collection loop runs at configurable intervals
- [ ] Handles device disconnection gracefully

---

## Agent 2: API & WebSocket Agent

**Purpose**: Implement FastAPI backend with WebSocket support for real-time updates.

### Responsibilities
- FastAPI application setup
- RESTful API endpoints
- WebSocket connection management
- Request/response validation with Pydantic
- CORS configuration

### Skills Required
- FastAPI framework and dependency injection
- WebSocket protocol and connection lifecycle
- Pydantic models for validation
- Async/await patterns

### Files to Create
```
api/
├── __init__.py
├── main.py            # FastAPI app setup
├── routes.py          # API endpoints
├── websocket.py       # WebSocket handler
└── models.py          # Pydantic request/response models
```

### Key Functions to Implement
```python
# api/main.py
app = FastAPI(title="Doctoid API")
app.add_middleware(CORSMiddleware)

# api/routes.py
@router.get("/api/metrics")
async def get_metrics() -> Metric

@router.get("/api/metrics/history")
async def get_metrics_history(
    start: datetime,
    end: datetime
) -> List[Metric]

@router.get("/api/apps")
async def get_apps() -> List[AppStat]

@router.get("/api/alerts")
async def get_alerts(limit: int = 50) -> List[Alert]

@router.get("/api/config")
async def get_config() -> Settings

@router.put("/api/config")
async def update_config(settings: Settings) -> Settings

# api/websocket.py
async def websocket_endpoint(websocket: WebSocket)
async def broadcast_update(data: dict)
```

### Dependencies
- `fastapi` - Web framework
- `uvicorn[standard]` - ASGI server with WebSockets
- `websockets` - WebSocket client for testing
- `pydantic` - Data validation

### Success Criteria
- [ ] API serves OpenAPI docs at /docs
- [ ] All endpoints return valid JSON
- [ ] WebSocket accepts connections
- [ ] WebSocket broadcasts updates to all clients
- [ ] CORS allows frontend connections

---

## Agent 3: Database Agent

**Purpose**: Implement SQLAlchemy models, database operations, and data retention.

### Responsibilities
- Database schema definition
- SQLAlchemy async session management
- CRUD operations for all entities
- Data aggregation and historical queries
- Retention policy implementation

### Skills Required
- SQLAlchemy ORM and async sessions
- SQLite with WAL mode configuration
- Time-series data patterns
- Database indexing for performance

### Files to Create
```
database/
├── __init__.py
├── models.py          # SQLAlchemy ORM models
├── db.py              # Database connection, session management
└── queries.py         # Common query functions
```

### Key Functions to Implement
```python
# database/models.py
class Metric(Base):
    __tablename__ = 'metrics'
    timestamp = Column(DateTime, primary_key=True)
    battery_level = Column(Integer)
    battery_temp = Column(Float)
    cpu_percent = Column(Float)
    memory_used_mb = Column(Integer)
    memory_free_mb = Column(Integer)

class AppStat(Base):
    __tablename__ = 'app_stats'
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, index=True)
    package_name = Column(String, index=True)
    foreground_service_ms = Column(BigInteger)
    wake_lock_held = Column(Boolean)
    last_used_ms = Column(BigInteger)
    launch_count = Column(Integer)
    notifications_count = Column(Integer)

class Alert(Base):
    __tablename__ = 'alerts'
    id = Column(Integer, primary_key=True)
    timestamp = Column(DateTime, index=True)
    severity = Column(String)
    app_name = Column(String, index=True)
    metric_name = Column(String)
    value = Column(String)
    threshold = Column(String)

# database/db.py
async def init_db()
async def get_session() -> AsyncSession
async def create_tables()

# database/queries.py
async def get_latest_metrics() -> Metric
async def get_metrics_history(start, end) -> List[Metric]
async def get_top_apps_by_fs_time(limit: int) -> List[AppStat]
async def get_recent_alerts(limit: int) -> List[Alert]
async def store_metrics(metrics: Metric, apps: List[AppStat])
async def store_alert(alert: Alert)
async def cleanup_old_data(days: int)
```

### Dependencies
- `sqlalchemy` - ORM and async sessions
- `aiosqlite` - Async SQLite driver
- `alembic` - Database migrations (optional for Phase 1)

### Success Criteria
- [ ] Database file created automatically
- [ ] Tables created with correct schema
- [ ] Can insert and query metrics
- [ ] Indexes improve query performance
- [ ] Old data cleaned up by retention policy

---

## Agent 4: Frontend Dashboard Agent

**Purpose**: Implement React TypeScript dashboard with Chart.js visualization.

### Responsibilities
- React app structure with Vite
- Chart.js integration and configuration
- WebSocket client for real-time updates
- Metric toggle components
- Sortable app ranking table
- Alert log panel

### Skills Required
- React functional components and hooks
- TypeScript type definitions
- Chart.js configuration and updates
- WebSocket client with reconnection
- State management (Context API or similar)

### Files to Create
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

### Key Components to Implement
```tsx
// src/App.tsx
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

// src/hooks/useMetrics.ts
function useMetrics() {
  const [metrics, setMetrics] = useState<Metric | null>(null);
  // WebSocket connection and updates
  return metrics;
}

// src/hooks/useWebSocket.ts
function useWebSocket(url: string) {
  const [connected, setConnected] = useState(false);
  const [data, setData] = useState<any>(null);
  // WebSocket with reconnection logic
  return { connected, data };
}

// src/components/RefreshSlider.tsx
function RefreshSlider() {
  const [rate, setRate] = useState(10);
  const updateRate = async (newRate: number) => {
    await fetch('/api/config', {
      method: 'PUT',
      body: JSON.stringify({ refresh_interval: newRate })
    });
    setRate(newRate);
  };
  return <input type="range" min="1" max="60" value={rate} onChange={...} />;
}
```

### Dependencies
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
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

### Success Criteria
- [ ] React app builds without errors
- [ ] Charts render with sample data
- [ ] WebSocket connects and receives updates
- [ ] Metric toggles show/hide charts
- [ ] Refresh slider changes update rate
- [ ] Table sorts by clicking columns

---

## Agent 5: Integration & DevOps Agent

**Purpose**: Orchestrate all components, handle configuration, logging, and process management.

### Responsibilities
- Configuration file management (YAML)
- Logging setup and rotation
- Process orchestration (collector + API server)
- Error handling and recovery
- Build scripts and entry points

### Skills Required
- YAML parsing and validation
- Python logging configuration
- Process management (subprocess, signals)
- Shell scripting for build/deploy

### Files to Create
```
doctoid/
├── config/
│   └── settings.yaml      # Alert thresholds, refresh rate, etc.
├── logs/
│   ├── alerts.log         # Alert history (auto-rotated)
│   └── collector.log      # Collector debug logs
├── data/
│   └── monitor.db         # SQLite database (auto-created)
├── run.py                 # Entry point: starts collector + API
├── requirements.txt       # Python dependencies
├── README.md              # Setup and usage instructions
└── pyproject.toml         # Project metadata
```

### Key Functions to Implement
```python
# run.py
import asyncio
from collector.collector import DataCollector
from api.main import app

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

### Configuration Schema
```yaml
# config/settings.yaml
device_id: null  # Auto-detect or specify
refresh_interval_seconds: 10
retention_days: 30

alert_thresholds:
  foreground_service_time:
    critical: 72000000  # 20 hours
    warning: 36000000   # 10 hours
  cpu_percent:
    critical: 20
    warning: 10
  battery_temp:
    critical: 40.0
    warning: 35.0
  battery_level:
    critical: 15
    warning: 30

log_level: INFO
alerts_log_file: logs/alerts.log
collector_log_file: logs/collector.log
log_retention_days: 90

database_path: data/monitor.db
```

### Dependencies
- `pyyaml` - Configuration file parsing
- `uvicorn` - ASGI server (already in API agent)
- `python-daemon` (optional) - Background process management

### Success Criteria
- [ ] run.py starts both collector and API
- [ ] Settings loaded from YAML
- [ ] Logs written to files with rotation
- [ ] Graceful shutdown on SIGINT/SIGTERM
- [ ] Database created on first run

---

## Parallel Execution Strategy

### Phase 1: Foundation (Parallel - Agents 1, 2, 3)
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Collector  │  │  Database   │  │     API     │
│   Agent     │  │   Agent     │  │   Agent     │
│             │  │             │  │             │
│  ADB client │  │   Models    │  │   Routes    │
│  Parser     │  │   Queries   │  │  WebSocket  │
│  Loop       │  │   Session   │  │  Validation │
└─────────────┘  └─────────────┘  └─────────────┘
       │                │                │
       └────────────────┼────────────────┘
                        ▼
                 ┌─────────────┐
                 │  Integration│
                 │    Agent    │
                 │             │
                 │  Config     │
                 │  Logging    │
                 │  Orchest.   │
                 └─────────────┘
```

### Phase 2: Frontend (Agent 4)
```
┌─────────────────────────────────────┐
│      Frontend Dashboard Agent       │
│                                     │
│  • React app structure              │
│  • Chart.js components              │
│  • WebSocket client                 │
│  • State management                 │
└─────────────────────────────────────┘
```

### Phase 3: Integration (Agent 5)
```
All agents merge into integrated application
```

---

## Agent Communication Protocol

### Data Flow Between Agents
```
Collector Agent → Database Agent
  (Raw metrics)  → (Store in DB)

Database Agent → API Agent
  (Query result) → (JSON response)

API Agent → Frontend Agent
  (WebSocket)    → (Real-time updates)

All Agents → Integration Agent
  (Status logs)  → (Unified logging)
```

### Shared Contracts
```python
# Shared type definitions (database/models.py)
class Metric(BaseModel):
    timestamp: datetime
    battery_level: int
    battery_temp: float
    cpu_percent: float | None
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
    app_name: str | None
    metric_name: str
    value: str
    threshold: str
```

---

## Skills Sources

Based on research from:

**Backend & FastAPI:**
- [Building Real-Time Dashboards with FastAPI and Svelte](https://testdriven.io/blog/fastapi-svelte/)
- [FastAPI Observability with Grafana](https://grafana.com/grafana/dashboards/16110-fastapi-observability/)
- [10 FastAPI WebSocket Recipes](https://medium.com/@Nexumo_/10-fastapi-websocket-recipes-for-real-time-dashboards-3f4fccbd9bcf)

**ADB & Android:**
- [Local Android metrics dashboard](https://www.reddit.com/r/Python/comments/1kxv6cr/i_built_a_local_livemetrics_dashboard_for_android_system/)
- [PAPIMonitor - Android API Monitor](https://github.com/0xdad0/PAPIMonitor)

**Frontend & Charts:**
- [Real-Time User Analytics Dashboard with Chart.js](https://dev.to/mayankchawdhari/building-a-real-time-user-analytics-dashboard-with-chartjs-track-active-inactive-users-11j7)
- [ReactJS for Real-Time Analytics Dashboards](https://makersden.io/blog/reactjs-dev-for-real-time-analytics-dashboards)
- [Top 5 React Chart Libraries 2026](https://www.syncfusion.com/blogs/post/top-5-react-chart-libraries)

---

*Last Updated: 2025-01-30*
