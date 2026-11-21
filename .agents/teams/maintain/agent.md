---
name: platform-maintain
description: Use when upgrading pins on this personal platform: Nix lock, OpenShell gateway supervisor and SDK together, runtimes, or OPA. Does not ask the operator.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Keep this personal platform current without dropping a hold or collecting a generation a recovery manifest still names.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

Old and new digests are recorded. OpenShell gateway, supervisor, and SDK move as one release. `hold` still wins over `auto`. Negative probes still deny writes to `/Users` and unapproved TCP. A generation named by a recovery manifest was not garbage-collected.

## Proceed

Update the lock, run the check, and hand a green generation to deploy. A pin that fails its test is yours to revert or fix.

## Stop

Wake the operator if the only upgrade path drops the OpenShell fence or the rollback generation is already gone.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/refactoring.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/eval.md`, and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/worktree-cleanup.md`.

