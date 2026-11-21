---
name: openshell-harness
description: >
  Use when deploying, provisioning, configuring, maintaining, securing,
  hardening, troubleshooting, or remediating this personal platform
  (mac-studio, nix-darwin, OpenShell). Routes the work to .agents/teams
  and the OpenShell fence. The team proceeds. The operator is woken only
  for a fatal error, a panic, a cyberattack, a data-integrity failure, or
  a fence drop.
---

# OpenShell harness

Read `.agents/shared/boundary.md` and `.agents/README.md` before choosing a team.

This personal platform is the Apple Silicon `mac-studio` in this repo. The
teams under `.agents/teams/` do the work. Do not ask the operator. Wake the
operator only for a fatal error, a panic, a cyberattack, a data-integrity
failure, or a change that drops the OpenShell fence.

Pick one team from the table in `.agents/README.md`. Follow that agent's
`Done when`. Pair the edit with the Ponytail skill and the Poteto playbook
named in the agent file. Read those files. Do not invent a shorter workflow.

The host CLI, SDK, and TUI are transport. The workload runs in the sandbox.
The supervisor intercepts the proxied API after allow and before credential
injection. A failed sandbox call stops the task.

After every tool step the project hook `.cursor/hooks/step-alert.py` alerts you. Adjust one spec, skill, command, or example only when that step contradicted a Done when. Otherwise change nothing.

These files are specs. They have not activated this Mac.
