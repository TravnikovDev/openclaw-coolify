# syntax=docker/dockerfile:1

FROM docker:cli AS dockercli

########################################
# Stage 1: Base System
########################################
FROM node:24-bookworm AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore

# Core packages + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    lsof \
    openssl \
    ca-certificates \
    gnupg \
    ripgrep fd-find fzf bat \
    pandoc \
    poppler-utils \
    ffmpeg \
    imagemagick \
    graphviz \
    sqlite3 \
    pass \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# 🔥 CRITICAL FIX (native modules)
ENV PYTHON=/usr/bin/python3 \
    npm_config_python=/usr/bin/python3

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    npm install -g node-gyp

########################################
# Stage 2: Runtimes
########################################
FROM base AS runtimes

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

ENV BUN_INSTALL="/data/.bun" \
    PATH="/usr/local/go/bin:/data/.bun/bin:/data/.bun/install/global/bin:$PATH"

# Install Bun (allow bun to manage compatible node)
RUN curl -fsSL https://bun.sh/install | bash

# Python tools
RUN pip3 install ipython csvkit openpyxl python-docx pypdf botasaurus browser-use playwright --break-system-packages && \
    playwright install-deps

ENV XDG_CACHE_HOME="/data/.cache"

########################################
# Stage 3: Dependencies
########################################
FROM runtimes AS dependencies

ARG OPENCLAW_BETA=false
ENV OPENCLAW_BETA=${OPENCLAW_BETA} \
    OPENCLAW_NO_ONBOARD=1 \
    NPM_CONFIG_UNSAFE_PERM=true

# Bun global installs (with cache)
RUN --mount=type=cache,target=/data/.bun/install/cache \
    bun install -g vercel @marp-team/marp-cli https://github.com/tobi/qmd && \
    bun pm -g untrusted && \
    bun install -g @openai/codex @google/gemini-cli opencode-ai @steipete/summarize @hyperbrowser/agent clawhub

# Ensure global npm bin is in PATH
ENV PATH="/usr/local/bin:/usr/local/lib/node_modules/.bin:${PATH}"

# OpenClaw CLI
RUN --mount=type=cache,target=/data/.npm \
    set -eux; \
    if [ "$OPENCLAW_BETA" = "true" ]; then \
        npm install -g openclaw@beta; \
    else \
        npm install -g openclaw@latest; \
    fi; \
    if ! command -v openclaw >/dev/null 2>&1; then \
        npm_root="$(npm root -g)"; \
        pkg_json="$npm_root/openclaw/package.json"; \
        if [ ! -f "$pkg_json" ]; then \
            echo "OpenClaw package metadata not found after npm install" >&2; \
            exit 1; \
        fi; \
        bin_rel="$(node -e 'const pkg=require(process.argv[1]);const bin=pkg.bin;if(typeof bin==="string"){process.stdout.write(bin);process.exit(0)}if(bin&&typeof bin.openclaw==="string"){process.stdout.write(bin.openclaw);process.exit(0)}const first=Object.values(bin||{}).find(Boolean);if(first){process.stdout.write(first)}' "$pkg_json")"; \
        if [ -z "$bin_rel" ] || [ ! -f "$npm_root/openclaw/$bin_rel" ]; then \
            echo "OpenClaw CLI entrypoint not found after npm install" >&2; \
            exit 1; \
        fi; \
        printf '%s\n%s\n' '#!/usr/bin/env bash' "exec node \"$npm_root/openclaw/$bin_rel\" \"\$@\"" > /usr/local/bin/openclaw; \
        chmod +x /usr/local/bin/openclaw; \
    fi; \
    command -v openclaw

# Install uv explicitly
RUN curl -L https://github.com/azlux/uv/releases/latest/download/uv-linux-x64 -o /usr/local/bin/uv && \
    chmod +x /usr/local/bin/uv

# Claude + Kimi
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    command -v uv

# Make sure uv and other local bins are available
ENV PATH="/root/.local/bin:${PATH}"

########################################
# Stage 4: Final
########################################
FROM dependencies AS final

WORKDIR /app
COPY . .

# Symlinks
RUN ln -sf /data/.claude/bin/claude /usr/local/bin/claude || true && \
    ln -sf /data/.kimi/bin/kimi /usr/local/bin/kimi || true && \
    ln -sf /app/scripts/openclaw-approve.sh /usr/local/bin/openclaw-approve || true && \
    chmod +x /app/scripts/*.sh

ENV PATH="/root/.local/bin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin:/data/.bun/bin:/data/.bun/install/global/bin:/data/.claude/bin:/data/.kimi/bin"
EXPOSE 18789
CMD ["bash", "/app/scripts/bootstrap.sh"]
