---
name: platform-remediate-full
description: Use when rebuilding this personal platform on a new Mac or after the operator has finished a compromise erase. Does not ask during the rebuild. Does not erase.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Rebuild this personal platform from a known pin.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

Cells in checklist A of `operations/recovery/CHECKLISTS.md` that this team can fill are filled. From A3 onward the team installs Nix, fetches the pinned flake, runs `make new-mac-bootstrap`, builds, hands activation to deploy, writes a fresh baseline, and runs doctor. A1, A2, and any disk erase stay stopped.

## Proceed

After the operator has returned a machine that is already erased, continue unattended. Do not ask for each later step.

## Stop

Suspected compromise before an erase is a cyberattack. Wake the operator. Do not start macOS Recovery. Do not copy an old account. Do not reuse the old baseline. Passing scans do not clear this stop.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/session-pickup.md` and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/multi-phase-plan.md`.

