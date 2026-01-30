# Doctoid Documentation

**Doctoid** is a real-time Android background usage monitoring dashboard that connects via ADB.

## Project Status
🚧 In Planning

## Documentation

| Document | Description |
|----------|-------------|
| [Design Document](design.md) | Complete architecture, database schema, API specs, implementation plan |
| [Skills Analysis](skills-analysis.md) | Technical skills required, learning resources, technology stack |
| [Agents Definition](agents.md) | Parallel implementation agents with responsibilities and contracts |

## Quick Links
- **Goal**: Monitor Android app background usage, battery drain, and suspicious activity
- **Tech Stack**: Python (FastAPI) + React + SQLite + ADB
- **Key Features**: Real-time dashboard, configurable alerts, historical data (30 days)

## Parallel Implementation

The project uses 5 specialized agents for parallel development:

1. **Collector Agent** - ADB integration, data collection, metrics parsing
2. **API & WebSocket Agent** - FastAPI backend, real-time updates
3. **Database Agent** - SQLAlchemy models, queries, retention
4. **Frontend Dashboard Agent** - React TypeScript UI, Chart.js visualization
5. **Integration Agent** - Configuration, logging, process orchestration

## Next Steps
1. Create project structure
2. Execute Phase 1 in parallel (Collector + Database + API agents)
3. Execute Phase 2 (Frontend Dashboard agent)
4. Execute Phase 3 (Integration agent)
5. Verification and testing
