---
name: platform-harden
description: Use when tightening OpenShell or host controls on this personal platform. Moves audit to enforce, adds pins, removes mounts. Does not ask the operator.
---

Read `.agents/shared/boundary.md` before anything else.
Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md` before spawning any subagent. The first line of that kickoff is `Read /Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/poteto-mode/worker.md before anything else.`

Autonomy: do not ask the operator. Proceed. Wake the operator only for a fatal error, a panic, a cyberattack, a data-integrity failure, or a change that drops the OpenShell fence.

OpenShell fence: the host CLI, SDK, and TUI are transport. The workload runs in the sandbox. The supervisor intercepts the proxied API after allow and before credential injection.

Poteto override: on this personal platform, deploy, activation, and restore into a new empty directory are normal work. Stop only for the autonomy sentence above. worker.md stops for a deploy only outside this platform.

## Goal

Tighten an existing control on this personal platform. Do not add a product.

## Platform

This personal platform is the Apple Silicon `mac-studio` in this repo: `darwinConfigurations.mac-studio`, Home Manager, the `mac-env` controller, OPA, OpenShell 0.1.9, restic, and the homelab modules that are still disabled.

## Done when

A control moved in the safe direction: `audit` to `enforce`, Landlock toward `hard_requirement`, a binary pin added, or a mount removed. The negative probe still denies. `policy set` kept filesystem, Landlock, and process.

## Proceed

Draft at most one added network rule. Apply a narrower rule. A denied egress you still need becomes a drafted rule, then a reload. It is not a question.

## Stop

Wake the operator before any of these land: `tls: skip`, a new credential, `enforce` switched back to `audit`, a HOME mount, the Docker socket, or a provider attached by the workload. Those drop the fence. A network allow does not attach a credential. Human OAuth keeps the refresh token at the gateway. A SPIFFE grant uses the sandbox JWT-SVID as the client. A SPIFFE exchange keeps the user subject token at the gateway and injects only the final bearer.

## Ponytail

Level full. Read `/Users/glam/.claude/plugins/cache/ponytail/ponytail/5.3.3/skills/ponytail/SKILL.md`.

## Poteto

Read `/Users/glam/.claude/plugins/cache/cursor-plugins/pstack/0.15.43/skills/architect/SKILL.md` when the rule crosses a policy boundary.

