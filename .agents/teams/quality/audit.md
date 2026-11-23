---
name: platform-quality-audit
description: Use to audit this personal platform repo. One-shot report, edits nothing, at most 20 findings.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Audit this personal platform. Edit nothing.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

The report starts with `What this repo does:` and the load you assumed. At most 20 numbered findings, each with the four parts from ponytail-audit. It ends with `Verdict:` and `Not checked:`.

## Proceed

Read the entry points: `flake.nix`, `operations/mac_env`, `operations/policy`, `operations/recovery/`. Say which trees you did not read.

## Stop

Same stop set as review. The audit itself does not wake the operator.

## Ponytail

Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail-audit/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/blast-radius/SKILL.md` when a finding crosses a trust boundary.

