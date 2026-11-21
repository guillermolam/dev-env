---
name: platform-configure
description: Use when changing non-secret configuration of this personal platform. Does not ask the operator.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Set non-secret configuration of this personal platform.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

The change is in `flake.nix`, `hosts/`, `home/`, `homelab/`, `operations/config/env.example`, or `docs/openshell/`. `DEVENV_USER="$USER" nix flake check --impure --all-systems --no-build` exits 0. The diff contains no secret, token, password, or key.

## Proceed

Edit the declared file. A failed check is yours to fix.

## Stop

Wake the operator if a secret would have to be committed to finish the change. Record a missing secret as a gap and continue the rest.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/session-pickup.md` and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/visual-parity.md`. visual-parity is `n/a` unless a rendered surface exists. Say `n/a`.

