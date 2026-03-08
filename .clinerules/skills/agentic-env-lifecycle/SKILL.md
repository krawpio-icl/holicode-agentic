---
name: agentic-env-lifecycle
description: Workspace session lifecycle for Coder+Vibe Kanban cloud environments. Guides agents through push → PR → merge → new workspace handoff.
compatibility: Designed for Claude Code, Codex, OpenCode, and Gemini skills format.
metadata:
  owner: holicode
  scope: workspace-lifecycle-orchestration
---

# Agentic Environment Lifecycle

This skill documents and guides the workspace session lifecycle in a Coder + Vibe Kanban cloud development environment. It is **optional** — only relevant when the runtime environment provides Coder workspaces and Vibe Kanban MCP tools.

> **Abstraction boundary**: The **abstract conventions** this skill enforces (feature branch lifecycle, session end protocol, PR discipline, review output contract) are defined in `holicode.md § Agentic Git Workflow Conventions` and apply regardless of provider. This skill is the **Coder + Vibe Kanban implementation** of those conventions. Other environments (GitHub Codespaces, Gitpod, local worktrees, etc.) need equivalent lifecycle skills that enforce the same abstract rules with their own tooling.

## When This Skill Applies

- You are running inside a Coder workspace (check: `/tmp/coder-agent` exists or `CODER_AGENT_TOKEN` is set)
- Vibe Kanban MCP tools are available (`mcp__vibe_kanban__*`)
- The project uses git with a remote GitHub repository

## Workspace Session Lifecycle

A workspace session follows this dependency chain. Each step requires the previous one to complete.

```
1. commit (local)
   → 2. push (requires remote access)
      → 3. PR create (requires gh auth)
         → 4. PR review (human gate)
            → 4.5 code review (optional, cross-agent via code-review skill)
               → 5. PR merge (human or auto-merge)
                  → 6. new workspace (requires merged base branch)
```

### Feature Branch Lifecycle

For multi-task epics/stories, task branches merge into a feature branch, which then merges into main:

```
main ─────────────────────────────────────────── merge commit ←─┐
  └── feature/<slug> ── squash ←─ task-1 PR                    │
                      ── squash ←─ task-2 PR                    │
                      ── squash ←─ task-3 PR ── roll-up PR ─────┘
```

- Task PRs target `feature/<slug>` (squash merge)
- A single roll-up PR merges `feature/<slug>` into `main` (merge commit)

### Step 1: Commit

Use the `git-commit-manager` workflow or commit directly with conventional format.

```bash
git add <specific-files>
git commit -m "type(scope): description"
```

### Step 2: Push

Push the workspace branch to the remote.

```bash
git push -u origin <branch-name>
```

**Pre-flight**: Verify the branch has a remote tracking branch. Branch naming is provider-specific — Vibe Kanban uses `vk/<workspace-short-id>-<slug>`; other providers use their own conventions (e.g., `feat/TASK-id` for manual worktrees).

### Step 3: PR Create

**Prerequisite**: `gh` CLI must be authenticated. Check with `gh auth status`.

If `gh` is not authenticated:
- Try: `coder external-auth access-token github | gh auth login --with-token` (if Coder external auth is configured)
- Or: set `GITHUB_TOKEN` env var from a workspace secret
- Or: flag to the user that PR must be created manually

**Determine PR target branch:**
- If a **feature branch** is active for the parent epic/story (e.g., `feature/<slug>`), the PR MUST target the feature branch — not `main`.
- If no feature branch exists (standalone task), the PR targets the default integration branch (usually `main`).
- Never target another task's workspace branch directly.

**PR title format**: `type(scope): HOL-XX description` — the tracker issue ID MUST appear in the title.

When `gh` is available:
```bash
gh pr create --base <target-branch> --title "type(scope): HOL-XX description" --body "<description>"
```

Use the `github-pr-create` workflow for template-based PR creation.

**Manual fallback**: If gh is not available, output the PR creation URL:
```
https://github.com/<org>/<repo>/pull/new/<branch-name>
```

### Step 4: PR Review (Human Gate)

This step is human-controlled. The agent should:
1. Note that PR review is needed before proceeding
2. Optionally check PR status: `gh pr view --json state,reviews,statusCheckRollup`
3. Wait for user instruction before proceeding

### Step 4.5: Cross-Agent Code Review (Optional)

Before merging, optionally dispatch an independent code review to a different AI executor using the `code-review` skill. This adds a structured second opinion from a fresh context.

**When to trigger:**
- High-priority or high-risk changes (security, data integrity, public API)
- Complex multi-file diffs where a fresh perspective adds confidence
- User explicitly requests cross-agent review
- New patterns or architectural decisions that benefit from validation

**When to skip:**
- Trivial changes (config, docs, single-line fixes)
- CI already covers the primary concerns (lint, type-check, tests pass)
- Human reviewer has already approved

**How to dispatch:**
Use the `code-review` skill, which handles executor selection, context bootstrapping, and the findings-only output contract. Review findings are posted as a PR comment or returned directly from the review workspace.

**After review completes:**
- Triage findings by severity (Critical/High must be addressed before merge)
- Implement fixes in the original workspace (not the reviewer session)
- Proceed to Step 5 when all Critical/High findings are resolved

### Step 5: PR Merge

Typically human-initiated. If the agent has permission, use the merge strategy matching the PR type (see `holicode.md § PR Discipline`):

- **Task PR → feature branch**: squash merge (collapses task commits into one)
  ```bash
  gh pr merge --squash --delete-branch
  ```
- **Feature branch roll-up PR → main**: merge commit (preserves task history)
  ```bash
  gh pr merge --merge --delete-branch
  ```

### Step 6: New Workspace

After the PR is merged into the base branch, a new workspace can be started for the next issue.

> **Vibe Kanban implementation** (other providers use equivalent dispatch):

```
mcp__vibe_kanban__start_workspace_session(
  title: "<issue title>",
  executor: "CLAUDE_CODE",  # or OPENCODE, GEMINI, etc.
  repos: [{repo_id: "<repo-id>", base_branch: "<merged-base-branch>"}],
  issue_id: "<next-issue-id>"
)
```

**Important**: The new workspace branches from the base branch. If the base branch does not include the merged changes yet, the new workspace will be missing them. Always verify the merge is complete before starting a new workspace.

## Session End Protocol

These steps implement the abstract session-end rules from `holicode.md § PR Discipline`. Before ending a workspace session, the agent MUST:

1. **Commit**: Ensure all changes are committed (no dirty working tree)
2. **Push**: Push the branch to remote
3. **PR create (mandatory)**: Create a PR before ending the session. This is not optional — do not leave work on an unpushed or un-PR'd branch.
   - Target the feature branch if one is active; otherwise target `main`
   - Use title format: `type(scope): ISSUE-ID description`
   - If `gh` is unavailable, output the manual PR URL and flag it clearly
4. **Issue status**: Set the linked issue to **"In review"** — NOT "Done". The issue is "In review" because a PR exists and awaits human code review. Done requires PR merge + QA validation. (Vibe Kanban: via MCP update; other trackers: via their respective APIs)
5. **Summary**: Summarize what was done, what remains, and include the PR URL

## Review Session Output Contract

When an agent session is performing **code review** (not implementation):

- Output is **findings-only**: comments, observations, requested changes
- The review agent MUST NOT apply inline fixes to the code
- Fixes are handled in a **separate follow-up workspace** dispatched after the review
- The review output should be structured as actionable findings that can be converted to sub-tasks

### Post-Merge Status Transition

After a PR is merged (typically by a human), the linked issue should move from "In review" to **"QA"** (not directly to "Done"). QA means the code is merged but awaits validation — deploy check, E2E test, or acceptance review. "Done" requires explicit QA sign-off.

This can happen in two ways:

- **Human-initiated**: The reviewer merges the PR and advances the tracker issue to "QA", then to "Done" after validation
- **Agent-detected**: On the next `task-init` session start, the agent detects issues stuck in "In review" whose PRs have been merged, and recommends advancing to QA or Done

See `holicode.md` → "Issue Lifecycle & Status Flow" for the full abstract process and tracker-specific mapping notes.

**Important**: Agents MUST NOT mark an issue "Done" at session end. The correct terminal state for an agent session is "In review" with a PR open.

## Dependencies and Gaps

> Capabilities marked **(VK)** are Vibe Kanban / Coder specific. Other providers need equivalents.

| Capability | Status | Notes |
|-----------|--------|-------|
| Git commit | Available | Via git or git-commit-manager workflow (provider-agnostic) |
| Git push | Available | Standard git, credentials via Coder GIT_ASKPASS **(VK)** |
| gh CLI auth | Gap | Coder external auth doesn't auto-configure gh CLI **(VK)** |
| PR create | Partial | Works when gh is authenticated; manual fallback needed (provider-agnostic) |
| PR merge | Human gate | Agent should not auto-merge without explicit permission (provider-agnostic) |
| New workspace | Available | Via `mcp__vibe_kanban__start_workspace_session` **(VK)** |

## Scope Boundaries

- This skill handles workspace lifecycle orchestration only
- Issue tracking operations are handled by `issue-tracker` skill
- Code implementation is handled by `task-implement` workflow
- This skill does NOT modify holicode core — it is an optional extension
