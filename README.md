# dev-env
Home manager NIX-first environment bootstrapper - Provision and configures environments deterministically for Windoes/WSL, Linux, MacOs

## macOS (nix-darwin + home-manager)

Configuration: `darwinConfigurations.mac-studio` (aarch64-darwin), on Determinate Nix (`nix.enable = false`).

The macOS username is **not** in the repo. The flake reads it at evaluation time, so every command needs `--impure`:
`DEVENV_USER` if set, otherwise `SUDO_USER` (the user running `sudo`), otherwise `USER`.

```sh
# first activation
sudo nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake ~/code/dev-env#mac-studio
# afterwards
sudo darwin-rebuild switch --impure --flake ~/code/dev-env#mac-studio
```

CI (`.github/workflows/nix.yml`) evaluates and builds the system on macOS with `DEVENV_USER` from a repository secret.

Homebrew apps are still declared in `~/Brewfile`; dotfiles (zsh, git, ssh) are not managed by home-manager yet.
