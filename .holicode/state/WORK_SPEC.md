# Work Specification: Epic Integration Proxy

**Status:** draft
**Created:** 2026-03-08
**Last Updated:** 2026-03-08
**Total Context Size:** <2KB (optimized for AI context loading)

## Issue Tracker
**This file is a LOCAL CACHE of issue tracker state.**
- The configured issue tracker is the single source of truth for task management
- Run `issue-sync` skill to refresh this cache from the configured tracker in `.holicode/state/techContext.md`
- All task creation, updates, and tracking happens in the tracker
- If `issue_tracker: local`, this file plus `.holicode/specs/**` become the local source of truth and sync is typically a consistency/noop pass
- Local specs in `.holicode/specs/` are for technical details only

## Project Overview
Secure integration proxy between Epic hospital system and custom application.

## Features (Epics)
<!-- Issue tracker epics linked here by issue-sync skill -->

## Active Stories
<!-- Issue tracker stories linked here by issue-sync skill -->

## Current Tasks
<!-- Issue tracker tasks linked here by issue-sync skill -->

## Completed
<!-- Completed issues linked here by issue-sync skill -->

## Technical Design Documents
<!-- TD tracker summaries and local TD paths linked here by issue-sync skill -->

## Implementation Status
### Completed Components
<!-- none -->

### In Progress Components
- State initialization and project framing

### Planned Components
- Proxy API gateway layer
- Request/response mapping layer
- Epic adapter layer
- Observability and audit subsystem

## Hierarchy Map
```
├── Epic (Business Value)
│   ├── Story (User Requirements)
│   │   └── Task (Implementation Work)
│   │       └── Component SPECs (Live Implementation Specs)
└── TD Summary Issue (Technical Design)
    └── Local TD File (Detailed Design)
```

## Context Optimization Notes
- **Tracker First**: All tasks are primarily managed in the configured issue tracker
- **Local Cache**: This file is a reference cache updated by tracker sync workflows
- **Component SPECs**: Technical contracts remain co-located with code in `src/**/SPEC.md`
- **ID References**: Use native tracker IDs (for example `GIF-15`)

## Validation Status
- [ ] All chunks validate against .holicode/specs/SCHEMA.md
- [ ] Hierarchical links resolve correctly
- [ ] No orphaned specifications
- [ ] Component SPECs exist for all referenced components

---
*This manifest is a LOCAL CACHE maintained by HoliCode workflows.*
*The configured issue tracker is the PRIMARY source of truth.*
