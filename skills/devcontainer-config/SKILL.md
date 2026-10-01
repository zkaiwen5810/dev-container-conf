---
name: devcontainer-config
description: Create or update repository-specific Dev Container configuration sets with fast rebuilds, minimal required tools, regional package mirrors, correct mounted-directory ownership, and shared AI coding agent settings.
---

# Dev Container configuration

Produce a usable `.devcontainer/` configuration set matched to the repository. Preserve existing choices unless they conflict with the user's requirements. Use the local `github.com/openai/codex/.devcontainer/` example when available as a design reference, not a template to copy indiscriminately. Do not require that example to exist on other machines.

## Discover and resolve choices

Read repository instructions, manifests, lockfiles, toolchain declarations, existing container configuration, and build/test commands. Identify the host architecture, Docker host location, workspace mount strategy, `remoteUser`, home directory, and required tools. Derive versions from the repository rather than the example's Rust or Node versions.

Before choosing download sources, ask the user which package mirror region to use: mainland China, another specified region, official upstream, or custom endpoints. Reuse an explicit preference already supplied in the conversation. Do not infer it from locale or timezone. Continue repository inspection while waiting, but leave mirror-dependent configuration unfinished until the user answers. Ask once for all applicable managers and explain any manager without a suitable verified mirror.

Only install packages or binaries needed for the project's build, tests, development workflow, or mandatory AI feature. Reuse tools already supplied by the base image or Features. Avoid duplicate runtimes, shells, editors, and convenience utilities. The mandatory exception is `ai-coding-cli`.

## Required AI feature and shared state

Always include the Dev Container Feature `ghcr.io/zkaiwen5810/features/ai-coding-cli` in `features`; installing a single CLI is not a substitute. The inspected Codex reference uses tag `0.2.7` with `nodeMajor`, `installZsh`, and `installZshrc`. Verify the chosen published tag and supported options against its maintained source before generation. Do not silently choose latest or assume old options still apply. Configure only necessary optional components. If metadata is unavailable, report the verification limitation and do not claim a successful build.

Persist installed agents' data and settings using stable named Docker volumes whose source names are identical across the user's containers on the same Docker daemon. Do not prefix agent-state volumes with the repository, workspace basename, or container ID. With Compose, use explicit volume `name` values to prevent project prefixes. Preserve existing shared names when updating configurations.

The reference maps `codex-home` to `$HOME/.codex`, `claude-home` to `$HOME/.claude`, `claude-config` to `$HOME/.config/claude`, `claude-cache` to `$HOME/.cache/claude`, `opencode-config` to `$HOME/.config/opencode`, `opencode-share` to `$HOME/.local/share/opencode`, and `claude-code-persist` to `$HOME/.persist`. Translate `$HOME` to the actual remote user's absolute home in mount targets. Verify which locations the installed CLI versions actually use; include their required state locations rather than blindly adding every example mount.

Persist single-file settings such as Claude's `$HOME/.claude.json` via a file inside a mounted directory and a symlink. Preserve existing content and wrong-target symlinks with a backup before migration; never replace settings with an empty object or overwrite an existing persisted file. Make migration repeatable. Do not bake credentials into images or copy agent state into the repository. Shared volumes are daemon-local; do not imply automatic synchronization across Docker hosts.

## Fast rebuilds and dependency setup

Separate stable image tool installation from frequently changing repository dependency setup. Keep the build context small using an appropriate context path or `.dockerignore`; ensure required build files remain included. Changes to source code should not invalidate stable tooling layers.

Use BuildKit `RUN --mount=type=cache` for downloads made during builds. These caches belong to the builder and differ from runtime named volumes. For apt, preserve downloaded packages when the base image enables automatic cleanup, cache package archives and lists, and use `sharing=locked`. Scope cache IDs to compatible distro, architecture, and source configuration. Never put required installed binaries only in a cache mount: its contents are not part of the final image.

Use runtime named volumes for package caches consumed after creation, matched to actual manager configuration: for example Cargo registry/git subdirectories, pnpm store, or uv cache. Verify effective cache locations using the manager's own command or documentation. Do not assume an npm setting configures pnpm on every version. Avoid mounting an entire tool home over image-installed binaries, toolchains, or configuration. Share compatible download caches; scope compiled outputs and dependency trees to their project/toolchain/architecture when reuse would be unsafe.

Prefer pinned official prebuilt binaries or multi-stage copies to compiling helper tools during rebuilds. Check architecture support and release integrity where supplied. Use lockfile-respecting dependency installation and avoid reinstalling unchanged tools in lifecycle hooks. Offer a separate dependency setup command when automatically running it would be expensive or outside the requested scope.

Apply the selected region to each relevant manager and download phase, including Feature installation where its documented options permit it. Expose build arguments or container environment/configuration at the phase where downloads actually occur. Use verified HTTPS sources, preserve signature/TLS verification and private registry configuration, and keep authentication out of committed files. Do not promise fastest downloads without measurements.

## Ownership before readiness

Resolve the effective numeric UID/GID after `updateRemoteUserUID`, and use them for runtime ownership. Image-time `chown` cannot fix volumes mounted later. Inventory every writable mount, its parent directories, and any image directory the remote user must update. Read-only mounts are exempt from mutation.

Run an idempotent ownership repair after mounts are attached and before dependency installation or agent use. Serialize repair and dependent setup; do not use parallel lifecycle command objects for dependent actions. Gate initial readiness with the repair (including `waitFor` where needed). If ownership can change on later starts, run the same check before use on each start.

Repair explicitly enumerated writable targets and any necessary parent roots with root or working noninteractive sudo. Check descendants as well as the mount root: a correctly owned root can hide root-owned files. Use a fast mismatch search that stops at the first match, then repair only mismatched entries or the affected tree without following symlinks or crossing nested mounts. Do not recursively change all of `$HOME`, `/workspaces`, or host directories outside declared targets; never use `chmod 777` as an ownership fix. For host bind mounts, assess the host-side effect and avoid changing unrelated files.

Use the same numeric UID/GID in containers sharing writable agent volumes; concurrent containers must not repeatedly chown shared data to competing identities. Surface incompatible identities and resolve the configuration before declaring readiness. If a filesystem cannot change ownership, report the blocked mount and use a compatible named volume or agreed UID mapping. Do not swallow repair failures. Verify write access as `remoteUser`, not as root.

For a named workspace volume, initialize a checkout only when empty. Never reset, pull, or overwrite an existing checkout as part of readiness. Keep workspace volumes project-specific even though agent settings volumes are shared.

## Validate and deliver

Create only the files needed: `devcontainer.json`, Dockerfile when needed, lifecycle scripts, ignore rules, and optional dependency setup instructions. Use LF for Linux scripts and invoke them through their interpreter or set executable permissions. Resolve script paths against the actual workspace/mount strategy.

Validate JSON/JSONC and Feature options, build context paths, shell syntax, mount sources/targets, effective cache paths, and lifecycle ordering. When Docker and the Dev Container CLI are available, build and open the container, then check as `remoteUser` that required CLI commands run and every writable mount accepts writes. Test ownership repair with both an empty volume and a volume with a correctly owned root but incorrectly owned child. Rebuild with existing volumes, verify settings survive, and confirm a second container resolves the same agent volumes with compatible ownership. Avoid concurrent application writes in the persistence check. Check that an ordinary source change leaves tooling layers cached.

Report generated files, mirror choice, shared volume names, and checks actually performed. Distinguish static validation from a successful container build; do not claim measured rebuild improvements without timing them. Do not prune caches, delete volumes, or alter global Docker settings to validate this skill.

Consult current primary documentation when syntax or manager behavior needs verification: [Docker cache guidance](https://docs.docker.com/build/cache/optimize/), [Dev Container configuration reference](https://containers.dev/implementors/json_reference/), and the selected Feature's maintained source.
