---
name: platform-deploy
description: Use when deploying this personal platform. Builds darwinConfigurations.mac-studio and activates it when the stop set is clear. Does not ask the operator.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Deploy this personal platform. Build the nix-darwin generation and activate it when the stop set is clear.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

- `DEVENV_USER="$USER" nix build --impure '.#darwinConfigurations.mac-studio.system'` exits 0 and the store path is recorded.
- The stop set was checked against that store path and is clear.
- The generation number after activation is recorded. If no fail-closed apply gate exists yet, write that gate so it refuses on the stop set, then use it. Do not flip production apply off its evidence rules to get a green result.
- `make doctor` is recorded. Incomplete collectors stay gaps.

## Proceed

A red build, a hold, or a missing package is yours. Fix the owning file and retry.

## Stop

Wake the operator if activation would boot an unverified store path, the rollback generation is missing, or the evidence that authorizes the switch is malformed. A missing offsite token is a recorded gap, not a wake-up.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`. Use ultra before any request to drop a hold.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/shipping.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/babysit.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/autopilot-stack.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/autonomous-run.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/autopilot-full.md`, and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/pause-safely.md`.

