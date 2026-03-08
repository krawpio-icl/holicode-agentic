terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# --- Parameters (user selects at workspace creation) ---

data "coder_parameter" "project_repo" {
  name         = "project_repo"
  display_name = "Project Repository"
  description  = "GitHub repo URL to clone (leave empty to skip)"
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "cpu_cores" {
  name         = "cpu_cores"
  display_name = "CPU Cores"
  type         = "number"
  default      = "2"
  mutable      = true
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory_gb" {
  name         = "memory_gb"
  display_name = "Memory (GB)"
  type         = "number"
  default      = "4"
  mutable      = true
  validation {
    min = 2
    max = 16
  }
}

data "coder_parameter" "jetbrains_enabled" {
  name         = "jetbrains_enabled"
  display_name = "Enable JetBrains Gateway"
  description  = "Show JetBrains Gateway IDE option. Disable to reduce startup overhead."
  type         = "bool"
  default      = "true"
  mutable      = true
}


data "coder_parameter" "force_rebuild" {
  name         = "force_rebuild"
  display_name = "Force Rebuild"
  description  = "Force workspace rebuild to pick up template changes. Toggle this to trigger rebuild."
  type         = "bool"
  default      = "false"
  mutable      = true
}

# --- Persistent volume (survives stop/start) ---

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-home"
}

# --- Shared workspace network (inter-container communication) ---

resource "docker_network" "workspace" {
  name        = "coder-${data.coder_workspace.me.id}-net"
  ipv6 = true
}

# --- Forgejo data volume (persistent across stop/start/rebuild) ---

resource "docker_volume" "forgejo_data" {
  name = "coder-${data.coder_workspace.me.id}-forgejo"
  lifecycle {
    ignore_changes = all
  }
}

# --- Workspace container ---

resource "docker_image" "workspace" {
  name         = "ghcr.io/holagence/holicode-cde:1.4"
  keep_locally = true
  # VK v0.1.21 via npm (VK_SOURCE=npm). Binaries download from R2 on first run.
  # VK_SHARED_API_BASE set at runtime in coder_script.vibe_kanban
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.workspace.image_id
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1", "8.8.8.8"]

  # Resource limits
  memory = data.coder_parameter.memory_gb.value * 1024

  # Coder agent bootstrap
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "PROJECT_REPO=${data.coder_parameter.project_repo.value}",
  ]

  # Entrypoint — Coder agent init script handles the rest
  entrypoint = ["sh", "-c", coder_agent.main.init_script]

  # Persistent home directory
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
  }

  # Allow reaching host services if needed
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  # Connect to Dokploy's network so Traefik can see workspace apps
  networks_advanced {
    name = "dokploy-network"
  }

  # Shared network for sidecar containers (e.g., Forgejo)
  networks_advanced {
    name    = docker_network.workspace.name
    aliases = ["workspace"]
  }
}

# --- Forgejo sidecar (Git web UI for branch/commit browsing) ---

resource "docker_image" "forgejo" {
  name         = "codeberg.org/forgejo/forgejo:9"
  keep_locally = true
}

resource "docker_container" "forgejo" {
  count   = data.coder_workspace.me.start_count
  image   = docker_image.forgejo.image_id
  name    = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}-forgejo"
  restart = "unless-stopped"

  env = [
    "USER_UID=1001",
    "USER_GID=1001",
    "FORGEJO__server__HTTP_PORT=3001",
    "FORGEJO__server__ROOT_URL=http://localhost:3001",
    "FORGEJO__server__SSH_DISABLE=true",
    "FORGEJO__repository__MAX_CREATION_LIMIT=0",
    "FORGEJO__service__DISABLE_REGISTRATION=true",
    "FORGEJO__service__REQUIRE_SIGNIN_VIEW=false",
    "FORGEJO__service__DEFAULT_ALLOW_CREATE_ORGANIZATION=false",
    "FORGEJO__database__DB_TYPE=sqlite3",
    "FORGEJO__admin__DISABLE_REGULAR_ORG_CREATION=true",
    "FORGEJO__repository__ROOT=/home/coder/.forgejo-mirrors",
    "FORGEJO__security__INSTALL_LOCK=true",
    "FORGEJO__security__SECRET_KEY=holicode-forgejo-secret",
    # bcrypt is faster than pbkdf2$320000 for API auth (local single-user instance)
    "FORGEJO__security__PASSWORD_HASH_ALGO=bcrypt",
    # Trust all directories — mirrors are owned by coder (1001) not git (1001 remapped)
    "GIT_CONFIG_COUNT=1",
    "GIT_CONFIG_KEY_0=safe.directory",
    "GIT_CONFIG_VALUE_0=*",
    # Auto-create admin on first run via entrypoint (idempotent — skipped if user exists)
    "GITEA_ADMIN_USERNAME=${data.coder_workspace_owner.me.name}",
    "GITEA_ADMIN_PASSWORD=coder-forgejo-local",
  ]

  networks_advanced {
    name    = docker_network.workspace.name
    aliases = ["forgejo", "git"]
  }

  healthcheck {
    test         = ["CMD", "curl", "-sf", "http://localhost:3001/api/v1/version"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 5
    start_period = "30s"
  }

  # Forgejo persistent data (SQLite DB, config)
  volumes {
    container_path = "/data"
    volume_name    = docker_volume.forgejo_data.name
  }

  # Shared home volume — Forgejo reads bare mirrors from .forgejo-mirrors/
  # Not read-only: Forgejo may need to write temp/lock files during indexing
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
  }

  depends_on = [docker_network.workspace]
}

# --- Coder agent (runs inside the container) ---

resource "coder_agent" "main" {
  arch = "arm64"
  os   = "linux"
  dir  = "/home/coder"

  # No startup_script here — using coder_script resources instead

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "top -bn1 | head -1 | awk '{print $NF}' | sed 's/,/ /'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = "free -h | awk '/^Mem:/ {print $3 \"/\" $2}'"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "df -h /home/coder | awk 'NR==2 {print $3 \"/\" $2}'"
    interval     = 60
    timeout      = 1
  }
}

# # See https://registry.coder.com/modules/code-server
# module "code-server" {
#   count  = data.coder_workspace.me.start_count
#   source = "registry.coder.com/modules/code-server/coder"

#   # This ensures that the latest version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
#   version = ">= 1.0.0"

#   agent_id = coder_agent.main.id
#   order    = 1
# }

# See https://registry.coder.com/modules/jetbrains-gateway
module "jetbrains_gateway" {
  count  = data.coder_parameter.jetbrains_enabled.value == "true" ? data.coder_workspace.me.start_count : 0
  source = "registry.coder.com/modules/jetbrains-gateway/coder"

  # JetBrains IDEs to make available for the user to select
  jetbrains_ides = ["IU", "PS", "WS", "PY", "CL", "GO", "RM", "RD", "RR"]
  default        = "PY"

  # Default folder to open when starting a JetBrains IDE
  folder = "/home/coder"

  # This ensures that the latest version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
  version = ">= 1.0.0"

  agent_id   = coder_agent.main.id
  agent_name = "main"
  order      = 2
}

# --- Startup scripts (separate lifecycle per service) ---

# 1. Clone repo first — other services depend on it
resource "coder_script" "clone_repo" {
  agent_id           = coder_agent.main.id
  display_name       = "Clone Repository"
  icon               = "/icon/git.svg"
  run_on_start       = true
  start_blocks_login = true # block until clone completes
  script             = <<-EOT
    #!/bin/bash
    set -e
    REPO_DIR="/home/coder/project"

    if [ -n "$PROJECT_REPO" ] && [ ! -d "$REPO_DIR/.git" ]; then
      # If previous attempt created the dir but clone failed, clean it
      if [ -d "$REPO_DIR" ] && [ ! -d "$REPO_DIR/.git" ]; then
        rm -rf "$REPO_DIR"
      fi

      SSH_DIR="/home/coder/.ssh"
      KNOWN_HOSTS="$SSH_DIR/known_hosts"

      mkdir -p "$SSH_DIR"
      chmod 700 "$SSH_DIR"
      touch "$KNOWN_HOSTS"
      chmod 600 "$KNOWN_HOSTS"

      host="$(
        printf '%s\n' "$PROJECT_REPO" |
          sed -E 's#^[a-z]+://##; s#^[^@]+@##; s#/.*$##; s#:.*$##'
      )"

      # Remove stale host key if present, then add fresh (TOFU)
      ssh-keygen -R "$host" >/dev/null 2>&1 || true
      ssh-keyscan -H "$host" >> "$KNOWN_HOSTS" 2>/dev/null

      echo "Cloning $PROJECT_REPO..."
      git clone "$PROJECT_REPO" "$REPO_DIR"
    else
      echo "Repo already cloned or no repo specified, skipping."
    fi
  EOT
}

# 2. Vibe Kanban — long-running, uses exec to replace shell cleanly
resource "coder_script" "vibe_kanban" {
  agent_id           = coder_agent.main.id
  display_name       = "Vibe Kanban"
  icon               = "/emojis/1f4cb.png"
  run_on_start       = true
  start_blocks_login = false # let user connect while VK starts
  script             = <<-EOT
    #!/bin/bash
    set -e

    # Wait for clone to finish (belt-and-suspenders; coder_script
    # ordering isn't guaranteed, start_blocks_login on clone helps
    # but this is a safety net)
    timeout=60
    while [ ! -d "/home/coder/project/.git" ] && [ "$timeout" -gt 0 ]; do
      echo "Waiting for project repo..."
      sleep 2
      timeout=$((timeout - 2))
    done

    if [ ! -d "/home/coder/project" ]; then
      echo "No project directory found, skipping vibe-kanban."
      exit 0
    fi

    # Clean up stale VK installs from persistent home volume (existing workspaces)
    # The home volume may have old npm-installed VK under ~/.local/ that shadows
    # the image's global /usr/lib/node_modules/vibe-kanban install.
    if [ -d "$HOME/.local/lib/node_modules/vibe-kanban" ]; then
      echo "Removing stale ~/.local/lib/node_modules/vibe-kanban"
      rm -rf "$HOME/.local/lib/node_modules/vibe-kanban"
    fi
    for f in "$HOME/.local/bin/vk" "$HOME/.local/bin/vibe-kanban" "$HOME/.local/bin/vibe-kanban-mcp" "$HOME/.local/bin/vibe-kanban-review"; do
      [ -e "$f" ] && echo "Removing stale $f" && rm -f "$f"
    done

    cd /home/coder/project

    VK_SHARED_API_BASE=https://vk-remote.holagence.com \
      HOST=0.0.0.0 \
      PORT=3000 \
      nohup vibe-kanban > /tmp/vibe-kanban.log 2>&1 &

    echo "Vibe Kanban started (PID $!), logs at /tmp/vibe-kanban.log"
  EOT
}

# 3. OpenCode — long-running AI coding agent
resource "coder_script" "opencode" {
  agent_id           = coder_agent.main.id
  display_name       = "OpenCode"
  icon               = "/emojis/1f916.png"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e

    nohup opencode serve --port 4096 --hostname 0.0.0.0 > /tmp/opencode.log 2>&1 &
    echo "OpenCode started (PID $!), logs at /tmp/opencode.log"
  EOT
}

# 4. Forgejo init — socat proxy, admin bootstrap, repo mirroring, sync loop
resource "coder_script" "forgejo_init" {
  agent_id           = coder_agent.main.id
  display_name       = "Forgejo Init"
  icon               = "/icon/git.svg"
  run_on_start       = true
  start_blocks_login = false
  script             = <<-EOT
    #!/bin/bash
    set -e

    FORGEJO_URL="http://forgejo:3001"
    ADMIN_USER="${data.coder_workspace_owner.me.name}"
    ADMIN_PASS="coder-forgejo-local"
    ADMIN_EMAIL="${data.coder_workspace_owner.me.name}@workspace.local"
    MIRROR_DIR="/home/coder/.forgejo-mirrors"

    # --- Wait for Forgejo API (INSTALL_LOCK=true skips install page, API up immediately) ---
    echo "Waiting for Forgejo API..."
    for i in $(seq 1 60); do
      if curl -sf "$FORGEJO_URL/api/v1/version" > /dev/null 2>&1; then
        echo "Forgejo API ready"
        break
      fi
      if [ "$i" -eq 60 ]; then
        echo "WARNING: Forgejo API not ready after 120s, skipping init"
        exit 0
      fi
      sleep 2
    done

    # --- Start socat proxy: localhost:3001 -> forgejo:3001 ---
    # Required because coder_app needs localhost URLs.
    # Use lsof to check port (pgrep matches grep itself — unreliable).
    # setsid detaches from script process group so proxy survives script exit.
    if ! lsof -i :3001 > /dev/null 2>&1; then
      setsid socat TCP-LISTEN:3001,fork,reuseaddr TCP:forgejo:3001 \
        > /tmp/forgejo-proxy.log 2>&1 &
      disown
      echo "Forgejo proxy started (PID $!)"
    else
      echo "Forgejo proxy already running on :3001"
    fi

    # --- Create admin user via API (idempotent) ---
    # INSTALL_LOCK=true skips install page. When no users exist, Forgejo
    # allows creating the first admin via API without authentication.
    AUTH_STATUS=$(curl -so /dev/null -w '%%{http_code}' \
      -u "$ADMIN_USER:$ADMIN_PASS" \
      "$FORGEJO_URL/api/v1/user" 2>/dev/null)

    if [ "$AUTH_STATUS" != "200" ]; then
      echo "Creating Forgejo admin user via API..."
      CREATE_STATUS=$(curl -so /dev/null -w '%%{http_code}' \
        -X POST "$FORGEJO_URL/api/v1/admin/users" \
        -H "Content-Type: application/json" \
        -d "{
          \"username\": \"$ADMIN_USER\",
          \"password\": \"$ADMIN_PASS\",
          \"email\": \"$ADMIN_EMAIL\",
          \"must_change_password\": false,
          \"source_id\": 0,
          \"login_name\": \"$ADMIN_USER\"
        }" 2>/dev/null)
      echo "Admin user create: HTTP $CREATE_STATUS"

      # Verify auth works
      AUTH_STATUS=$(curl -so /dev/null -w '%%{http_code}' \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        "$FORGEJO_URL/api/v1/user" 2>/dev/null)
      echo "Admin auth check: HTTP $AUTH_STATUS"
    else
      echo "Admin user already exists"
    fi

    # --- Create bare mirrors for repos ---
    # Forgejo expects repos at REPO_ROOT/<owner>/<repo>.git
    # REPO_ROOT is set to /home/coder/.forgejo-mirrors via env var
    OWNER_DIR="$MIRROR_DIR/$ADMIN_USER"
    mkdir -p "$OWNER_DIR"

    # Discover all git repos in /home/coder/ (direct children with .git dir)
    for repo_path in /home/coder/*/; do
      repo_path="$${repo_path%%/}"  # strip trailing slash ($$ escapes Terraform interpolation)
      [ -d "$repo_path/.git" ] || continue

      name=$(basename "$repo_path")
      bare="$OWNER_DIR/$${name}.git"

      if [ ! -d "$bare" ]; then
        echo "Creating bare mirror (shared objects): $name"
        # Clone without tags first — Forgejo's adoption hangs on repos with thousands of tags
        # Tags are fetched separately after adoption completes
        git clone --bare --shared --no-tags "$repo_path" "$bare" 2>/dev/null
      else
        echo "Updating mirror: $name"
        cd "$bare" && git fetch --all --prune 2>/dev/null || true
      fi

      # --- Adopt repo in Forgejo (idempotent) ---
      REPO_EXISTS=$(curl -so /dev/null -w '%%{http_code}' \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        "$FORGEJO_URL/api/v1/repos/$ADMIN_USER/$name" 2>/dev/null)

      if [ "$REPO_EXISTS" != "200" ]; then
        echo "Adopting repo in Forgejo: $name"
        ADOPT_STATUS=$(curl -so /dev/null -w '%%{http_code}' --max-time 30 \
          -X POST "$FORGEJO_URL/api/v1/admin/unadopted/$ADMIN_USER/$name" \
          -u "$ADMIN_USER:$ADMIN_PASS" 2>/dev/null)
        if [ "$ADOPT_STATUS" = "204" ]; then
          echo "Repo adopted: $name"
          # Fetch tags after adoption so they appear in Forgejo
          cd "$bare" && git fetch --tags 2>/dev/null || true
          # Make repo public (adopted repos default to private)
          curl -sf --max-time 10 -X PATCH "$FORGEJO_URL/api/v1/repos/$ADMIN_USER/$name" \
            -u "$ADMIN_USER:$ADMIN_PASS" \
            -H "Content-Type: application/json" \
            -d '{"private": false}' > /dev/null 2>&1 && echo "Repo set public: $name" || true
        else
          echo "Repo adoption HTTP $ADOPT_STATUS: $name (may need manual adopt)"
        fi
      else
        echo "Repo already adopted: $name"
      fi
    done

    # --- Background mirror sync — fetch every 60s ---
    (
      while true; do
        sleep 60
        for bare in "$OWNER_DIR"/*.git; do
          [ -d "$bare" ] && git -C "$bare" fetch --all --prune 2>/dev/null || true
        done
      done
    ) > /dev/null 2>&1 &
    disown
    echo "Mirror sync daemon started (PID $!)"
    echo "Forgejo init complete"
  EOT
}

# --- Web apps exposed through Coder ---

resource "coder_app" "vibekanban" {
  agent_id     = coder_agent.main.id
  display_name = "Vibe Kanban"
  slug         = "vk"
  url          = "http://localhost:3000"
  icon         = "/icon/kanban.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:3000"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "opencode" {
  agent_id     = coder_agent.main.id
  display_name = "OpenCode"
  slug         = "opencode"
  url          = "http://localhost:4096"
  icon         = "/icon/code.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:4096"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "forgejo" {
  agent_id     = coder_agent.main.id
  display_name = "Forgejo"
  slug         = "forgejo"
  url          = "http://localhost:3001"
  icon         = "/icon/git.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:3001"
    interval  = 5
    threshold = 10
  }
}
