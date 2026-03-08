# HoliCode Project

This project uses the **HoliCode framework** for spec-driven development with persistent AI memory.

## Framework Instructions

Read and follow: `.clinerules/holicode.md` - the comprehensive framework rules and workflow standards.

Additional tracker config:
- @.clinerules/config/issue-tracker.md

## State Management

Core state files (read on every conversation start):
- **Current context**: `.holicode/state/activeContext.md` - what we're working on now
- **Progress tracking**: `.holicode/state/progress.md` - completion status and metrics
- **Work manifest**: `.holicode/state/WORK_SPEC.md` - board snapshot and tracker issue cache
- **Project brief**: `.holicode/state/projectbrief.md` - foundation and goals
- **Product context**: `.holicode/state/productContext.md` - business context and users
- **Tech context**: `.holicode/state/techContext.md` - stack and constraints

## Workflows (Agents)

Available via `/agents` command. Key workflows in `.claude/agents/`:

| Agent | Purpose |
|-------|---------|
| `business-analyze` | Transform business briefs → productContext.md + tracker Epics |
| `functional-analyze` | Create user stories with EARS format (Given/When/Then) |
| `implementation-plan` | Generate sized tasks with acceptance criteria |
| `task-implement` | Execute tasks → working code + tests |
| `spec-workflow` | Orchestrate full lifecycle (Business → Functional → Implementation) |

## Specifications

- **Work manifest**: `.holicode/state/WORK_SPEC.md` - links to active tracker issues (also listed above as state)
- **Technical designs**: `.holicode/specs/technical-design/TD-*.md`
- **Component specs**: `src/**/SPEC.md` - co-located with code

## Core Conventions

1. **DoR/DoD Gates**: Every workflow validates Definition of Ready/Done
2. **State Update Order**: activeContext → retro-inbox → progress (always in this order)
3. **Issue Tracker First**: Configured tracker issues are source of truth for task management
4. **Specification Mode**: Planning workflows produce docs only, never code
5. **SPEC-as-Input**: Implementation requires existing SPEC.md contracts

## Git Rules

- Always `git add <specific-files>` - never `git add -A` or `git add .`
- Use conventional commits: `type(scope): subject`
- Create focused PRs aligned to task chunks
- CRITICAL: Do not mention Claude/Anthropic in commit messages

## Commands

- Tests: `npm run test -- path/to/file`
- Build: `npm run build`
- Lint: `npm run lint`

## Quick Start

1. Check `.holicode/state/activeContext.md` for current focus
2. Check `.holicode/state/progress.md` for what's done/pending
3. proactively select other .holicode state files, and leverage retro-inbox for **meta** learnings
3. Use appropriate workflow agent for the task type
4. Update state files after completing work
