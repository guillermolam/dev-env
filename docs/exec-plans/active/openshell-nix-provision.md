# Exec plan: OpenShell Nix provision + start

Status: active  
Opened: 2026-11-21  
Goal: declare OpenShell 0.1.9 in the flake and give the operator a
`--confirm` script that provisions certs/config and starts the gateway
LaunchAgent without Homebrew.

## Non-goals

- Migrating every desktop agent (T17)
- Service-account split / root LaunchDaemon
- Changing compute driver to VM (optional later)
- Agent-owned `launchctl` or `darwin-rebuild`

## Change set

| Artefact | Role |
| --- | --- |
| `homelab/openshell-package.nix` | Pinned CLI + gateway + prover + VM driver |
| `home/openshell.nix` | HM package + LaunchAgent when `runtimes.openshell` |
| `scripts/openshell-provision.sh` | status / provision / start / stop / restart |
| `docs/openshell/PROVISION.md` | Operator runbook |
| flake / Makefile / AGENTS.md | Wire package and commands |

## Verification

```bash
DEVENV_USER="$USER" nix build --impure --out-link result-openshell '.#openshell'
./result-openshell/bin/openshell --version
make openshell-status
make openshell-provision
make openshell-start
openshell status && openshell whoami
```

## Status honesty

Implemented in tree ≠ package built ≠ gateway running ≠ controller sandbox ready.
