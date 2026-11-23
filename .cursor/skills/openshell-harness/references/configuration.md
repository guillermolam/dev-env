# OpenShell configuration

Read this when configuring the gateway, policy, sandbox, or credentials.
The procedure and the fence are in `SKILL.md`. This file is the map of
files and commands on this Mac.

## Pin

| Piece | Where |
| --- | --- |
| Version | 0.1.9, `homelab/openshell-package.nix` |
| CLI, gateway, VM driver, prover | same release tarball set |
| Home Manager | `home/openshell.nix`, enabled when `homelab.runtimes.openshell` is true |
| LaunchAgent label | `sh.mac-environment.openshell-gateway` |
| Program | `${openshell}/libexec/openshell-gateway-service` |
| Compute driver | `OPENSHELL_COMPUTE_DRIVER=docker` and `compute_driver = "docker"` in `gateway.toml` |
| Docker socket | `unix://$HOME/.orbstack/run/docker.sock` when OrbStack is the engine |

Upgrade the gateway, the supervisor, and the SDK as one release. A newer CLI
against an older gateway is not a configuration.

## Paths

| Path | Role |
| --- | --- |
| `~/.config/mac-environment/openshell/gateway.toml` | Gateway config |
| `~/.local/state/mac-environment/openshell/tls/` | mTLS and JWT material |
| `~/.local/state/mac-environment/openshell/logs/` | Gateway logs |
| `~/Library/LaunchAgents/sh.mac-environment.openshell-gateway.plist` | User LaunchAgent |
| `~/.config/openshell/gateways/openshell/mtls/` | CLI client certs |

Mode on the state and config directories is `0700`. Cert material is created
by `make openshell-provision`, not by Home Manager.

## Commands

```sh
make openshell-status
sh scripts/openshell-provision.sh provision --confirm
sh scripts/openshell-provision.sh start --confirm
make openshell-stop
make openshell-restart
```

`start` boots out `sh.brew.openshell` when that label is loaded so port
`17670` has one listener. Uninstall the Homebrew formula only after
`openshell status` and `openshell whoami` succeed from the Nix binary.

Declared install, shown before it runs:

```sh
DEVENV_USER="$USER" nix build --impure '.#darwinConfigurations.mac-studio.system'
sudo darwin-rebuild switch --impure --flake .#mac-studio
```

## Sandbox

Policy file: `docs/openshell/policy-controller.yaml`. Name:
`mac-env-controller`. Create command and upload list: `docs/openshell/CREATE.md`.

The policy includes the workdir, a short read-only set, and read-write
`/tmp` plus `/dev/null`. Landlock compatibility in that file is
`best_effort`. Moving it to `hard_requirement` is a harden-team change with
the negative probes still passing.

`policy set` replaces the entire base policy. Keep filesystem, Landlock, and
process in the replacement. `policy.local` may add one network rule. It
cannot add tcp, tls skip, GraphQL, MCP, credentials, or path selectors.

Upload the repo and the already-hashed `opa` and `restic` binaries. Do not
give the sandbox network so it can download them. Do not mount HOME,
`/Users`, `/`, the Docker socket, the SSH agent, Keychain, vault storage, or
gateway admin credentials.

Acceptance probes from CREATE.md: `id`, Python ≥ 3.11, `opa version` 1.22.4,
`restic version`, and a failed connect to `1.1.1.1:443`. Record policy hash,
image digest, and enforcement in a receipt. No secret values.

## Credentials

A network allow is not a credential. The supervisor injects a credential
only after the allow. The sandbox sees a stable placeholder for a human
OAuth refresh. Refresh material stays on the gateway. A SPIFFE grant sends
the sandbox JWT-SVID as the client assertion. A SPIFFE exchange keeps the
user subject token at the gateway and injects only the final bearer.

The workload does not attach a provider. Attaching one, or flipping
`enforce` to `audit`, drops the fence and wakes the operator.

## What is already true

The package, the Home Manager module, the provision script, and a controller
sandbox receipt from 2026-11-21 exist. A receipt is not proof the gateway is
running in this session. `make openshell-status` is the live check.
