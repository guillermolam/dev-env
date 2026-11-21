# Provision OpenShell from this flake

Operator runbook. No Homebrew. Pinned OpenShell **0.1.9** via
`homelab/openshell-package.nix`. LaunchAgent label:
`sh.mac-environment.openshell-gateway`.

## Why

The Homebrew service exited when Docker was briefly unavailable and
auto-detection then reported `no compute driver configured` for hours.
This path sets `compute_driver = "docker"` explicitly, uses
`KeepAlive = true`, and owns state under
`~/.local/state/mac-environment/openshell`.

## Prerequisites

- Apple Silicon Mac, Determinate Nix (`nix-daemon` running)
- OrbStack (or Docker) running so a docker socket exists
- You are the admin user for this machine

If `nix build` fails with `cannot connect to socket ... nix-daemon`:

```sh
sudo launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
# or, if already registered:
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

## One-shot (no darwin-rebuild)

```sh
# Read-only
make openshell-status

# Build package, generate certs, write gateway.toml + LaunchAgent plist
make openshell-provision

# Bootstrap LaunchAgent, register CLI, wait for status/whoami
make openshell-start
```

Equivalent:

```sh
sh scripts/openshell-provision.sh status
sh scripts/openshell-provision.sh provision --confirm
sh scripts/openshell-provision.sh start --confirm
```

Stop / restart:

```sh
make openshell-stop
make openshell-restart
```

## Declared install (after review)

`homelab.runtimes.openshell = true` installs the package and the same
LaunchAgent via Home Manager (`home/openshell.nix`). Activation still
requires operator:

```sh
DEVENV_USER="$USER" nix build --impure '.#darwinConfigurations.mac-studio.system'
# review, then:
sudo darwin-rebuild switch --impure --flake .#mac-studio
```

Certs are **not** created by Home Manager. Run `make openshell-provision`
once after activation (or before start).

## Conflict with Homebrew OpenShell

`start` boots out `sh.brew.openshell` if it is loaded so port `17670`
is free. Prefer removing the Homebrew formula after this path works:

```sh
brew services stop openshell   # if still installed
brew uninstall openshell       # operator choice
```

## Layout

| Path | Role |
| --- | --- |
| `result-openshell/` | `nix build` out-link (gitignored) |
| `~/.config/mac-environment/openshell/gateway.toml` | Gateway config (`compute_driver = "docker"`) |
| `~/.local/state/mac-environment/openshell/tls/` | mTLS + JWT material |
| `~/.local/state/mac-environment/openshell/logs/` | gateway stdout/stderr |
| `~/Library/LaunchAgents/sh.mac-environment.openshell-gateway.plist` | LaunchAgent |
| `~/.config/openshell/gateways/openshell/mtls/` | CLI client certs (NVIDIA layout) |

## Next: controller sandbox

When `openshell status` and `openshell whoami` succeed, create the
controller sandbox per [CREATE.md](CREATE.md).
