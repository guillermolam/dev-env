# Container runtimes (OrbStack, Podman, Colima)

Operator runbook. Desired state matches `home/container-runtimes.nix`.
Packages come from the flake only (`homelab/runtime-packages.nix`, nixpkgs
`colima` / `incus.client`). No Homebrew install or purge path.

## Headless contract (Context7 / upstream)

| Runtime | How | Do not |
| --- | --- | --- |
| OrbStack | `orb start` / `orbctl start`; `setup.use_admin=false` | Open `OrbStack.app`; admin GUI prompts |
| Podman | `podman machine init/start --update-connection=false` | TTY prompts when connection unset |
| Colima | `colima start` with flags or existing yaml | `--edit` |
| Podman Desktop | Not started here (Electron GUI; EPIPE if stdout closed) | `nohup podman-desktop` |

Sources: [OrbStack headless](https://docs.orbstack.dev/headless),
[Colima automation](https://github.com/abiosoft/colima/blob/main/skills/references/automation.md),
[podman machine --update-connection](https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html).

## Declared ceilings

| Runtime | Resources | Notes |
| --- | --- | --- |
| OrbStack | 4 CPU, 8192 MiB | LAN expose off; `docker.set_context true` |
| Podman machine `podman-machine-default` | 2 CPU, 4096 MiB, 60 GiB | rootless, libkrun; mount `~/Git` |
| Colima profile `incus` | 2 CPU, 4 GiB, 60 GiB | runtime `incus`, vz + virtiofs; mount `~/Git` |

## Commands

```sh
make runtimes-status
make runtimes-provision   # nix build + configs
make runtimes-start       # headless CLI only
make runtimes-stop
```

Binary resolution order: `result-<attr>/bin` → `~/.nix-profile/bin` →
PATH entries whose realpath is under `/nix/store`. Homebrew Cellar/Caskroom
paths are refused.

## New Mac

1. Determinate Nix daemon running
2. `make runtimes-provision && make runtimes-start`
3. `make openshell-provision && make openshell-start`
