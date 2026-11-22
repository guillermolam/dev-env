# Objective-See tools on the nix-darwin flake

## Goal

All 15 Objective-See tools build from pinned, hash-verified latest upstream
releases (checked 2026-11-21 against objective-see.org/tools.html and GitHub
releases/latest). `homelab/objective-see-package.nix` packages 14 of them and
pins LuLu to 4.5.7 via `overrideAttrs` of the nixpkgs package (4.5.4).

- System-extension / privileged-daemon tools (LuLu, BlockBlock, OverSight,
  RansomWhere, ReiKey, DoNotDisturb, WhatsYourSign, TaskExplorer) are copied
  into /Applications by `hosts/mac-studio/objective-see.nix` at activation,
  gated on `homelab.objectiveSee.enable`.
- User-level scanners (KnockKnock, Netiquette, DHS, KextViewr) and CLI
  monitors (FileMonitor, ProcessMonitor, DNSMonitor) install through Home
  Manager (`home/objective-see.nix`).

## Done when

Every package builds with `nix build`, `nix flake check --impure
--all-systems --no-build` passes, and the mac-studio darwinConfiguration
evaluates. `darwin-rebuild switch` has not been run; first launch of each
Installer.app (privileged daemon registration) stays a manual operator step.
