# Tracker Mapping

## Active Provider
- **issue_tracker**: vibe_kanban
- **Source of truth**: Issue tracker (Vibe Kanban)
- **Local cache**: `.holicode/state/WORK_SPEC.md`

## ID Conventions
- Epic: `GIF-<n>` with `epic` tag
- Story: `GIF-<n>` with `story` tag
- Task: `GIF-<n>` with `task` tag
- Technical Design summary: `GIF-<n>` with `technical-design` tag

## Linking Rules
- Story should reference parent Epic
- Task should reference parent Story
- WORK_SPEC is synchronized from tracker state via `issue-sync`

## Notes
- Final project/org IDs will be filled after tracker bootstrap verification.
