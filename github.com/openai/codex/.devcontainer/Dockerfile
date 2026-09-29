# syntax=docker/dockerfile:1
FROM rust:1.95.0-bookworm AS rust
FROM ghcr.io/astral-sh/uv:0.12.20 AS uv

FROM mcr.microsoft.com/devcontainers/javascript-node:22-bookworm
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Preserve downloaded debs and package indexes across changes to this layer.
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential pkg-config libssl-dev libcap-dev cmake clang libclang-dev \
      python3 python3-venv curl ca-certificates git jq ripgrep fd-find \
      bubblewrap vim unzip zsh

# Rust and helper binaries are image contents, never hidden by a CARGO_HOME mount.
COPY --from=rust /usr/local/cargo /usr/local/cargo
COPY --from=rust --chown=node:node /usr/local/rustup /usr/local/rustup
ENV CARGO_HOME=/home/node/.cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/home/node/.cargo/bin:/usr/local/cargo/bin:${PATH} \
    CC=clang \
    CXX=clang++
RUN mkdir -p /home/node/.cargo && chown node:node /home/node/.cargo
USER node
RUN rustup component add rustfmt clippy rust-src
USER root

COPY --from=uv /uv /uvx /usr/local/bin/

# Pin helper releases; download binaries instead of recompiling them on rebuild.
ARG JUST_VERSION=1.58.0
RUN arch="$(uname -m)" \
    && curl -fsSL --retry 3 "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${arch}-unknown-linux-musl.tar.gz" \
       | tar -xz -C /usr/local/bin just

ARG DOTSLASH_VERSION=0.5.9
RUN arch="$(uname -m)" \
    && curl -fsSL --retry 3 "https://github.com/facebook/dotslash/releases/download/v${DOTSLASH_VERSION}/dotslash-linux-musl.${arch}.tar.gz" \
       | tar -xz -C /usr/local/bin dotslash

ARG NEXTEST_VERSION=0.9.146
RUN arch="$(uname -m)" \
    && curl -fsSL --retry 3 "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-${NEXTEST_VERSION}/cargo-nextest-${NEXTEST_VERSION}-${arch}-unknown-linux-gnu.tar.gz" \
       | tar -xz -C /usr/local/bin cargo-nextest

ARG PNPM_VERSION=10.34.5
ENV COREPACK_HOME=/usr/local/share/corepack
RUN corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate \
    && chown -R node:node "$COREPACK_HOME"

# No source, lockfiles, secrets, or lifecycle scripts enter the image context.
# The AI feature is installed by Dev Containers after these stable layers.
