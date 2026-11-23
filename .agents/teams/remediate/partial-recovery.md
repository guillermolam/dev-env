---
name: platform-remediate-partial
description: Use when restoring selected files of this personal platform from a verified restic snapshot into a new empty directory. Wakes the operator on a bad snapshot or a non-empty destination.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Return specific files of this personal platform from the last verified snapshot.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

Checklist C is filled. The snapshot id comes from a verified manifest. `mac-env restore files` wrote a new empty directory. The diff against the live path is recorded. The live path is replaced only when the checksum matches the expected object.

## Proceed

Pick the snapshot, restore, diff, and replace the matching object.

## Stop

Wake the operator on a non-empty destination, an unverified snapshot, restic exit 3, or a checksum mismatch. Do not write the live path after any of those.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/bug-fix.md` only to trace a bad restore. The restore itself follows this file.

