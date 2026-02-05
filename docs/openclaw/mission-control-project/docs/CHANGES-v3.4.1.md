# Mission Control v3.4.1 - Changes & Improvements

## Overview

v3.4.1 adds **Documentation Tab** and **Project Filtering** to Mission Control UI, addressing gaps identified in the dashboard screenshot review.

**Based on:** v3.4.0 (Orchestrator-Complete Edition)

---

## Key Changes

### 1. Documentation Tab (NEW)

**Problem in v3.4:** Dashboard UI only showed Kanban board. No way to view or edit project documentation within the interface.

**Solution in v3.4.1:**
- **Section 8.6:** Complete Documentation Tab component specification
- **File tree sidebar** showing all project documents:
  - `KANBAN.md` (read-only, mirrored from DB)
  - `CHRONICLE.md` (editable)
  - `.context/*` files (editable)
  - Agent `SOUL.md` and `learned.md` files (editable)
- **Markdown editor** with split view (edit + preview)
- **Read/Write capabilities table** clarifying which files are editable

**RPC Methods Added:**
- `mission.document.list` - List all docs in project
- `mission.document.get` - Read document content
- `mission.document.update` - Write document content (with locking)

**Component Interface:**
```typescript
interface DocumentsTabProps {
  projectId: string;
  document: string;
  onDocumentChange: (doc: string) => void;
}
```

**Document Tree Structure:**
```
Documents
├── KANBAN.md (read-only, mirrored state)
├── CHRONICLE.md (editable)
├── .context/
│   ├── style-guide.md
│   ├── tech-stack.md
│   └── rules.md
└── Agents
    ├── Sophie-FE
    │   ├── SOUL.md
    │   └── learned.md
    ├── Elena-DBA
    │   ├── SOUL.md
    │   └── learned.md
    └── ...
```

**Impact:** Users can now view and edit all project documentation directly from Mission Control UI without switching to external editor.

---

### 2. Project Filtering: "All Projects" Mode (NEW)

**Problem in v3.4:** Project switcher only allowed selecting one project at a time. No way to see tasks across all projects.

**Solution in v3.4.1:**
- **Section 8.5:** Project Switcher with "All Projects" option
- **Two view modes:**
  - **All Projects:** Shows tasks from all projects (flat or grouped by project)
  - **Single Project:** Filters tasks to selected project only

**Component Interface:**
```typescript
interface ProjectSwitcherProps {
  currentProject: string | null;  // null = "All Projects"
  projects: Project[];
  onProjectChange: (projectId: string | null) => void;
}
```

**Dropdown Structure:**
```
Dropdown options:
├── All Projects (default)
│   └── Shows all tasks (optionally grouped by project)
└── {Project Name}
    ├── Vanguard
    ├── Vidsnap
    └── Doctoid
```

**RPC Calls:**

**All Projects:**
```typescript
const allTasks = await rpcCall<Task[]>('mission.task.list', {});
```

**Single Project:**
```typescript
const projectTasks = await rpcCall<Task[]>('mission.task.list', {
  project_id: 'vanguard'
});
```

**Impact:** Users can now see all tasks across projects (useful for portfolio view) or drill down into specific project.

---

### 3. Document RPC Handlers (NEW)

**Problem in v3.4:** No backend handlers for reading/writing project documentation files.

**Solution in v3.4.1:**
- **Section 4.5:** Complete document handler implementation
- **Three handlers:**
  - `handlerDocumentList` - Scan project directory, return file tree
  - `handlerDocumentGet` - Read file content with path security
  - `handlerDocumentUpdate` - Write file content with atomic writes + locking

**Path Security:**
```typescript
function resolveDocumentPath(projectId: string, docPath: string): string {
  const basePath = path.resolve('~/.openclaw/projects', projectId);
  const fullPath = path.resolve(basePath, docPath);

  // Security: Ensure path doesn't escape project directory
  if (!fullPath.startsWith(basePath)) {
    throw new Error('Path traversal attempt detected');
  }

  return fullPath;
}
```

**File Locking:**
```typescript
const lock = await acquireLock(docPath);

try {
  // Atomic write (temp file + rename)
  const tempPath = `${fullPath}.tmp`;
  await fs.writeFile(tempPath, content, 'utf-8');
  await fs.rename(tempPath, fullPath);

  // Broadcast update
  broadcastEvent({
    type: 'DOCUMENT_UPDATED',
    data: { project_id, path: docPath, updated_at: new Date() }
  });
} finally {
  await releaseLock(lock);
}
```

**Impact:** Safe read/write access to project docs with proper locking and security.

---

### 4. Tab Navigation (NEW)

**Problem in v3.4:** No way to switch between Kanban board and other views.

**Solution in v3.4.1:**
- **Section 8.7:** Tab Navigation component
- **Two tabs:**
  - `[Kanban]` - Main task board
  - `[Documents]` - Project documentation viewer/editor

**Component:**
```typescript
interface TabNavigationProps {
  activeTab: 'kanban' | 'documents';
  onTabChange: (tab: 'kanban' | 'documents') => void;
}
```

**UI:**
```
┌─────────────────────────────────────────────┐
│  Project: [Vanguard ▼]  |  [Kanban] [Documents]  │
├─────────────────────────────────────────────┤
│                                         │
│  (Active tab content)                    │
│                                         │
└─────────────────────────────────────────────┘
```

**Impact:** Clean separation of concerns between task management and documentation.

---

### 5. Complete UI Layout (UPDATED)

**Problem in v3.4:** Frontend structure incomplete.

**Solution in v3.4.1:**
- **Section 8.8:** Complete UI layout specification
- **Visual ASCII diagram** showing full dashboard layout

**Layout:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Mission Control                                            │
├─────────────────────────────────────────────────────────────────┤
│  Project: [Vanguard ▼]  |  [Kanban] [Documents]       │
├──────────────────────┬────────────────────────────────────────┤
│                      │                                    │
│  [Active Tab]        │  Agent Status Grid                  │
│                      │  ┌──────────────────────┐          │
│  ┌────────────────┐  │  │ Sophie-FE           │          │
│  │                │  │  │ Task: Kanban Board  │          │
│  │  Kanban or     │  │  │ Status: Working      │          │
│  │  Documents     │  │  └──────────────────────┘          │
│  │                │  │  ┌──────────────────────┐          │
│  │                │  │  │ Elena-DBA           │          │
│  │                │  │  │ Task: API Endpoints  │          │
│  │                │  │  │ Status: Idle         │          │
│  │                │  │  └──────────────────────┘          │
│  │                │  │  ... (more agents)    │          │
│  └────────────────┘  │                                    │
│                      │                                    │
└──────────────────────┴────────────────────────────────────────┘
```

**Impact:** Clear visual reference for frontend implementation.

---

### 6. WebSocket Events (UPDATED)

**Problem in v3.4:** No event for document updates.

**Solution in v3.4.1:**
- Added `DOCUMENT_UPDATED` event type
- Broadcasts when `mission.document.update` is called

**Event:**
```typescript
type MissionEvent =
  | { type: 'DOCUMENT_UPDATED'; data: { project_id: string; path: string; updated_at: Date } }
  // ... existing events
```

**Broadcast Trigger:**
MC_Service broadcasts `DOCUMENT_UPDATED` to all connected WebSocket clients when a document is updated via UI.

**Impact:** Real-time collaboration on documents. Multiple users see updates immediately.

---

### 7. Updated Project Structure (UPDATED)

**Problem in v3.4:** Component list incomplete.

**Solution in v3.4.1:**
- Added new components to project structure:
  - `DocumentsTab.tsx`
  - `TabNavigation.tsx`

**Updated Structure:**
```
mission-control-ui/
├── src/
│   ├── components/
│   │   ├── KanbanBoard.tsx
│   │   ├── TaskCard.tsx
│   │   ├── ThoughtStream.tsx
│   │   ├── AgentStatusGrid.tsx
│   │   ├── ProjectSwitcher.tsx
│   │   ├── DocumentsTab.tsx     ← NEW
│   │   └── TabNavigation.tsx    ← NEW
│   ├── hooks/
│   ├── types/
│   └── ...
```

**Impact:** Frontend developer knows exactly which components to build.

---

### 8. Implementation Phases (UPDATED)

**Problem in v3.4:** Phase 5 (Frontend) didn't include new features.

**Solution in v3.4.1:**
- Updated Phase 5 with new tasks:
  - Implement Documents Tab component with file tree sidebar
  - Implement markdown editor (read-only for KANBAN.md, editable for others)
  - Implement "All Projects" mode in ProjectSwitcher
  - Add TabNavigation component (Kanban | Documents)
- Updated Phase 7 with new tests:
  - Test document read/write via UI
  - Verify document updates broadcast via WebSocket

**Impact:** Implementation plan reflects new requirements.

---

## Changes Summary

### New Features (v3.4.1)
| Feature | Section | Description |
|----------|----------|-------------|
| **Documentation Tab** | 8.6 | View and edit project docs in UI |
| **Project Filtering** | 8.5 | "All Projects" + single project modes |
| **Document RPC** | 4.5 | `mission.document.*` handlers |
| **Tab Navigation** | 8.7 | Switch between Kanban and Documents |
| **UI Layout** | 8.8 | Complete dashboard layout spec |
| **Document Events** | 4.3 | `DOCUMENT_UPDATED` WebSocket event |

### Updated Sections (v3.4.1)
| Section | Changes |
|---------|----------|
| **8.1** | Added DocumentsTab.tsx and TabNavigation.tsx to project structure |
| **8.5** | NEW: Project Switcher with "All Projects" mode |
| **8.6** | NEW: Documentation Tab spec |
| **8.7** | NEW: Tab Navigation component |
| **8.8** | NEW: Complete UI layout diagram |
| **4.3** | Added `DOCUMENT_UPDATED` event |
| **4.5** | NEW: Document handlers (list/get/update) |
| **10** | Updated Phase 5 and Phase 7 |
| **11** | Added 3 new rows to Key Changes table |

---

## Architecture Impact

### v3.4.0 Architecture
```
Human → UI → MC_Service → DB
  ↓                 ↑
Nestor (AI) ←→ WebSocket broadcasts
  ↓
sessions_send → Specialist Agents → Native Tools
```

### v3.4.1 Architecture (No Change)
```
Human → UI → MC_Service → DB
            │         │
            │         ├─→ mission.document.* (NEW)
            │         │
Nestor (AI) ←─┴─ WebSocket broadcasts
  ↓
sessions_send → Specialist Agents → Native Tools
```

**Note:** No architectural changes. v3.4.1 only adds frontend components and backend handlers. Nestor orchestration unchanged.

---

## Implementation Impact

### For Frontend Developers (Sophie-FE)
**New Work:**
1. Build `DocumentsTab.tsx` with file tree sidebar
2. Build `TabNavigation.tsx` component
3. Update `ProjectSwitcher.tsx` to support "All Projects" (null project_id)
4. Integrate markdown editor (e.g., `react-markdown-editor-lite`)
5. Handle `DOCUMENT_UPDATED` WebSocket event

**No Breaking Changes:**
- WebSocket API unchanged (new event added, not modified)
- Existing RPC methods unchanged

### For Backend Developers (Elena-DBA)
**New Work:**
1. Implement `mission.document.list` handler
2. Implement `mission.document.get` handler
3. Implement `mission.document.update` handler (with locking)
4. Add `DOCUMENT_UPDATED` to WebSocket broadcast list

**No Breaking Changes:**
- Existing RPC methods unchanged
- Database schema unchanged
- WebSocket protocol compatible (adds new event)

### For QA (David-QA)
**New Tests:**
1. Test document listing (`mission.document.list`)
2. Test document reading (`mission.document.get`)
3. Test document writing (`mission.document.update`)
4. Test file locking (concurrent writes)
5. Test path security (traversal attempts)
6. Test WebSocket `DOCUMENT_UPDATED` event
7. Test "All Projects" filtering

---

## Migration from v3.4.0 to v3.4.1

If you've started implementing v3.4.0:

### For Backend:
✅ **No changes needed** - Database schema compatible
📝 **Add handlers:**
- `handlerDocumentList`
- `handlerDocumentGet`
- `handlerDocumentUpdate`
📡 **Update WebSocket:**
- Add `DOCUMENT_UPDATED` to event types
- Broadcast on `mission.document.update`

### For Frontend:
✅ **No changes needed** - Existing components unchanged
📝 **Add new components:**
- `DocumentsTab.tsx`
- `TabNavigation.tsx`
📝 **Update existing:**
- `ProjectSwitcher.tsx` (support null for "All Projects")
- `App.tsx` (add tab navigation)
📡 **Handle new event:**
- `DOCUMENT_UPDATED` in WebSocket client

---

## Summary

### What v3.4.1 Adds:
1. 📄 **Documentation Tab** - View/edit project docs in UI
2. 🔍 **Project Filtering** - "All Projects" + single project modes
3. 📝 **Document Handlers** - Backend RPC methods for docs
4. 🎯 **Tab Navigation** - Switch between Kanban and Documents
5. 🎨 **UI Layout** - Complete dashboard spec
6. 📡 **Document Events** - Real-time document updates

### What Stays the Same:
1. ✅ Nestor orchestrator (unchanged)
2. ✅ Agent coordination (unchanged)
3. ✅ Database schema (unchanged)
4. ✅ WebSocket protocol (compatible, adds new event)
5. ✅ Existing RPC methods (unchanged)
6. ✅ Task management (unchanged)

---

## Recommendation

**Safe upgrade.** v3.4.1 is additive only. No breaking changes.

**If implementing v3.4.0:**
- Continue with current work
- Add new components and handlers when ready
- No migration needed

**If starting fresh:**
- Use v3.4.1 directly
- All features available from day one

---

**Version:** v3.4.1
**Date:** 2026-02-02
**Status:** Implementation Ready
