# Coder Workspace Template — SPEC

**Template name**: `holicode-agentic`
**Location**: `scripts/infra/coder-template/main.tf`
**Provider**: Docker (kreuzwerker/docker)
**Architecture**: Multi-container sidecar pattern

---

## What's in the Template

### Containers

| Container | Image | Purpose | Ports |
|-----------|-------|---------|-------|
| `workspace` (primary) | `ghcr.io/holagence/holicode-cde:<tag>` | Dev environment with coder_agent | 3000 (VK), 3001 (Forgejo proxy), 4096 (OpenCode) |
| `forgejo` (sidecar) | `codeberg.org/forgejo/forgejo:9` | Git web UI for branch/commit browsing | 3001 (internal) |

### Volumes

| Volume | Mount | Container | Mode | Survives rebuild? |
|--------|-------|-----------|------|-------------------|
| `home` | `/home/coder` | workspace (rw) | Persistent (no `count`) | Yes |
| `home` | `/home/coder` | forgejo (rw) | Shared with workspace | Yes |
| `forgejo_data` | `/data` | forgejo (rw) | Persistent (`ignore_changes`) | Yes |

### Network

| Network | Purpose |
|---------|---------|
| `workspace` | Inter-container communication (workspace ↔ forgejo) |
| `dokploy-network` | External access via Traefik proxy |

### Parameters (user-configurable)

| Parameter | Type | Default | Mutable | Notes |
|-----------|------|---------|---------|-------|
| `project_repo` | string | `""` | Yes | GitHub repo URL to clone |
| `cpu_cores` | number | `2` | Yes | 1-8 (not enforced — template does not set CPU limits) |
| `memory_gb` | number | `4` | Yes | 2-16 (enforced via `docker_container.memory`) |
| `jetbrains_enabled` | bool | `true` | Yes | Toggle JetBrains Gateway |

---

## Startup Scripts (`coder_script`)

Executed by the coder_agent inside the primary container. **Ordering is not guaranteed** — scripts with `start_blocks_login = false` may run concurrently. Use wait loops for dependencies (e.g., `vibe_kanban` waits for clone via timeout loop).

| Script | Blocks login? | Purpose |
|--------|--------------|---------|
| `clone_repo` | Yes | Clones `$PROJECT_REPO` via SSH (TOFU) |
| `vibe_kanban` | No | Waits for clone (timeout loop), starts VK on port 3000 |
| `opencode` | No | Starts OpenCode on port 4096 |
| `forgejo_init` | No | Waits for Forgejo ready, starts socat proxy, bootstraps admin user, creates bare mirrors, adopts repos, starts 60s sync loop |

---

## Forgejo Sidecar

### Architecture

Forgejo is a **viewer-only** Git UI. It indexes bare mirrors of workspace repos and presents branches, commits, diffs, and file history in a web interface. It does NOT manage repos — it only reads them.

```
workspace container                       forgejo container
┌──────────────────────────┐             ┌──────────────────┐
│ /home/coder/             │             │ /data/            │
│   holicode/  ──git clone──→            │  (SQLite, config) │
│   project/   bare --shared             │                   │
│                          │             │ /home/coder/ (rw) │
│ .forgejo-mirrors/coder/  │  ← shared → │  (REPO_ROOT)      │
│   holicode.git ──────────hardlinks────→│  repo browsing    │
│   project.git            │             │                   │
│                          │             │ :3001 (web UI)    │
│ socat :3001 ─────────────TCP──────────→│                   │
└──────────────────────────┘             └──────────────────┘
```

### Configuration

Viewer mode — no SSH, no registration, no repo creation, SQLite backend:

```
USER_UID=1001, USER_GID=1001
FORGEJO__server__HTTP_PORT=3001
FORGEJO__server__SSH_DISABLE=true
FORGEJO__repository__MAX_CREATION_LIMIT=0
FORGEJO__repository__ROOT=/home/coder/.forgejo-mirrors
FORGEJO__service__DISABLE_REGISTRATION=true
FORGEJO__database__DB_TYPE=sqlite3
FORGEJO__admin__DISABLE_REGULAR_ORG_CREATION=true
```

### Admin Credentials

- **User**: Coder workspace owner username (e.g. `ciekawy`)
- **Password**: `coder-forgejo-local`
- **Email**: `<owner>@workspace.local`

Created automatically on first container start via `GITEA_ADMIN_USERNAME/PASSWORD` env vars.

Login is **not required** to browse repos — `REQUIRE_SIGNIN_VIEW=false` makes all repos publicly visible to anyone who can reach the Forgejo URL. Since the URL is Coder-auth-protected (subdomain mode), this is safe. Login is only needed for admin operations.

### Mirror Sync

- **Initial**: `git clone --bare --shared --no-tags` (hardlinks, no tags — avoids Forgejo adoption timeout on repos with 1000s of tags)
- **Post-adoption**: `git fetch --tags` (tags fetched after adoption completes)
- **Periodic**: `git fetch --all --prune` every 60s (local, <100ms)
- **Scope**: All repos in `/home/coder/*/` with a `.git` directory — auto-discovered, no hardcoded list

### What's Visible

- All branches, commits, diffs, blame, file browser, branch comparison
- NOT visible: uncommitted working-tree changes (expected — committed work only)

### Socat Proxy

`coder_app` requires `localhost` URLs. Since Forgejo is in a separate container, socat bridges `localhost:3001` → `forgejo:3001` over the shared Docker network.

---

## Web Apps (`coder_app`)

| App | Slug | URL | Subdomain | Share |
|-----|------|-----|-----------|-------|
| Vibe Kanban | `vk` | `http://localhost:3000` | Yes | owner |
| Forgejo | `forgejo` | `http://localhost:3001` | Yes | owner |
| OpenCode | `opencode` | `http://localhost:4096` | Yes | owner |

---

## Template Push

```bash
cd scripts/infra/coder-template
coder templates push holicode-agentic \
  --name "<version>" \
  --message "describe changes" \
  --directory .
```

Existing workspaces are NOT affected by template pushes. Only new or rebuilt workspaces use the updated template.

### Pre-push Validation (Always Run)

Coder's workspace-tags parser is stricter than Terraform and gives no line numbers on failure. Always test before pushing:

```bash
# Copy to temp dir (avoids version name collision) and test parse
cp main.tf /tmp/ttest/main.tf
coder templates push holicode-agentic --directory /tmp/ttest --name test-parse --yes 2>&1 \
  | grep -E 'parse|Invalid|Updated'
```

### Coder Parser Gotchas

Coder's parser rejects valid Terraform HCL in these cases:

| Pattern | Error | Fix |
|---------|-------|-----|
| `lifecycle { ignore_changes = all }` (inline) | "Invalid single-argument block definition" | Expand to multi-line block |
| `ephemeral = true` on `coder_parameter` | "Invalid expression" | Remove attribute (unsupported) |
| `$(...)` subshell in a quoted string | "Invalid expression" | Move shell logic to heredoc (`<<-EOT`) |
| `${var%pattern}` inside heredoc | "Invalid expression" | Use `$${var%%pattern}` (double `$`, double `%`) |
| `locals {}` referencing data sources | "Invalid expression" | Inline values or use env vars instead |

**Key rule**: In `<<-EOT` heredocs, `${...}` is Terraform interpolation and `%{...}` is a template directive. Shell `${var%pattern}` **must** be written as `$${var%%pattern}`.

### Error Bisection Method

When "Invalid expression" gives no line number, binary-search the file:

```bash
for lines in 100 200 300 400 500 $(wc -l < main.tf); do
  head -$lines main.tf > /tmp/ttest/main.tf
  result=$(coder templates push holicode-agentic --directory /tmp/ttest --name test --yes 2>&1 \
    | grep -oE 'Invalid|Updated')
  echo "Lines $lines: ${result:-ok}"
done
```

Find the range where it transitions from `ok` → `Invalid`, then inspect those 25-50 lines.

### Workspace Update vs Rebuild

- `coder templates push` + `coder update <workspace>` — updates template but only works if workspace is "out of date"
- If workspace is already on latest version name: use `force_rebuild` parameter (toggle it) or stop/start the workspace
- `docker_container` with `restart=no` (one-shot init containers) show as **disabled** in the Coder UI — avoid this pattern, use `coder_script` instead

---

---

## Troubleshooting

### Forgejo not accessible

1. Check socat proxy: `ps aux | grep socat` — should show `TCP-LISTEN:3001`
2. Check Forgejo container: run from Coder host `docker ps | grep forgejo`
3. Check Forgejo health: `curl -sf http://forgejo:3001/api/v1/version` from workspace terminal
4. Check logs: `cat /tmp/forgejo-proxy.log`

### Mirrors out of date

```bash
# Manual sync all mirrors
for bare in /home/coder/.forgejo-mirrors/<owner>/*.git; do
  cd "$bare" && git fetch --all --prune
done
```

### Forgejo shows no repos

1. Check bare mirrors exist: `ls /home/coder/.forgejo-mirrors/<owner>/`
2. Check adoption via API: `curl -u <owner>:coder-forgejo-local http://forgejo:3001/api/v1/repos/search`
3. Manual adopt from admin panel: `http://localhost:3001/-/admin/repos/unadopted`
4. Check init script output in Coder's startup log

### Port conflict on 3001

Ensure no other service uses port 3001 in the workspace. Check with `lsof -i :3001`.

### Permission errors on mirrors directory

If Forgejo can't read `/home/coder/.forgejo-mirrors/`:

1. Check UID inside container: `docker exec <forgejo-container> id`
2. Check ownership: `ls -la /home/coder/.forgejo-mirrors/`
3. Regular image (`forgejo:9`) is used — it reliably remaps UID via `USER_UID=1001` env var.
   The rootless image ignored `USER_UID` and ran as git/1000, causing permission denied on hooks.

### Repo adoption hangs / times out

Root cause is almost always one of:

1. **Thousands of tags** — Forgejo processes every tag during adoption. Fix: strip tags from bare mirror before adoption:
   ```bash
   git -C ~/.forgejo-mirrors/<owner>/<repo>.git tag | \
     xargs git -C ~/.forgejo-mirrors/<owner>/<repo>.git tag -d
   ```
   Then retry adoption. Tags are fetched back incrementally by the 60s sync loop.

2. **Slow auth (pbkdf2$320000)** — Default Forgejo password hash takes 3-4s per API call. Check:
   ```bash
   docker exec <forgejo> sqlite3 /data/gitea/gitea.db 'SELECT passwd_hash_algo FROM user;'
   ```
   If `pbkdf2$320000`, reset to bcrypt:
   ```bash
   docker stop <forgejo>
   docker run --rm --user 1001:1001 -v <forgejo-data>:/data codeberg.org/forgejo/forgejo:9 \
     sh -c 'sed -i "/\[security\]/a PASSWORD_HASH_ALGO = bcrypt" /data/gitea/conf/app.ini'
   docker run --rm --user 1001:1001 -v <forgejo-data>:/data codeberg.org/forgejo/forgejo:9 \
     forgejo admin user change-password --username <user> --password <pass>
   docker start <forgejo>
   ```

3. **must_change_password flag** — If API returns 403 with "You must change your password":
   ```bash
   docker exec <forgejo> sqlite3 /data/gitea/gitea.db \
     "UPDATE user SET must_change_password=0 WHERE name='<user>';"
   ```

### Socat proxy dies on workspace restart

`pgrep -f socat` gives false positives (matches grep itself). Use `lsof -i :3001` instead.
`setsid socat ... &` + `disown` ensures socat survives `coder_script` process group exit.

### Forgejo API auth is slow (>1s per call)

Default password hash is `pbkdf2$320000` — 3-4s per verification. Template sets `FORGEJO__security__PASSWORD_HASH_ALGO=bcrypt` to avoid this. If an existing workspace has slow auth, see "Repo adoption hangs" section above.

### Workspace shows all resources as disabled

Caused by a `docker_container` with `restart=no` (one-shot init pattern) exiting with non-zero code, OR by the agent token being stale during restart (transient 401). Check:
- If transient: wait 30s and refresh the Coder UI — the agent reconnects
- If persistent: check `docker logs <workspace-container>` for the actual error

### Forgejo install page loops (INSTALL_LOCK issue)

`environment-to-ini` runs on every container start and regenerates `app.ini` from env vars. If `FORGEJO__security__INSTALL_LOCK=true` is NOT set as an env var, the install page appears on every restart and `INSTALL_LOCK` never persists. Always set it via env var, not just via the install form.
