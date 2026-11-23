---
name: platform-remediate-backup
description: Use when capturing and verifying a restic backup of this personal platform. Exit 3 wakes the operator. A missing cloud token is a recorded gap.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Capture and verify a backup of this personal platform.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

A verified snapshot id is recorded. The password file is a path outside Git, mode 0600, and its contents were not printed. The offsite path is not under `local-restic`. A disposable `recovery-drill` is labeled as a drill and is not checklist A8.

## Proceed

Run status and `make offsite-preflight`. Take the backup when the destination and password path already exist. A missing R2 token stays a gap. Do not claim offsite.

## Stop

restic exit 3, a partial snapshot, or a password file that would be committed is a data-integrity failure. Wake the operator. Write no manifest. Keep the previous manifest.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/pause-safely.md` before any restore. Restore belongs to `platform-remediate-partial`.

