# Mac Studio (Apple Silicon). System-level config via nix-darwin.
{
  self,
  user,
  pkgs,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Determinate Nix owns the Nix install, daemon and /etc/nix/nix.conf.
  # nix-darwin must not manage Nix, or activation aborts.
  nix.enable = false;

  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  # Shell integration so Nix-installed tools are on PATH in every zsh.
  programs.zsh.enable = true;

  # Kolide: "macOS Firewall Is Not Enabled"
  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
  };

  # Kolide: "File Extensions Are Not Visible in Finder"
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.finder.AppleShowAllExtensions = true;

  # Homebrew stays managed by ~/Brewfile for now (not declared here on purpose).
  # Touch ID for sudo (writes /etc/pam.d/sudo_local, which survives macOS updates).
  security.pam.services.sudo_local.touchIdAuth = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;
}
