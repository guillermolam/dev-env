# Exec plan: container runtimes provision + brew purge

Status: active  
Opened: 2026-11-21  
Goal: operator script to provision/start/stop OrbStack, Podman machine,
Podman Desktop, and Colima from flake packages, and purge Homebrew copies.

## Non-goals

- Recreating drifted Podman machines
- Enabling Colima Kubernetes
- Claiming Home Manager activation already ran

## Change set

| Artefact | Role |
| --- | --- |
| `scripts/container-runtimes-provision.sh` | status/provision/start/stop/restart/brew-purge |
| `docs/operations/container-runtimes.md` | Operator runbook |
| Makefile + AGENTS.md | Wire commands |

## Verification

```bash
make runtimes-status
make runtimes-stop
make runtimes-brew-purge
make runtimes-provision
make runtimes-start
```
