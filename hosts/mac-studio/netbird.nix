# Official NetBird macOS client, pinned to the latest GitHub release.
# Checked 2026-11-20: v0.83.1, not a prerelease, published 2026-11-13.
# nixpkgs in this flake only has netbird 0.82.0, built from source, and that
# build rewrites the daemon socket for systemd. It is not the macOS client.
#
# The signed arm64 pkg installs /Applications/NetBird.app, links
# /usr/local/bin/netbird, and its own postinstall registers the root daemon.
{
  pkgs,
  lib,
  homelab,
  ...
}:
let
  netbird = import ../../homelab/netbird-package.nix { inherit pkgs; };
  inherit (netbird) version;
  pkg = netbird.installer;
in
{
  system.activationScripts.postActivation.text = lib.mkIf homelab.runtimes.netbird ''
    installed=$(/usr/sbin/pkgutil --pkg-info io.netbird.client 2>/dev/null | /usr/bin/awk '/^version: / { print $2; exit }')
    if [ "$installed" != "${version}" ]; then
      /usr/sbin/installer -pkg ${pkg} -target /
    fi
  '';
}
