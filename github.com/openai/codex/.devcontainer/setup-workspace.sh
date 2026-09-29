#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/codex
test -f package.json
test -f codex-rs/rust-toolchain.toml

# Corepack honors packageManager in this checkout, including its integrity hash.
pnpm install --frozen-lockfile
cd codex-rs
# rustup honors rust-toolchain.toml; a newer checkout can install a newer toolchain.
rustup show active-toolchain
cargo fetch --locked
printf '\nReady: cd /workspaces/codex/codex-rs && cargo build --locked\n'
