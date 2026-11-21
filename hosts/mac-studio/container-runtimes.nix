{ lib, pkgs, homelab, ... }:
let
  previousRuntimePackages = previous: import ../../homelab/runtime-packages.nix {
    pkgs = previous;
    inherit lib;
  };
in
{
  nixpkgs.overlays = [
    (_: previous: previousRuntimePackages previous)
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "orbstack";

}
