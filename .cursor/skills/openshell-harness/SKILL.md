---
name: openshell-harness
description: >
  Use when harnessing agents, managing platform teams, or configuring NVIDIA
  OpenShell on this mac-studio: gateway, supervisor, SDK pin, LaunchAgent,
  gateway.toml, policy, sandbox create, providers, or credentials. Use it
  whenever the user says agents, harness, sandbox, gateway, policy, or
  team, even if they do not name OpenShell. Includes the configuration
  steps, the fence, and which team owns the work.
---

# OpenShell harness

This skill is how agents on this Mac are managed and how OpenShell is
configured. A desktop chat is not a sandbox. Configuration that is only
implied gets invented: a HOME mount, a host fallback, a policy that drops
Landlock. Read the files below and follow the configuration order.

## Read first

1. `.agents/shared/boundary.md` — stop set and fence.
2. `.agents/README.md` — which team owns the work.
3. [references/configuration.md](references/configuration.md) when the task
   touches the gateway, LaunchAgent, `gateway.toml`, policy, a sandbox,
   a provider, or a credential.

Cloudflare tokens and the Determinate Nix daemon prompt are
`.cursor/skills/cloudflare-ops/SKILL.md`. Show that command before running it.
Do not use `sudo -n` or `sudo -S`.

## Upstream skills

These four skills are the `ai-openshell/openshell` tree at commit
`38c47412dd7e94b8efc44b128940e097590b7582`. Read the one that matches the
task. This file and `.agents/shared/boundary.md` win when an upstream example
disagrees. A HOME mount, `tls: skip`, a workload-attached provider, or a host
fallback is not a step on this Mac.

| Task | Read |
| --- | --- |
| CLI commands for sandbox, gateway, provider, policy | `.cursor/skills/openshell-cli/SKILL.md` |
| Policy YAML | `.cursor/skills/generate-sandbox-policy/SKILL.md` and its `examples.md` |
| Gateway or cluster health | `.cursor/skills/debug-openshell-cluster/SKILL.md` |
| Supervisor middleware | `.cursor/skills/debug-openshell-cluster/references/supervisor-middleware.md` |
| Attached-provider inference | `.cursor/skills/debug-inference/SKILL.md` |

Only `debug-openshell-cluster` has a `references/` directory. The other three
are a single `SKILL.md`, plus `examples.md` for policy generation.

## Manage the teams

Pick one team from `.agents/README.md`. Follow that file's Done when. Pair
the edit with the Ponytail skill and the Poteto playbook named there.

The teams proceed without asking. Wake the operator only for a fatal error,
a panic, a cyberattack, a data-integrity failure, or a change that drops the
OpenShell fence. `make check-agents` must keep passing.

After every tool step, `.cursor/hooks/step-alert.py` alerts you. Change a
spec, skill, command, or example only when that step contradicted a Done when.
The census board is `.cursor/hooks/census-board.py`. Workload A stays open
until its predicate is true. A `receipts/<step>-blocked*` file holds the stop
follow-up for that first open id.

## Configure OpenShell

Do this in order. Record gateway auth, sandbox id, image digest, policy
revision, and enforcement before any mutation. `audit` is not `enforce`.

1. Pin stays OpenShell 0.1.9 in `homelab/openshell-package.nix`. Gateway,
   supervisor, and SDK move together. The CLI, SDK, and TUI stay outside
   the sandbox.
2. Nix daemon must answer `nix store info --store daemon` before a build.
   If it does not, follow the cloudflare-ops skill and show the bootstrap
   command first.
3. `make openshell-status` is read-only. `make openshell-provision` and
   `make openshell-start` need `--confirm` inside the script. They write
   `gateway.toml` with `compute_driver = "docker"`, certs, and LaunchAgent
   `sh.mac-environment.openshell-gateway`.
4. Create or reuse `mac-env-controller` only from `docs/openshell/CREATE.md`
   and `docs/openshell/policy-controller.yaml`. Upload the project. Do not
   mount HOME, `/Users`, `/`, the Docker socket, the SSH agent, Keychain,
   vault storage, or gateway admin credentials.
5. Prove denial: protected directory and external TCP fail. Record the
   receipt with hashes and versions, not secret values.

`policy set` replaces the whole base policy. Keep filesystem, Landlock, and
process. A network allow does not attach a credential. Human OAuth keeps the
refresh token at the gateway. A SPIFFE grant uses the sandbox JWT-SVID. A
SPIFFE exchange keeps the user subject token at the gateway and injects only
the final bearer.

The workload cannot widen its own policy, attach a provider, or switch
`enforce` back to `audit`. `tls: skip` is a fence drop. A failed sandbox call
stops the task. It is not permission to use the host shell.

Home Manager activation and `darwin-rebuild` are shown before they run. Certs
are not created by Home Manager. Run `make openshell-provision` once after
activation. Remove Homebrew `openshell` only after `openshell status` and
`openshell whoami` succeed on the Nix path. Port `17670` belongs to one gateway.

## Status

Specs and the provision script exist. This chat is not an admitted sandbox.
Do not claim the gateway is operational from a file that has not been started.
