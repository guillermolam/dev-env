---
name: platform-remediate-cve
description: Use when removing a CVE or CWE from this personal platform. A network deny is not the fix. Does not ask the operator unless the host is under active exploitation.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Remove a CVE or CWE from this personal platform.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

The advisory id and the pin or function are named. The pin moved or the function changed. Where a local test can express the bug, it fails before the fix and passes after. Vulnix or the test output is recorded. Python stays at cyclomatic and cognitive complexity 3 or less. A network deny was not used as the patch.

## Proceed

Patch the pin or the function, test, and hand a green generation to deploy.

## Stop

Wake the operator when the vulnerable pin is under active exploitation on this machine, or the only fix drops the OpenShell fence.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`. Then read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail-review/SKILL.md` on the diff.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/bug-fix.md`.

