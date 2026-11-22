# Trivy on the nix-darwin flake

## Goal

`nix build .#trivy` produces the scanner. Home Manager installs it on the next activation.

## Done when

The package builds. `darwin-rebuild switch` has not been run.
