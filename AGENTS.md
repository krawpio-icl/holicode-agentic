# 0ne s3 asset server (HoliCode)

## Entry Point (Mandatory)
- Follow HoliCode framework rules in `.clinerules/holicode.md`.
- If anything in this file conflicts with HoliCode, `.clinerules/holicode.md` wins.

## Project Context (Always Read First)
- `.holicode/state/activeContext.md`
- `.holicode/state/progress.md`
- `.holicode/state/WORK_SPEC.md` (work manifest linking to active tracker issues)

## How We Work Here
- HoliCode is spec-driven: plan/spec workflows produce docs; implementation happens only after specs exist.
- The configured issue tracker is the source of truth for task management; local `.holicode/` stores technical specs/state.

## OpenCode Agents (Project)
- Agents are defined in `.opencode/agents/`.
- Core HoliCode workflows (agent names match filenames):
  - `business-analyze`, `functional-analyze`, `technical-design`, `implementation-plan`, `task-implement`, `spec-backfill`, `spec-workflow`

## Git Conventions
- Always stage explicitly: `git add <specific-files>` (never `git add .` / `git add -A`).
- Conventional commits: `type(scope): subject`.
