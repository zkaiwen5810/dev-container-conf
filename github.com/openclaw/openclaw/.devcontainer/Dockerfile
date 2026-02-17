
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG NODE_MAJOR=22

# 最小但偏稳：git/curl + node 常见 native 依赖编译环境（避免 pnpm install 时频繁踩坑）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl ca-certificates \
      build-essential python3 pkg-config \
      libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
      jq ripgrep unzip \
    && rm -rf /var/lib/apt/lists/*

# Node 22 + corepack（让 pnpm 版本可锁定）
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    corepack enable

USER vscode
