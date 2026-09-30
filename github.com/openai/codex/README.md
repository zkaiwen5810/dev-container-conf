# OpenAI Codex development container

This directory is a **local stub** for developing [openai/codex](https://github.com/openai/codex). Open this directory in VS Code, then run **Dev Containers: Reopen in Container**. Docker Desktop must be running Linux containers. The first creation clones Codex into the Docker volume `openai-codex-src` at `/workspaces/codex`. Source files are not copied from or synchronized with this Windows directory. Existing checkouts are never pulled or reset automatically.

After opening the container:

```bash
bash /opt/devcontainer-config/setup-workspace.sh
cd /workspaces/codex/codex-rs
cargo build --locked
cargo run --bin codex -- "explain this codebase to me"
just test -p codex-tui
```

Run the setup script again after changing branches or dependency lockfiles. It uses `pnpm install --frozen-lockfile` and `cargo fetch --locked`; it does not rewrite lockfiles. `just fmt`, `just fix -p <crate>`, and `just test -p <crate>` use the upstream justfile. Bare `codex` is the released CLI installed by the AI feature; `cargo run --bin codex -- ...` or `just codex ...` runs your source changes.

The image includes Node 22, Rust 1.95.0 with rustfmt/clippy/rust-src, pnpm 10.34.5, just, DotSlash, nextest, uv, and native compilation dependencies. This covers the Cargo development workflow and Python/JS maintenance tooling. Bazel, cross-compilation toolchains, and release packaging are not provisioned. Start with targeted crate tests rather than the full workspace. Large Rust builds need substantial Docker disk and RAM; resource limits are left to Docker Desktop.

## Editor memory and connection recovery

The full Codex Rust workspace can use substantial memory during indexing. This configuration starts Rust Analyzer with two analysis threads, disables eager cache priming, and reduces its syntax-tree LRU capacity to 64. It also disables checks on save, build scripts, and procedural-macro expansion. Generated-code completion and diagnostics are consequently incomplete. These are reduced-work settings, not a hard memory limit. Build output and dependency directories are excluded from file watching and text search; those exclusions do not control Rust Analyzer's dependency analysis.

`CARGO_BUILD_JOBS=2` limits concurrent Cargo compilation jobs. The same value is supplied through Rust Analyzer's `cargo.extraEnv` so its Cargo subprocesses receive it too. This does not limit the analyzer's total memory. Run targeted checks manually, for example `cargo check --locked -j 2 -p codex-cli` from `codex-rs`.

If indexing causes disconnections:

1. Check Docker/WSL memory and kernel OOM logs. An observed failure on this host killed Rust Analyzer at approximately 8.6 GiB resident memory; the 16 GB Windows host also had about 390 MiB free. High CPU alone was not the underlying failure.
2. Apply these `customizations.vscode.settings` values to the existing container's **Remote Settings (JSON)** and reload the VS Code window. Workspace settings can override remote settings. Editing the local devcontainer file alone does not reliably update an already-created container's editor settings.
3. For future containers, the settings are already included here. **Dev Containers: Rebuild Container** also applies the container environment change and reuses unchanged Docker image layers. Do not select the no-cache rebuild option for this issue.
4. Free memory by stopping unused workloads. If Docker responds, reconnect to the affected container before considering a Docker/WSL restart, which interrupts other containers. Increasing WSL's allocation beyond 12 GB on a 16 GB host can worsen Windows memory pressure.

Once stable, enable `rust-analyzer.cargo.buildScripts.enable`, then `rust-analyzer.procMacro.enable`, monitoring memory after each change. Full analysis may require more RAM; if the reduced settings still exhaust memory, disable the Rust Analyzer extension for this workspace and use manual targeted Cargo checks until more memory is available.

Settings reference: [Rust Analyzer configuration](https://rust-analyzer.github.io/book/configuration) and [Cargo environment variables](https://doc.rust-lang.org/cargo/reference/environment-variables.html).

## Cache design

* **Docker layers:** no source, manifests, lockfiles, or scripts are copied into the image. `.dockerignore` allows only the Dockerfile and itself. Source edits, dependency changes, credentials, and lifecycle-script edits cannot invalidate tool installation layers. The configuration directory is mounted read-only at runtime.
* **BuildKit caches:** APT package files and indexes use locked cache mounts. Disabling Debian's `docker-clean` hook allows downloaded packages to survive a changed APT layer. They stay in the builder cache rather than inflating the image. Regular rebuilds reuse complete layers first.
* **Stable tool versions:** Rust, pnpm, uv, just, DotSlash, nextest, and the AI feature use explicit versions. Helper tools use release binaries to avoid compiling helpers during image builds. A changed tool version invalidates its layer and later layers, not earlier ones. Base image tags and version tags are not immutable digests; cold builds can still differ.
* **Runtime caches:** Cargo registry and Git caches, pnpm store, uv cache, and DotSlash cache each have shared named volumes (`cargo-registry`, `cargo-git`, `pnpm-store`, `uv-cache`, `dotslash-cache`). Cargo is Rust's package manager and build tool: `registry` caches published crates, while `git` caches dependencies obtained from Git repositories. Other projects can reuse these downloads by mounting the same volumes. The project-specific source volume also retains `codex-rs/target`, `node_modules`, and Python environments across container recreation. Keeping Cargo's default target location preserves upstream helpers that refer to `target/debug/codex` directly. Do not mount over all of `/usr/local/cargo` or Rust's toolchain: that would hide baked-in tools.
* **No eager build:** opening the editor clones source once but does not build Codex or fetch its entire dependency graph. Run the setup command when ready. Source/dependency work happens at runtime and never causes an image rebuild.
* **Cache boundaries:** Docker image layers, BuildKit package caches, and runtime volumes are different caches. `docker builder prune` affects builder caches; deleting `openai-codex-src` deletes source and uncommitted work as well as build artifacts. None are automatically deleted by these scripts. For a second independent checkout, change the source volume name while keeping app-state and download-cache volume names shared.

The feature still runs its own APT/npm installers, installs current AI CLI releases, and cleans its npm cache. Its exact version fixes the installer, not the versions of Codex/Claude/OpenCode it downloads. Normal rebuilds reuse the feature layer; a cold rebuild may install newer CLIs. Refreshing that layer deliberately requires rebuilding without cache (which also discards reuse for other layers). Fully reproducible CLI releases require adding version options to the upstream feature. No unsupported options are invented here.

## Credentials and optional network mirrors

No credentials are required to clone the public repository. VS Code Dev Containers can forward your SSH agent and Git credential helper; configure Git identity inside the container or through VS Code. AI CLI state intentionally shares the reference configuration's existing Docker volumes: `codex-home`, `claude-home`, `claude-config`, `claude-cache`, `opencode-config`, `opencode-share`, and `claude-code-persist`. Existing sign-ins and settings are available across projects on the same Docker engine; sign in interactively if the shared volumes are new. Do not commit credentials.

Docker shares a named volume by its `source` name, not by the container's `target` path. In particular, retain the reference's `claude-code-persist` name: it mounts at `/home/node/.persist`, and `~/.claude.json` links to the shared `.persist/.claude.json`. Naming it merely `persist` would create a different volume. Other project configurations must use these same source names to participate in sharing. The source workspace remains `openai-codex-src`.

After changing mount names, recreate the container using **Dev Containers: Rebuild Container**. This mount-only change reuses the image layers. Previously created `openai-codex-*` app/cache volumes are not migrated or deleted automatically; the updated mounts use the reference's shared data.

If you need the reference's runtime environment file, create `.devcontainer.env` alongside this README and add this property to `devcontainer.json`:

```json
"runArgs": ["--env-file", "${localWorkspaceFolder}/.devcontainer.env"]
```

The file is ignored locally. Docker requires it to exist when `--env-file` is enabled. Credentials passed this way remain runtime values and never enter build layers. Recreate the container to change runtime environment variables.

Public registries are the default. For a network that needs the reference's mirrors, configure npm/pip/uv or replace APT sources deliberately. Build-time mirror changes invalidate relevant image layers; runtime registry configuration does not. Do not set `PIP_TRUSTED_HOST` for an HTTPS endpoint with a valid certificate.

## Reference configuration: every adoption decision

Reference: `C:/Users/dsens/Codebase/claude-code-2_1_88/.devcontainer/` (`devcontainer.json`, `Dockerfile`, `post-create.sh`). “Adapt” retains the purpose with a different implementation.

### devcontainer.json

| Reference item | Purpose | Decision for Codex |
| --- | --- | --- |
| `name: claude-code-2.1.88` | Editor display label | Adapt to `openai-codex`. |
| `build.dockerfile: Dockerfile` | Custom system/tool image | Adopt. Rust and native dependencies need an image. |
| `build.context: .` | Small context scoped to `.devcontainer` | Adopt and add an allowlist `.dockerignore`. |
| `remoteUser: node` | Non-root shell with base-image sudo support | Adopt; matches the Node base and feature's `_REMOTE_USER`. |
| `updateRemoteUserUID: true` | Linux host UID/GID compatibility | Adopt; useful beyond Windows. Ownership repair handles new volumes. |
| Named `workspaceMount` | Avoid Windows bind-mount overhead and persist source | Adapt to `openai-codex-src`; clone once on creation. |
| `workspaceFolder` | Editor's source root | Adapt to `/workspaces/codex`. |
| `ai-coding-cli:latest` | Install Codex, Claude Code, OpenCode | Required; adopt with explicit `0.2.7` installer version. |
| `nodeMajor: 20` | Feature fallback when Node is absent | Change to 22; upstream requires >=22. The feature checks for Node, so the base image remains its provider. |
| `installZsh: true` | Install and select zsh for the remote user | Adopt. |
| `installZshrc: true` | Supply minimal shell configuration | Adopt; feature default avoids overwriting an existing zshrc. |
| Mandatory `--env-file` | Inject credentials/proxies without rebuilding | Make opt-in, documented above; missing file would otherwise prevent startup. |
| Read-only `${localEnv:USERPROFILE}/.ssh` bind | Make host SSH keys/config available | Omit; Windows-only path, missing-directory and Linux permission issues. Prefer agent forwarding. |
| Read-only `${localEnv:USERPROFILE}/.gitconfig` bind | Share Git identity/config | Omit; optional host file and platform-specific settings should not be required to start. Use forwarding or configure Git. |
| `pnpm-store` volume | Reuse downloaded JS dependencies | Adopt the same shared name and an effective pnpm store configuration. |
| `codex-home` volume | Keep Codex login/config/history | Adopt the same name to share state across projects. |
| `claude-home` volume | Keep Claude login/session state | Adopt the same shared name. |
| `claude-config` volume | Keep Claude XDG configuration | Adopt the same shared name. |
| `claude-cache` volume | Reuse Claude cache | Adopt the same shared name. |
| `opencode-config` volume | Keep OpenCode configuration | Adopt the same shared name. |
| `opencode-share` volume | Keep OpenCode data/auth/session state | Adopt the same shared name. |
| `claude-code-persist` volume | Store root-level `.claude.json` outside ephemeral home | Adopt this exact shared name so the symlink uses the reference's existing configuration. |
| `PNPM_STORE_DIR` | Intended pnpm cache redirection | Replace with `npm_config_store_dir`, the pnpm configuration environment variable; a custom `PNPM_STORE_DIR` alone does not reliably configure pnpm. |
| `SHELL=/usr/bin/zsh` | Advertise the preferred shell to subprocesses | Adopt and explicitly select zsh for VS Code terminals. |
| `postCreateCommand` with `bash -lc`, fixed `cd`, `/tmp/post-create.sh` | Initialize volume ownership and persistence after mounts exist | Adapt to non-login bash and a read-only mounted script. Each script sets its own working directory; no dependence on shell startup files. |

### Dockerfile

| Reference item | Purpose | Decision for Codex |
| --- | --- | --- |
| `javascript-node:22` | Node, Corepack, non-root user, common development utilities | Adopt with explicit Debian Bookworm variant to stabilize distro assumptions. |
| Two APT `sed` mirror substitutions | Faster Debian/security downloads from China | Omit by default; geographically dependent and tied to a particular source-file layout. See optional mirrors above. |
| `apt-get update && apt-get install` | Native system dependencies | Adopt with `--no-install-recommends` and locked BuildKit caches. |
| `build-essential` | Compiler, libc headers, make | Adopt for Rust native dependencies and Node addons. |
| Explicit `make`, `g++` | Native compilation | Omit duplicates; already supplied by `build-essential`. |
| `python3` | Build scripts and justfile's Python shell wrapper | Adopt; directly required by current upstream justfile. |
| `python3-pip` | Install Python packages globally | Omit; uv supplies isolated project environments. |
| `python3-venv` | Isolated Python environments | Adopt for SDK/script development. |
| `curl` | Download tooling | Adopt. |
| `jq` | Inspect JSON/API output | Adopt as a small development utility. |
| `ripgrep` | Fast source search for humans and AI CLIs | Adopt. |
| `fd-find` | Fast filename search | Adopt; Debian command is `fdfind`. |
| `zsh` | Interactive shell | Adopt; feature also ensures it exists. APT does not reinstall an already installed version. |
| `bubblewrap` | Linux process sandbox support | Adopt; availability does not guarantee Docker's host kernel/security policy permits nested namespaces. |
| `vim` | Terminal editing | Adopt for reference parity. |
| Delete `/var/lib/apt/lists/*` | Reduce image layer size | Replace with cache mounts; lists are not committed to the layer and remain reusable. |
| `NPM_CONFIG_REGISTRY=npmmirror` | Alternate npm download endpoint | Omit global mirror; opt-in by network need. |
| `corepack enable` | Activate package-manager shims | Adopt at image build and startup. The Node base has a separate global pnpm earlier on PATH; startup replaces that entry with a Corepack shim so checkout pins are respected. This is a local symlink operation, not a package download. |
| `corepack prepare pnpm@latest` | Make pnpm available before checkout | Pin 10.34.5 from upstream; Corepack later honors each checkout's `packageManager`. |
| `PIP_INDEX_URL` | Alternate Python package endpoint | Omit default mirror. |
| `PIP_TRUSTED_HOST` | Relax certificate verification for a host | Omit; unnecessary for valid HTTPS. |
| `UV_INDEX_URL` | Alternate uv package endpoint | Omit default mirror. |
| `pip3 install --no-cache-dir uv --break-system-packages` | Install uv despite externally managed Python | Replace with versioned uv image binaries; no system Python modification or pip download step. |
| `COPY post-create.sh /tmp/...` | Make bootstrap available when workspace is a volume | Replace with runtime config bind; script changes no longer invalidate later feature layers. |
| `sed` CRLF removal | Make Windows-authored scripts executable in Linux | Replace with `.gitattributes` enforcing LF. Keep LF when copying/editing these files manually. |
| `chmod +x` script | Permit direct execution | Omit; lifecycle and setup commands explicitly invoke bash. |

### post-create.sh

| Reference item | Purpose | Decision for Codex |
| --- | --- | --- |
| Bash shebang; `set -euo pipefail` | Reliable shell and early failure | Adopt in both scripts. |
| Recursive `sudo chown` of cache/state paths | Repair root-owned Docker volumes | Adapt: check each exact volume's owner first. Recurse only for new ownership; avoid scanning all caches and unrelated `.config`/`.local` data on every rebuild. Add source and Rust cache paths. |
| Create `~/.local/bin` and `codex-dfa` launcher | Run installed Codex with `--sandbox danger-full-access` | Omit. It bypasses the sandbox and would run the released CLI rather than the source binary. Sandbox-specific testing should use an explicitly selected setup. |
| Launcher's `command -v`, missing-binary check, `exec`, mode `0755` | Locate/replace process with the full-access CLI | Omit along with the launcher. |
| Create `.persist`, define source/target variables | Keep a file across container recreation | Adopt. |
| Initialize missing `.claude.json` to `{}` | Ensure a valid initial configuration file | Adopt only when no existing regular config can be migrated. |
| `rm -f` existing `.claude.json`, then symlink | Redirect CLI state into the persistence volume | Adapt: migrate the existing file if possible, back it up before linking, preserve existing symlinks. No destructive overwrite. |

### Codex-specific additions

`pkg-config`, OpenSSL headers, CMake, Clang, and libclang follow upstream's Nix development shell; libcap headers follow its Linux package definition. `CC=clang` and `CXX=clang++` follow its BoringSSL compiler choice. Rust comes from a versioned official Rust image, with the toolchain writable by the development user so a changed checkout can request a newer version. Additional toolchains installed at runtime are not persisted across image rebuilds; update the Dockerfile Rust pin when adopting a new baseline.

just, DotSlash, and nextest support the documented build/test/format helpers. uv supports `scripts/format.py` and the Python SDK. Corepack uses a shared image directory so pnpm prepared during the root build is also available to `node`; bootstrap repairs tool-directory ownership if UID remapping changes the user and activates Corepack in the base image's global npm bin directory. Run the post-create script before using a bare Docker image outside Dev Containers, since that bypasses lifecycle initialization. Rust Analyzer and TOML extensions provide editor support; `linkedProjects` points at the nested Cargo workspace. Rust Analyzer can be memory-intensive on this workspace; the reduced analysis defaults and their tradeoffs are documented above.

`devcontainer-lock.json`, generated by the Dev Containers CLI, records the resolved AI feature digest. Keep it with the configuration when copying this stub; use the CLI's feature-upgrade workflow when deliberately updating the feature.

## Evidence and version baseline

Inspected Codex commit [`d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b`](https://github.com/openai/codex/commit/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b) on 2026-09-29:

* [Build instructions](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/docs/install.md): Cargo, just, DotSlash, nextest.
* [Rust toolchain](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/codex-rs/rust-toolchain.toml): Rust 1.95.0 and components.
* [package.json](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/package.json): Node >=22 and pnpm 10.34.5.
* [Nix shell](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/flake.nix): native libraries and Clang selection.
* [Nix package](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/codex-rs/default.nix): Linux libcap dependency.
* [Formatter](https://github.com/openai/codex/blob/d515b2f85ec1b24a4b5ec3fbd86db27fd51aea3b/scripts/format.py): Python, uv and DotSlash usage.

The clone intentionally follows the repository's default branch, not this evidence commit. For the exact reviewed baseline, check out that commit before running setup. Review tool pins as upstream changes.

The feature options and install behavior were inspected in the local `C:/Users/dsens/Codebase/devcontainer-features/src/ai-coding-cli/` version 0.2.7 source and verified against the downloaded OCI feature. Dev Containers resolved version 0.2.7 to `sha256:098c87169246f9a1da550a975b3d3b2434cdc2d5dab832ea620b0792429571be`.

## Validation

Validated on 2026-09-29 using Docker Desktop Linux/amd64 and Dev Containers CLI 0.89.0:

* Full image build, including the published AI feature: passed. The local image is `openai-codex-devcontainer:latest`.
* Repeat Dev Containers build: all RUN/COPY layers, including the AI feature, reported `CACHED`; about 18 seconds including registry metadata resolution.
* Changed APT package list: downloaded only 524 KB of a 104 MB package set, reusing the BuildKit package cache.
* Non-root runtime checks: Rust 1.95.0 and its components, pnpm 10.34.5, the configured `/home/node/.pnpm-store/v10` store, just, DotSlash, nextest, uv, OpenSSL/libcap, and zsh passed.
* Installed AI CLI version checks: Codex 0.159.0, Claude Code 2.1.284, OpenCode 1.18.33. These are observations from this build, not additional version pins.
* Both lifecycle scripts passed against a disposable Rust/pnpm fixture: locked dependency setup, unchanged lockfiles, Rust compilation, nextest invocation, and repeat initialization. Separate fixtures covered initial cloning, refusal to overwrite unrelated files, mount ownership, and preservation of existing Claude settings and backups.
* JSON parsing, Bash syntax, LF attributes, environment-file ignore rule, and whitespace checks passed.

The full upstream Codex workspace was not compiled or tested, and no authenticated AI requests were made. ARM64 and host-specific nested sandbox behavior were not validated. The fixture checks validate container setup and tool integration, not Codex application behavior.
