FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/coder

# Base tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git ca-certificates openssh-client sudo \
    rsync jed build-essential python3 python3-pip \
    jq socat netcat-openbsd ripgrep fd-find unzip \
    openssl dnsutils iputils-ping less lsof tini \
    pkg-config libssl-dev libclang-dev clang libsqlite3-dev zip \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS + global tools
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest pnpm@10.13.1 opencode-ai

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Workspace user
RUN useradd -m -s /bin/bash -d $HOME coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

RUN chown -R coder:coder $HOME

USER coder
WORKDIR $HOME

# Git defaults
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase true

# Claude Code — native binary installer (installs to ~/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="${PATH}:${HOME}/.local/bin"

# Vibe Kanban CLI — install from npm, pre-built tarball, or build from source
# VK_SOURCE=npm       → npm install from registry (fast, ~30s, official upstream)
# VK_SOURCE=prebuilt  → download tarball from GitHub Release (fast, ~30s)
# VK_SOURCE=source    → clone + build from source (slow, ~5-8min, always works)
ARG VK_SOURCE=npm
ARG VK_GIT_REF=v0.1.21
ARG VK_API_BASE=https://vk-remote.holagence.com
ARG VK_REPO=https://github.com/holagence/vibe-kanban.git
ARG GITHUB_REPO=holagence/holicode
# GH_TOKEN required to download release asset from private repo
ARG GH_TOKEN=

RUN set -e && \
    VK_VERSION="${VK_GIT_REF#v}" && \
    if [ "${VK_SOURCE}" = "npm" ]; then \
        echo "Installing vibe-kanban from npm registry (v${VK_VERSION})..." && \
        sudo npm install -g "vibe-kanban@${VK_VERSION}"; \
    elif [ "${VK_SOURCE}" = "prebuilt" ]; then \
        echo "Installing vibe-kanban from pre-built tarball (${VK_GIT_REF})..." && \
        GITHUB_TOKEN="${GH_TOKEN}" gh release download "vk-prebuilt-${VK_VERSION}" \
            --repo "${GITHUB_REPO}" \
            --pattern "vibe-kanban-${VK_VERSION}.tgz" \
            --dir /tmp && \
        sudo npm install -g "/tmp/vibe-kanban-${VK_VERSION}.tgz" && \
        rm "/tmp/vibe-kanban-${VK_VERSION}.tgz"; \
    else \
        echo "Building vibe-kanban from source (${VK_GIT_REF}) — slow path, no Rust cache..." && \
        \
        # Install Rust toolchain inline (only for source builds; not kept in image for prebuilt)
        sudo curl https://sh.rustup.rs -sSf | sudo sh -s -- -y --no-modify-path && \
        export PATH="/root/.cargo/bin:${PATH}" && \
        sudo /root/.cargo/bin/rustup toolchain install nightly-2025-12-04 && \
        \
        git clone --depth 1 --branch "${VK_GIT_REF}" "${VK_REPO}" /tmp/vibe-kanban && \
        cd /tmp/vibe-kanban && \
        pnpm install --frozen-lockfile && \
        \
        # 1. Build frontend with custom API base
        cd frontend && \
        NODE_OPTIONS="--max-old-space-size=8192" \
            VITE_VK_SHARED_API_BASE="${VK_API_BASE}" \
            npm run build && \
        cd .. && \
        \
        # 2. Build Rust server binary (embeds frontend/dist at compile time)
        /root/.cargo/bin/cargo build --release --bin server && \
        /root/.cargo/bin/cargo build --release --bin vibe-kanban-mcp && \
        /root/.cargo/bin/cargo build --release --bin vibe-kanban-review && \
        \
        # 3. Package assembly
        mkdir -p npx-cli/dist/linux-arm64 && \
        mkdir -p /tmp/vk-pack && \
        cp target/release/server /tmp/vk-pack/vibe-kanban && \
        cd /tmp/vk-pack && zip -j /tmp/vibe-kanban/npx-cli/dist/linux-arm64/vibe-kanban.zip vibe-kanban && \
        cp /tmp/vibe-kanban/target/release/vibe-kanban-mcp /tmp/vk-pack/ && \
        zip -j /tmp/vibe-kanban/npx-cli/dist/linux-arm64/vibe-kanban-mcp.zip vibe-kanban-mcp && \
        cp /tmp/vibe-kanban/target/release/vibe-kanban-review /tmp/vk-pack/ && \
        zip -j /tmp/vibe-kanban/npx-cli/dist/linux-arm64/vibe-kanban-review.zip vibe-kanban-review && \
        rm -rf /tmp/vk-pack && \
        \
        # 4. Pack and install
        cd /tmp/vibe-kanban/npx-cli && \
        TARBALL=$(pnpm pack) && \
        sudo npm install -g "$TARBALL" && \
        \
        # Cleanup — remove Rust toolchain to keep image lean
        cd / && \
        rm -rf /tmp/vibe-kanban /root/.cargo /root/.rustup; \
    fi && \
    # Pre-extract zips for prebuilt/source paths (npm path uses R2-downloaded binaries cached above)
    if [ "${VK_SOURCE}" != "npm" ]; then \
        VK_DIST="/usr/lib/node_modules/vibe-kanban/dist/linux-arm64" && \
        sudo unzip -o "${VK_DIST}/vibe-kanban.zip" -d "${VK_DIST}" && \
        sudo unzip -o "${VK_DIST}/vibe-kanban-mcp.zip" -d "${VK_DIST}" && \
        sudo unzip -o "${VK_DIST}/vibe-kanban-review.zip" -d "${VK_DIST}" && \
        sudo chmod +x "${VK_DIST}/vibe-kanban" "${VK_DIST}/vibe-kanban-mcp" "${VK_DIST}/vibe-kanban-review"; \
    fi && \
    echo "Vibe Kanban installed (${VK_SOURCE} mode)"

EXPOSE 3000 4096 5173

ENTRYPOINT ["tini", "-g", "--"]
