# User-level Objective-See tools: standalone GUI scanners and CLI monitors.
# Privileged system-extension tools are copied into /Applications by the host
# module; see hosts/mac-studio/objective-see.nix.
{
  lib,
  pkgs,
  homelab,
  ...
}:
let
  objectiveSee = import ../homelab/objective-see-package.nix { inherit pkgs lib; };
in
{
  home.packages = lib.mkIf homelab.objectiveSee.enable (
    builtins.attrValues (objectiveSee.userApps // objectiveSee.cliTools)
  );
}
