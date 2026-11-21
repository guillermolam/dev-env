---
name: platform-troubleshoot
description: Use when this personal platform fails. Finds the root cause and names the owning team. Does not activate, restore, or ask the operator.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Explain a failure of this personal platform and name the repair. Do not activate, restore, rotate, or erase.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

Hypotheses are ranked. The probe that separated them was run. The root cause cites a file and line. The owning verb team is named. If the probe did not run, the outcome is `outcome_unknown`. An uncertain mutation is not retried.

## Proceed

A red test, a crash you can reproduce, or a slow path is yours. Hand the patch to the owning team.

## Stop

Wake the operator when the failure is a panic loop that survives one restart, a kernel panic, or evidence of a cyberattack or a torn write.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/investigation.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/bug-fix.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/runtime-forensics.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/trace-forensics.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/perf-issue.md`, and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/hillclimb.md`.

