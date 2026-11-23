# Cloudflare ops — inspected 2026-11-22

No secret values belong in this file.

## Host facts

| Item | Observed |
| --- | --- |
| `nix` | `/nix/var/nix/profiles/default/bin/nix` |
| `op` | `/opt/homebrew/bin/op` |
| `wrangler` | `/opt/homebrew/bin/wrangler` |
| `cloudflared` | `/opt/homebrew/bin/cloudflared` |
| `launchctl` | `/bin/launchctl` |
| Tunnel token | `~/.cloudflared/sunshine-tunnel.token`, mode `0600`, uid of the console user |
| Other cloudflared dirs | absent: `~/Library/Application Support/cloudflared`, `/usr/local/etc/cloudflared`, `/etc/cloudflared` |
| Daemon plist | `/Library/LaunchDaemons/systems.determinate.nix-daemon.plist` |
| Daemon program | `/usr/local/bin/determinate-nixd daemon` |
| Daemon sockets | `/var/run/nix-daemon.socket` and `/var/run/determinate-nixd.socket` |
| nix-darwin sudoers | `/etc/sudoers.d/10-nix-darwin-extra-config` keeps `TERMINFO` and `TERMINFO_DIRS` for root and `%admin` |
| Daemon NOPASSWD rule | absent |
| Flake Cloudflare packages | absent. `homelab.cloudflare.enable` is false. `zone` and `tokenItem` are null |
| 1Password Environment | `mac-env-offsite` (`5jqdtvndl7342gn7u6nhfaqz7q`) is the restic scope. Secrets were not populated. It is not the Cloudflare scope |
| Legacy Wrangler OAuth | `scripts/r2-token-to-rclone.sh` reads `oauth_token` from the Wrangler config. Unattended Cloudflare calls use `op run` instead of extending that read |

## Commands that stay unapplied until shown

Daemon, one time, native prompt:

```sh
env -u OP_SERVICE_ACCOUNT_TOKEN -u CLOUDFLARE_API_TOKEN \
  sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
```

No-TTY native dialog:

```sh
osascript -e 'do shell script "/bin/launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist" with administrator privileges'
```

Verify:

```sh
nix store info --store daemon
```

User builds, after the daemon answers:

```sh
nix build --impure nixpkgs#cloudflared
nix build --impure nixpkgs#wrangler
```

Activation, only after the package diff is shown:

```sh
sudo darwin-rebuild switch --impure --flake .#mac-studio
```

## Rejected

- `sudo -n` for the one-time daemon start
- `sudo -S`
- A 1Password item that holds the macOS login password
- `OP_SERVICE_ACCOUNT_TOKEN` or `CLOUDFLARE_API_TOKEN` in the privileged environment
- `NOPASSWD` for `/bin/sh`, `/bin/bash`, `/bin/zsh`, `/bin/launchctl`, `/usr/sbin/installer`, or `darwin-rebuild`
- Writing the tunnel token, the API token, or the service-account token into Git or the Nix store
