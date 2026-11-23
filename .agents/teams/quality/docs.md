---
name: platform-quality-docs
description: Use when documenting a change to this personal platform. Keeps implemented, tested, installed, and operational distinct.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Document a change to this personal platform so a later team can act on it.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

The doc matches the code. `implemented`, `tested`, `installed`, and `operational` are not swapped. `AGENTS.md` stays under 150 lines. A secret does not appear.

## Proceed

Write the missing page. Update PLAN, FEATURES, and TASKS when status changes.

## Stop

Wake the operator if the doc would have to hide a fence drop or a failed integrity check to look finished.

## Ponytail

Level lite. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`. Do not delete a required warning to shorten the page.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/authoring-a-skill.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/playbooks/visual-parity.md`, `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/technical-writing/SKILL.md`, and `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/unslop/SKILL.md`. visual-parity is `n/a` unless a rendered surface exists.

