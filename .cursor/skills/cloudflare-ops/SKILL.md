---
name: cloudflare-ops
description: >
  Use when operating Cloudflare on this Apple Silicon mac-studio: Wrangler,
  cloudflared, R2, a Cloudflare API token, nix-darwin Cloudflare packages, or
  the Determinate Nix daemon. Separates a read-only 1Password service account
  from macOS administrator authorization. Shows privileged commands before
  applying them.
---

# Cloudflare ops

Read [reference.md](reference.md) before changing this Mac. Inspect the live
paths named there. Show every privileged command and file change in the
reply, then wait. Apply a command only after it was shown.

## Two paths

Path 1 is application secrets. Path 2 is macOS authorization. Do not mix them.

Never retrieve or store my macOS login password through 1Password for use with `sudo -S`. Keep the 1Password service-account token out of the privileged environment.

### Path 1 — read-only 1Password

Use a read-only 1Password Service Account for application secrets. Scope it to
a dedicated vault or Environment. The restic Environment `mac-env-offsite` is
not that scope.

Unattended Wrangler commands that need a Cloudflare API token use `op run`
with masking left on. Do not pass `--no-masking`. The token enters the child
environment as `CLOUDFLARE_API_TOKEN`. It does not appear in Git, the Nix
store, command arguments, or logs.

```sh
op run --env-file="$HOME/.config/cloudflare-ops/env" -- wrangler whoami
```

The env file lists variable names. It does not contain token values. The
service-account token is `OP_SERVICE_ACCOUNT_TOKEN` in that user environment
only.

Preserve cloudflared’s existing user-owned 0600 token file at
`~/.cloudflared/sunshine-tunnel.token`. Do not read it, print it, copy it, or
replace it during this migration.

### Path 2 — macOS authorization

Privileged operations use the native administrator prompt. Do not use
`sudo -n`. Do not use `sudo -S`.

The one-time daemon command, after it has been shown, is:

```sh
env -u OP_SERVICE_ACCOUNT_TOKEN -u CLOUDFLARE_API_TOKEN \
  sudo /bin/launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
```

When this shell has no TTY, show and then run the native dialog form. The
script string is only that launchctl argv:

```sh
osascript -e 'do shell script "/bin/launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist" with administrator privileges'
```

The launchd plist stays root-owned at that path. Do not copy it into the repo
or the Nix store.

If agents must repeat that command unattended, propose this sudoers rule and
wait. It names one executable and one argument list. It is not installed by
this skill.

```sudoers
Cmnd_Alias NIX_DAEMON_BOOTSTRAP = /bin/launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
%admin ALL=(root) NOPASSWD: NIX_DAEMON_BOOTSTRAP
Defaults!NIX_DAEMON_BOOTSTRAP !env_keep
```

Reject broad permissions for shells, `launchctl`, `installer`, or `darwin-rebuild`. A rule is broad when the executable is a shell, when `launchctl` has no subcommand and arguments, when the target is `installer`, or when the target is `darwin-rebuild`. Wildcards and `NOPASSWD: ALL` are rejected.

## Order

1. Inspect reference.md paths. Record modes and owners. Do not print secret bytes.
2. Show the privileged commands and the diff.
3. After the administrator authorizes the daemon command, verify with `nix store info --store daemon`.
4. Build and test Cloudflare Nix packages as the normal user. `wrangler` and `cloudflared` are Homebrew today. Add the nixpkgs attributes only in a shown diff. Run the builds without `sudo`.
5. Ask for native administrator approval for the reviewed nix-darwin activation. The activation command is shown first:

```sh
sudo darwin-rebuild switch --impure --flake .#mac-studio
```

6. Remove legacy Homebrew `wrangler` and `cloudflared` only after the Nix binaries run and the 0600 cloudflared token file is unchanged. Leave `op` on Homebrew until a separate reviewed pin exists.
