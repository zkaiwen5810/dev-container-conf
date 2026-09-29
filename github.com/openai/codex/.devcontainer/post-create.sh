#!/usr/bin/env bash
set -euo pipefail

workspace=/workspaces/codex
owner="$(id -u):$(id -g)"
# Docker may create mount-parent directories as root. Repair only their roots,
# so tools can create sibling config/cache directories without a recursive scan.
for parent in "$HOME/.cargo" "$HOME/.config" "$HOME/.cache" "$HOME/.local" "$HOME/.local/share"; do
  sudo mkdir -p "$parent"
  sudo chown "$owner" "$parent"
done
paths=(
  "$workspace" /usr/local/rustup /usr/local/share/corepack
  "$HOME/.cargo/registry" "$HOME/.cargo/git"
  "$HOME/.pnpm-store" "$HOME/.cache/uv" "$HOME/.cache/dotslash"
  "$HOME/.codex" "$HOME/.claude" "$HOME/.config/claude"
  "$HOME/.cache/claude" "$HOME/.config/opencode"
  "$HOME/.local/share/opencode" "$HOME/.persist"
)
for path in "${paths[@]}"; do
  sudo mkdir -p "$path"
  # Only traverse a volume when its owner changed (new volume or host UID).
  if [[ "$(stat -c '%u:%g' "$path")" != "$owner" ]]; then
    sudo chown -R "$owner" "$path"
  fi
done

# The Node base also ships a global pnpm ahead of /usr/local/bin on PATH.
# Point that location at Corepack without downloading/reinstalling any tools.
corepack enable --install-directory /usr/local/share/npm-global/bin

# Preserve existing Claude settings instead of deleting an ordinary file.
persist_file="$HOME/.persist/.claude.json"
target_file="$HOME/.claude.json"
if [[ ! -e "$persist_file" ]]; then
  if [[ -f "$target_file" && ! -L "$target_file" ]]; then
    cp -p "$target_file" "$persist_file"
  else
    printf '{}\n' > "$persist_file"
  fi
fi
if [[ ! -L "$target_file" ]]; then
  if [[ -e "$target_file" ]]; then
    mv "$target_file" "${persist_file}.before-devcontainer.$(date +%s%N)"
  fi
  ln -s "$persist_file" "$target_file"
fi

# A named workspace volume does not receive files from the Windows stub.
# Clone once; never reset, pull, or overwrite an existing checkout.
if [[ ! -e "$workspace/.git" ]]; then
  if [[ -n "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Refusing to clone into nonempty $workspace; move the files or use a fresh source volume." >&2
    exit 1
  fi
  git clone https://github.com/openai/codex.git "$workspace"
fi

printf '\nWorkspace ready. Install checkout dependencies with:\n'
printf '  bash /opt/devcontainer-config/setup-workspace.sh\n'
