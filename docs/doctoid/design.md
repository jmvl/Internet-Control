# Doctoid - Android Background Usage Monitor

**Design Document** - 2025-01-30

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Collection](#data-collection)
4. [Database Schema](#database-schema)
5. [Web API](#web-api)
6. [Frontend Dashboard](#frontend-dashboard)
7. [Alert System](#alert-system)
8. [Error Handling](#error-handling)
9. [Configuration](#configuration)
10. [Implementation Plan](#implementation-plan)

---

## Overview

**Doctoid** is a real-time monitoring dashboard for Android devices that connects via ADB to track app background usage, battery drain, and suspicious activity.

### Goals
| Goal | Description |
|------|-------------|
| **Battery Investigation** | Identify apps draining battery through excessive foreground service time |
| **Security/Audit** | Monitor for suspicious background activity and unusual app behavior |
| **Personal Dashboard** | Ongoing monitoring with configurable alerts when apps misbehave |

### Key Features
- **Real-time monitoring** with configurable refresh rate (1-60 seconds)
- **Comprehensive metrics**: CPU, memory, battery, temperature, foreground service time, wake locks, notifications
- **Visual dashboard** with interactive charts and sortable tables
- **Smart alerts** with color-coded severity (critical/warning/normal)
- **Historical data** retention (30 days by default)
- **Metric toggles** to show/hide different data groups
- **Alert logging** to file for audit trail

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

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Backend** | Python 3.11+ | Excellent ADB integration via subprocess, async support |
| **Web Framework** | FastAPI | Fast, async native, auto API docs, WebSocket support |
| **ORM** | SQLAlchemy | Type-safe queries, migration support |
| **Database** | SQLite | Zero configuration, efficient for time-series |
| **Frontend** | React + TypeScript | Type safety, component reusability |
| **Charts** | Chart.js | Lightweight, responsive, real-time capable |
| **Config** | YAML | Human-editable, comment support |

---

## Data Collection

### ADB Commands Used

| Command | Purpose | Frequency |
|---------|---------|-----------|
| `adb devices -l` | Device detection, connection status | Every 30s (reconnect check) |
| `dumpsys usagestats --checkin` | App usage, FS time, launch counts | Every refresh cycle |
| `dumpsys batterystats` | Battery drain by app | Every refresh cycle |
| `dumpsys power` | Wake locks, suspend blockers | Every refresh cycle |
| `dumpsys battery` | Current %, temp, voltage | Every refresh cycle |
| `dumpsys appops <package>` | Background permissions | On change + every 5 min |
| `top -n 1` | Real-time CPU/memory per process | Every refresh cycle |
| `cat /proc/net/dev` | Network activity per interface | Every refresh cycle |

### Collector Architecture

```python
# collector/collector.py

class DataCollector:
    """Main collection orchestrator with async scheduling"""

    def __init__(self, config: Settings):
        self.adb = ADBClient(config.device_id)
        self.parser = MetricsParser()
        self.db = DatabaseSession()
        self.refresh_interval = config.refresh_interval_seconds

    async def collect_loop(self):
        """Main collection loop"""
        while self.running:
            try:
                # Check connection first
                if not self.adb.is_connected():
                    await self.handle_disconnect()
                    continue

                # Collect all metrics in parallel
                results = await asyncio.gather(
                    self.collect_system_metrics(),
                    self.collect_app_metrics(),
                    self.collect_battery_stats(),
                    return_exceptions=True
                )

                # Store in database
                await self.store_metrics(results)

                # Check for alerts
                await self.check_alerts()

                # Push to WebSocket clients
                await self.broadcast_update(results)

            except Exception as e:
                logger.error(f"Collection error: {e}")

            # Wait for next cycle
            await asyncio.sleep(self.refresh_interval)

    async def collect_system_metrics(self):
        """Collect system-wide metrics"""
        cpu_mem = await self.adb.query("top -n 1")
        battery = await self.adb.query("dumpsys battery")
        return self.parser.parse_system(cpu_mem, battery)

    async def collect_app_metrics(self):
        """Collect per-app metrics"""
        usage = await self.adb.query("dumpsys usagestats --checkin")
        power = await self.adb.query("dumpsys power")
        return self.parser.parse_apps(usage, power)
```

### Smart Collection Strategies

1. **Incremental Updates**: Only fetch detailed appops for apps that changed
2. **Caching Layer**: Store system stats once, reuse for app calculations
3. **Parallel Queries**: Run independent ADB commands concurrently
4. **Delta Detection**: Only log entries when values change significantly (>5%)
5. **Adaptive Rate**: Slow down collection when device is idle/screen off

---

## Database Schema

### Schema Diagram

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
│ severity     │ TEXT         │ CHECK        │ 'crit'|'warn'    │
│ app_name     │ TEXT         │ INDEXED      │                  │
│ metric_name  │ TEXT         │              │                  │
│ value        │ TEXT         │              │                  │
│ threshold    │ TEXT         │              │                  │
└──────────────┴──────────────┴──────────────┴──────────────────┘
```

### SQLAlchemy Models

```python
# database/models.py

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

### Data Retention

- **Raw metrics**: 30 days, then aggregate to hourly averages
- **Aggregated metrics**: 365 days
- **Alerts**: 90 days (never aggregated)

---

## Web API

### API Endpoints

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| GET | `/api/metrics` | Current system metrics | Metric object |
| GET | `/api/metrics/history` | Historical metrics (time range) | Array[Metric] |
| GET | `/api/apps` | All apps with current stats | Array[AppStat] |
| GET | `/api/apps/{package}` | Detailed app info | AppStat + history |
| GET | `/api/alerts` | Recent alerts | Array[Alert] |
| GET | `/api/config` | Current configuration | Settings object |
| PUT | `/api/config` | Update configuration | Updated Settings |
| WS | `/ws/updates` | Real-time metric updates | Stream JSON |

### WebSocket Protocol

```python
# Client → Server
{"action": "subscribe", "metrics": ["system", "apps", "alerts"]}
{"action": "set_refresh_rate", "interval": 5}

# Server → Client
{"type": "metrics", "data": {...}}
{"type": "apps", "data": [...]}
{"type": "alert", "data": {...}}
{"type": "status", "connected": true, "device": "SM-S911B"}
```

### FastAPI Setup

```python
# api/main.py

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from .routes import router
from .websocket import handle_websocket

app = FastAPI(title="Doctoid API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")

@app.websocket("/ws/updates")
async def websocket_endpoint(websocket: WebSocket):
    await handle_websocket(websocket)
```

---

## Frontend Dashboard

### Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  Doctoid                        [Refresh: ▼10s] [⚙️] [📥 Export]     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Toggle Metrics:]                                                   │
│  ☑ System  ☑ App Usage  ☑ Network  ☑ Notifications                 │
│                                                                      │
│  ┌─────────────────────────┐  ┌─────────────────────────┐          │
│  │    Battery & Temp       │  │      CPU & Memory       │          │
│  │    [circular gauge]     │  │    [sparkline chart]    │          │
│  │    72% • 26.6°C         │  │    CPU: 5% • Mem: 98%   │          │
│  └─────────────────────────┘  └─────────────────────────┘          │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Top Apps by Foreground Service Time                         │  │
│  │  [████████████████████████████████] 24h  com.teslamotors.tesla│  │
│  │  [████████████] 2h                com.whatsapp               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  App Ranking Table                           [Sort: ▼FS Time] │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ App                    │ FS Time │ CPU  │ Wake Lock │ Status│  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ 🟡 com.teslamotors.tesla │ 24h    │ 0%   │ No        │ ⚠️   │  │
│  │ 🟢 com.whatsapp          │ 5min   │ 2%   │ No        │ ✓    │  │
│  │ 🟢 com.facebook.katana   │ 30min  │ 1%   │ No        │ ✓    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Recent Alerts                        [Filter: ▼All] [Clear]  │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │ 🔴 10:45  Tesla FS time > 20h (24h)                           │  │
│  │ 🟡 10:30  AliExpress CPU > 10% (13.3%)                        │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

```tsx
// frontend/src/App.tsx

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

// Key components
- MetricToggles: Checkbox group for show/hide metrics
- RefreshSlider: Range input 1-60s with presets
- BatteryGauge: Circular progress with temp
- CpuMemoryChart: Dual-line sparkline
- TopAppsChart: Horizontal bar chart
- AppRankingTable: Sortable table with status badges
- AlertLog: Scrollable list with filters
```

### State Management

```tsx
// Custom hooks
function useMetrics() {
  // Fetch from /api/metrics, subscribe to WS
  const [metrics, setMetrics] = useState(null);
  useEffect(() => {
    const ws = new WebSocket('ws://localhost:8000/ws/updates');
    ws.onmessage = (msg) => {
      const data = JSON.parse(msg.data);
      if (data.type === 'metrics') setMetrics(data.data);
    };
    return () => ws.close();
  }, []);
  return metrics;
}

function useRefreshRate() {
  const [rate, setRate] = useState(10);
  const updateRate = (newRate) => {
    fetch('/api/config', { method: 'PUT', body: JSON.stringify({ refresh_interval: newRate }) });
    setRate(newRate);
  };
  return [rate, updateRate];
}
```

---

## Alert System

### Alert Detection Engine

```python
# collector/alerts.py

class AlertEngine:
    """Detects and logs alert conditions"""

    def __init__(self, thresholds: Dict[str, Dict]):
        self.thresholds = thresholds

    async def check_metrics(self, metrics: Metric, apps: List[AppStat]):
        """Evaluate all alert rules"""
        alerts = []

        # System-level alerts
        if metrics.battery_temp >= self.thresholds['battery_temp']['critical']:
            alerts.append(Alert(
                severity='critical',
                metric_name='battery_temp',
                value=f"{metrics.battery_temp}°C",
                threshold=f">{self.thresholds['battery_temp']['critical']}°C"
            ))

        # App-level alerts
        for app in apps:
            fs_hours = app.foreground_service_ms / 1000 / 60 / 60
            if fs_hours >= self.thresholds['foreground_service_time']['critical'] / 1000 / 60 / 60:
                alerts.append(Alert(
                    severity='critical',
                    app_name=app.package_name,
                    metric_name='foreground_service_time',
                    value=f"{fs_hours:.1f}h",
                    threshold=f">20h"
                ))

        # Store and return
        await self.store_alerts(alerts)
        return alerts
```

### Default Thresholds

```yaml
# config/settings.yaml

alert_thresholds:
  foreground_service_time:
    critical: 72000000  # 20 hours in ms
    warning: 36000000   # 10 hours
  cpu_percent:
    critical: 20
    warning: 10
  battery_temp:
    critical: 40.0  # Celsius
    warning: 35.0
  battery_level:
    critical: 15   # percent
    warning: 30
```

### Alert Actions

| Severity | Visual | Log | Notification |
|----------|--------|-----|--------------|
| Critical | 🔴 Red badge | alerts.log | Dashboard banner |
| Warning | 🟡 Yellow badge | alerts.log | Badge on app row |

### Log Format

```
# logs/alerts.log
2025-01-30T10:45:23.123Z CRITICAL com.teslamotors.tesla foreground_service_time value=86399999ms threshold=72000000ms
2025-01-30T10:30:15.456Z WARNING com.alibaba.intl.android.apps.poseidon cpu_percent value=13.3 threshold=10
```

---

## Error Handling

### Connection Management

```python
# collector/adb_client.py

class ADBClient:
    """Safe ADB connection handling"""

    async def check_connection(self):
        """Verify device is connected"""
        result = await self.query("devices -l", timeout=5)
        if not result or self.device_id not in result:
            self.connected = False
            return False
        self.connected = True
        return True

    async def query(self, command: str, timeout: int = 10):
        """Execute ADB command with timeout"""
        try:
            proc = await asyncio.create_subprocess_exec(
                'adb', 'shell', command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(),
                timeout=timeout
            )
            return stdout.decode('utf-8')
        except asyncio.TimeoutError:
            logger.warning(f"ADB timeout: {command}")
            return None
        except Exception as e:
            logger.error(f"ADB error: {e}")
            return None
```

### Error Recovery

| Error | Detection | Recovery |
|-------|-----------|----------|
| Device disconnected | `adb devices` empty | Banner + retry every 30s |
| Multiple devices | >1 device in list | Prompt user, store selection |
| Permission denied | dumpsys fails | Show "N/A", log to debug.log |
| Database locked | SQLite exception | Retry 3x with backoff |
| OOM | Process memory >500MB | Restart collector, log warning |

---

## Configuration

### Settings File

```yaml
# config/settings.yaml

# ADB Connection
device_id: null  # Auto-detect, or specify "RZCW90HMP2Y"

# Collection
refresh_interval_seconds: 10
retention_days: 30

# Alert Thresholds
alert_thresholds:
  foreground_service_time:
    critical: 72000000  # ms
    warning: 36000000
  cpu_percent:
    critical: 20
    warning: 10
  battery_temp:
    critical: 40.0
    warning: 35.0
  battery_level:
    critical: 15
    warning: 30

# Logging
log_level: INFO
alerts_log_file: logs/alerts.log
collector_log_file: logs/collector.log
log_retention_days: 90

# Database
database_path: data/monitor.db
```

---

## Implementation Plan

### Phase 1: Core Collector (Foundation)
**Goal**: Collect and store metrics from ADB

**Tasks**:
- [ ] Create project structure
- [ ] `collector/adb_client.py` - ADB connection, device detection, safe query wrapper
- [ ] `collector/metrics.py` - Parse dumpsys output into Python dicts
- [ ] `database/models.py` - SQLAlchemy schema (Metric, AppStat, Alert)
- [ ] `database/db.py` - Database connection, session management
- [ ] `collector/collector.py` - Main async collection loop
- [ ] CLI test runner: `python -m collector.collector`
- [ ] Verify: Data appears in monitor.db

### Phase 2: Web API & Real-time Updates
**Goal**: Expose metrics via HTTP and WebSocket

**Tasks**:
- [ ] FastAPI setup with CORS
- [ ] `api/routes.py` - Endpoints: /metrics, /apps, /alerts, /config
- [ ] `api/websocket.py` - WebSocket for pushing updates
- [ ] Database query functions (get_latest, get_history)
- [ ] Verify: curl http://localhost:8000/api/metrics

### Phase 3: Frontend Dashboard
**Goal**: Visual dashboard with charts and controls

**Tasks**:
- [ ] React app with Vite
- [ ] Metric toggle components
- [ ] Chart.js integration (line, bar, gauge)
- [ ] App ranking table with sorting
- [ ] Alert log panel with filters
- [ ] Refresh rate slider (1-60s)
- [ ] WebSocket connection for real-time updates
- [ ] Verify: Dashboard shows live metrics

### Phase 4: Integration & Polish
**Goal**: Production-ready application

**Tasks**:
- [ ] Config file editing (YAML)
- [ ] Log rotation for alerts.log
- [ ] Error handling & reconnection logic
- [ ] README with setup instructions
- [ ] run.py - Entry point that starts collector + API
- [ ] Add startup script for auto-launch

### Phase 5: Optional Enhancements
**Tasks**:
- [ ] Dark mode theme
- [ ] Export data to CSV
- [ ] Per-app detailed modal view
- [ ] Historical trend comparison
- [ ] Packaged executable (PyInstaller)

### Verification Checklist

- [ ] Run `python run.py` → Collector + API start
- [ ] Open `http://localhost:8000` → Dashboard renders
- [ ] Change refresh slider → Data updates at new rate
- [ ] Toggle metrics off/on → Charts show/hide
- [ ] Trigger alert (high CPU app) → Red badge + log entry
- [ ] Disconnect device → "Waiting for device..." banner
- [ ] Reconnect device → Auto-resume collection
- [ ] Check alerts.log → Alert entries present
- [ ] Check monitor.db → Historical data present

---

## Appendix

### ADB Command Reference

```bash
# Device connection
adb devices -l                          # List connected devices
adb -s DEVICE_ID shell <command>       # Run on specific device

# Metrics collection
dumpsys usagestats --checkin           # App usage, FS time, launches
dumpsys batterystats                   # Battery usage by app
dumpsys power                          # Wake locks, suspend state
dumpsys battery                        # Current battery state
dumpsys appops <package>               # App permissions status
top -n 1                               # CPU/memory snapshot
cat /proc/net/dev                      # Network interface stats

# Background permissions
appops set <package> RUN_IN_BACKGROUND ignore
appops get <package> RUN_IN_BACKGROUND
```

### Dependencies

```txt
# requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
websockets==12.0
sqlalchemy==2.0.23
aiosqlite==0.19.0
pyyaml==6.0.1
```

---

*End of Design Document*
