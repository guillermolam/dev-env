# User environment via home-manager. Deliberately does NOT manage ~/.zshrc, ~/.gitconfig or ~/.ssh:
# those were restored by hand from dotfiles-backup and are owned outside Nix for now.
{ pkgs, user, ... }:
{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    nil # Nix language server
    nixfmt # Nix formatter (also `nix fmt`)
    nix-tree # inspect closures
  ];

  # direnv + nix-direnv: per-project `use flake` environments.
  # Integration is added manually in ~/.zshrc (home-manager does not own that file).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false;
  };

  programs.home-manager.enable = true;
}
