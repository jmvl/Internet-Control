# Doctoid - Technical Skills Analysis

**Research Date**: 2025-01-30

## Overview

This document outlines the technical skills required to build **Doctoid**, a real-time Android monitoring dashboard using Python FastAPI backend and React TypeScript frontend.

---

## 🔥 Core Technical Skills

### 1. Backend Development with FastAPI

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| **Async/await Python** | Critical | `asyncio`, event loops, coroutines, futures |
| **FastAPI framework** | Critical | Routing, dependency injection, Pydantic models |
| **RESTful API design** | Critical | OpenAPI/Swagger docs, HTTP methods, status codes |
| **WebSocket implementation** | Critical | Real-time bidirectional communication |
| **Server-Sent Events (SSE)** | Optional | Alternative to WebSockets for unidirectional updates |

**Resources:**
- [Building Real-Time Dashboards with FastAPI and Svelte](https://testdriven.io/blog/fastapi-svelte/)
- [FastAPI Observability with Grafana](https://grafana.com/grafana/dashboards/16110-fastapi-observability/)
- [10 FastAPI WebSocket Recipes for Real-Time Dashboards](https://medium.com/@Nexumo_/10-fastapi-websocket-recipes-for-real-time-dashboards-3f4fccbd9bcf)

### 2. Android Debug Bridge (ADB) Integration

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| **subprocess module** | Critical | `asyncio.create_subprocess_exec`, timeout handling |
| **Device connection management** | Critical | USB/Wi-Fi ADB, multi-device handling |
| **dumpsys parsing** | Critical | `usagestats`, `batterystats`, `power` output |
| **Performance monitoring** | Critical | CPU, memory, battery, network metrics |

**ADB Commands Used:**
```bash
dumpsys usagestats --checkin    # App usage, FS time, launches
dumpsys batterystats            # Battery drain by app
dumpsys power                   # Wake locks, suspend blockers
dumpsys battery                 # Current %, temp, voltage
dumpsys appops <package>        # Background permissions
top -n 1                        # CPU/memory snapshot
cat /proc/net/dev               # Network activity
```

**Resources:**
- [I built a local, live-metrics dashboard for Android](https://www.reddit.com/r/Python/comments/1kxv6cr/i_built_a_local_livemetrics_dashboard_for_android_system/)
- [Automate Android Login Workflows with ADB and Python](https://proandroiddev.com/effortless-account-switching-automate-your-android-app-login-flow-with-python-and-adb-8a5aea83924d)
- [PAPIMonitor: Python API Monitor for Android apps](https://github.com/0xdad0/PAPIMonitor)

### 3. Frontend Development with React + TypeScript

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| **React with hooks** | Critical | `useState`, `useEffect`, custom hooks |
| **TypeScript** | Critical | Type safety, interfaces, generics |
| **Chart.js integration** | Critical | Line charts, bar charts, real-time updates |
| **WebSocket client** | Critical | `WebSocket` API, reconnection logic |
| **State management** | Optional | Context API, Zustand, or Redux |

**Resources:**
- [Building a Real-Time User Analytics Dashboard with Chart.js](https://dev.to/mayankchawdhari/building-a-real-time-user-analytics-dashboard-with-chartjs-track-active-inactive-users-11j7)
- [ReactJS Development for Real-Time Analytics Dashboards](https://makersden.io/blog/reactjs-dev-for-real-time-analytics-dashboards)
- [Top 5 React Chart Libraries for 2026](https://www.syncfusion.com/blogs/post/top-5-react-chart-libraries)

### 4. Database & Data Management

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| **SQLAlchemy with async** | Critical | ORM models, async sessions, queries |
| **SQLite with WAL mode** | Critical | Write-Ahead Logging, concurrent access |
| **Time-series data patterns** | Critical | Efficient querying, aggregation, retention |
| **aiosqlite** | Critical | Async SQLite driver for Python |

### 5. DevOps & Deployment

| Skill | Importance | Key Concepts |
|-------|------------|--------------|
| **Python packaging** | Important | `requirements.txt`, virtual environments |
| **Process management** | Important | `uvicorn`, signal handling, graceful shutdown |
| **Logging** | Important | Structured logging, log rotation |

---

## 📊 Skill Breakdown by Implementation Phase

### Phase 1: Core Collector

**Required Skills:**
- Python subprocess management with `asyncio`
- ADB command execution and output parsing
- SQLAlchemy ORM models and migrations
- Database session management

**Learning Resources:**
- [Python Asyncio Subprocess](https://docs.python.org/3/library/asyncio-subprocess.html)
- [SQLAlchemy Async Tutorial](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)

### Phase 2: Web API

**Required Skills:**
- FastAPI routing and dependency injection
- WebSocket connection management
- Pydantic models for data validation
- CORS middleware configuration

**Learning Resources:**
- [FastAPI WebSocket Tutorial](https://fastapi.tiangolo.com/advanced/websockets/)
- [Real-Time Data Processing with WebSockets](https://www.pluralsight.com/courses/fastapi-real-time-data-processing-websockets)

### Phase 3: Frontend Dashboard

**Required Skills:**
- React functional components with TypeScript
- Chart.js configuration and updates
- Custom React hooks for data fetching
- WebSocket integration with reconnection

**Learning Resources:**
- [React Chart.js Tutorial](https://www.youtube.com/watch?v=qVMCZ_xhiVM)
- [Real-Time Dashboard with Chart.js](https://dev.to/mayankchawdhari/building-a-real-time-user-analytics-dashboard-with-chartjs-track-active-inactive-users-11j7)

### Phase 4: Integration & Polish

**Required Skills:**
- YAML configuration parsing
- Log rotation and file management
- Error handling and recovery patterns
- Process orchestration (collector + API server)

---

## 🎯 Recommended Skill Acquisition Order

1. **FastAPI Basics** → Build simple REST APIs
2. **Async Python** → Understand `asyncio` event loops
3. **WebSockets** → Create real-time features
4. **ADB Integration** → Execute shell commands via subprocess
5. **SQLAlchemy** → Define models and run queries
6. **React + TypeScript** → Build component-based UIs
7. **Chart.js** → Visualize data with charts
8. **Integration** → Connect all components

---

## 📚 Additional Resources

### Tutorials & Guides
- [FastAPI + Svelte Real-Time Dashboard](https://testdriven.io/blog/fastapi-svelte/)
- [FastAPI Observability with Grafana](https://grafana.com/grafana/dashboards/16110-fastapi-observability/)
- [React JS Admin Dashboard with JSON Data & Chart.js](https://www.youtube.com/watch?v=qVMCZ_xhiVM)

### Open Source Projects
- [FastAPI Radar - Debugging Dashboard](https://github.com/doganarif/fastapi-radar)
- [Real-Time Dashboard Project](https://github.com/Abdulbasit110/Dashboard)
- [PAPIMonitor - Android API Monitor](https://github.com/0xdad0/PAPIMonitor)

### Articles
- [10 Python Skills That Will Make You Unstoppable in 2025](https://python.plainenglish.io/10-python-skills-that-will-make-you-unstoppable-in-2025-be0c6ab3c76a)
- [Building Blazing-Fast Backends with FastAPI and Async](https://python.plainenglish.io/building-blazing-fast-fast-backends-with-fastapi-and-async-python-my-journey-from-flask-to-next-gen-8e821a20343c)
- [React.js Development Trends in 2025](https://medium.com/@princy.icoderz/react-js-development-trends-in-2025-what-businesses-need-to-know-before-hiring-bab7b92ee45a)

---

## 🔧 Technology Stack Summary

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Backend** | Python 3.11+, FastAPI | Async web framework |
| **Database** | SQLite + SQLAlchemy | Data persistence |
| **Async Driver** | aiosqlite | Async SQLite operations |
| **Frontend** | React + TypeScript | UI framework |
| **Charts** | Chart.js | Data visualization |
| **Real-time** | WebSocket API | Live updates |
| **Config** | PyYAML | Settings management |
| **Process** | uvicorn | ASGI server |

---

*Last Updated: 2025-01-30*
