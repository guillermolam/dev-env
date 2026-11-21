# dev-env

Declarative Apple Silicon Mac configuration using Nix, nix-darwin, and Home
Manager, plus a Python controller whose backup and update decisions are made by
local Open Policy Agent (OPA) policies.

## Status

The controller, inventory, policy engine, backup wrapper, and update gates are
implemented and covered by tests. They are not installed as a scheduled service.
No production backup destination, credential reference, approved baseline, or
complete security-collector coverage is configured. Daily updates and restores
are therefore not operational.

Windows, WSL, Linux, and Intel Mac configurations are not implemented.

- [RULES.md](RULES.md) — implementation and operational requirements.
- [PLAN.md](PLAN.md) — completed work, remaining deployment inputs, and validation.
- [FEATURES.md](FEATURES.md) — implemented, tested, and not-yet-operational capabilities.
- [TASKS.md](TASKS.md) and [TASKS.csv](TASKS.csv) — task status.
- [Operations guide](operations/README.md) — commands and test entry points.
- [Recovery runbook](operations/recovery/RUNBOOK.md) — manual recovery boundaries.

## Layout

This repository is the editable source. Runtime state belongs under
`/private/var/lib/mac-environment`, with logs under
`/private/var/log/mac-environment`. Those directories are not created yet.
Keep `/nix` for Nix itself. Encrypted backups belong on separate storage; the
destination is still unset.

Privileged jobs must run root-owned installed code. Do not point a LaunchDaemon
at this writable checkout. `operations/deploy/install.sh` refuses installation.

## macOS configuration

Configuration: `darwinConfigurations.mac-studio` (`aarch64-darwin`), on
Determinate Nix (`nix.enable = false`).

The macOS username is not committed. Evaluation needs `--impure`:
`DEVENV_USER`, otherwise `SUDO_USER`, otherwise `USER`.

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake ~/code/dev-env#mac-studio
sudo darwin-rebuild switch --impure --flake ~/code/dev-env#mac-studio
```

The second command applies only after nix-darwin is already installed. Neither
command has been run as part of this controller work. Homebrew remains in
`~/Brewfile`. Home Manager does not own `~/.zshrc`, `~/.gitconfig`, or `~/.ssh`.

### Container runtimes and homelab

`hosts/mac-studio/container-runtimes.nix` pins Nix-owned Podman 6.2.0,
Podman Desktop 1.30.7, OrbStack 2.2.5, Colima 0.10.3, and the Incus 7.6
client. Home Manager declares rootless Podman and a Colima `incus` profile,
limits their resources and host mounts, and reconciles OrbStack LAN exposure
and resource ceilings. Activation creates missing runtime VMs and refuses
Podman resource or privilege drift; it never recreates a machine to converge it.

The signed NetBird 0.83.1 UI and daemon remain pinned in
`hosts/mac-studio/netbird.nix`. Set `netbird.managementUrl` in
`homelab/config.nix` to the self-hosted HTTPS endpoint before enrollment.
Browser SSO remains an operator action. The combined server manifest is
`homelab/netbird-server.nix`. It is not rendered until the runtime is enabled
and the 1Password item, proxy CIDRs, and image digests are set. It follows the
v0.83.1 combined server, not an unverified dashboard or Traefik chart.

Central CoreDNS/etcd, OpenBao, cert-manager, ExternalDNS, and 1Password
Operator definitions live in `homelab/` and
`hosts/mac-studio/homelab-services.nix`. They are disabled by default.
Enabling them requires a stable LAN address, Cloudflare and 1Password item
references, OpenBao AppRole inputs, and immutable Kubernetes image digests.
No secrets are stored in the flake. OpenBao uses a persistent host service and
requires a documented operator unseal after restart; offline certificate
renewal is not claimed while it is sealed. Cloudflare BYOCA requires an
Enterprise account and is not enabled here.

Build the native Darwin generation before activation:

```sh
nix build --impure --print-build-logs '.#darwinConfigurations.mac-studio.system'
```

The operator then activates that locked build with:

```sh
sudo ./result/sw/bin/darwin-rebuild switch --impure --flake /Users/glam/Git/guillermolam/dev-env#mac-studio
```

The controller package is a flake output, not part of the activated system:

```sh
nix build .#mac-env
```

That build uses Nixpkgs' `opa`. Controller tests pin and verify OPA 1.22.4
separately. Do not treat those as the same binary until their versions are
compared.

## Policy and tool update control

OPA 1.22.4 evaluates Rego v1 locally. Process exit code zero is not permission
to update. Missing OPA, an undefined decision, malformed output, or a timeout
blocks the operation. There is no Python fallback policy.

```sh
PYTHONPATH=operations python3 -m mac_env policy tools set brew:formula:vault --mode hold --reason "Keep infrastructure tooling stable"
PYTHONPATH=operations python3 -m mac_env policy tools set brew:formula:git --mode auto
PYTHONPATH=operations python3 -m mac_env policy tools remove brew:formula:git
```

`auto` can still be blocked by security, backup, disk, or adapter rules. `hold`
also blocks indirect changes and wins over a narrower `auto`. Unlisted tools
are `manual`. Exact pins are supported. Permanent security exceptions are
rejected.

## Python quality and tests

Python 3.11+ is required. Quality dependencies are isolated from runtime code.
Every Python function under `operations/`, including tests and development
scripts, must score at most **3** in Radon cyclomatic complexity and the pinned
cognitive-complexity implementation. Ruff checks Python style, imports and
McCabe complexity. CI enforces all three checks without suppressions.

```sh
python3 -m venv operations/.cache/quality
operations/.cache/quality/bin/python -m pip install pip==26.3
operations/.cache/quality/bin/python -m pip install --group quality
operations/.cache/quality/bin/ruff check operations
operations/.cache/quality/bin/ruff format --check operations
operations/.cache/quality/bin/python operations/tools/check_complexity.py
python3 operations/tools/fetch_opa.py
operations/.cache/opa test operations/policy -v
PYTHONPATH=operations MAC_ENV_OPA="$PWD/operations/.cache/opa" operations/.cache/quality/bin/python -m unittest discover -s operations/tests -v
```

The complexity refactor reduced 39 violating functions to zero; 300 functions
now have maxima of 3 for each metric. Collectors and exports are separated;
Restic commands use an injected runner; validation is schema-driven; state
writes use one private atomic-write helper.

The latest local run passed 6 Rego tests and 56 Python tests. Those tests do
not prove that a live restore, Nix activation, or migration works.

## Remaining review findings

Production updates remain disabled. Candidate scan freshness/status and
vulnerability-threshold enforcement in Rego still need correction; the Nix
wrapper also needs its executable dependency paths fixed. Lower complexity
does not resolve these previously reported deployment blockers.

## Recovery boundaries

Nix rebuilds declared software and configuration. Documents, Git working trees,
and 1Password data need separate recovery. A generation does not reinstall
macOS or firmware. Full-disk recovery stays a manual Recovery procedure.

## Required agent boundary and new toolchains

All agent execution must use NVIDIA OpenShell, including work on this project.
Read [AGENTS.md](AGENTS.md) and the
[agent security plan](AGENT_SECURITY_PLAN.md) before running commands. The Python
and quality commands above belong inside the verified sandbox. Native macOS
activation commands are operator-only; they are not an agent host-shell exception.

OpenShell 0.1.9 is installed and its local gateway and provider-free bootstrap
sandbox passed authentication, isolation and denial checks. This does not confine
existing agent applications or attest this desktop chat's separate tools.
HOME inventory and agent migration remain pending. Julia, Zig, Rust and LuaJIT
are planned, with package ownership and Darwin/Linux ARM64 smoke tests required
before activation. The plan contains ordered tasks, inventory fields and the
prompt for the faster execution model.
