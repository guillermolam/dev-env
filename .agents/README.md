# Personal platform teams

These teams deploy, provision, configure, maintain, secure, harden,
troubleshoot, and remediate this personal platform. The platform is the Apple
Silicon `mac-studio` declared in this repo.

They do not ask the operator. They wake the operator only for a fatal error, a
panic, a cyberattack, a data-integrity failure, or a change that drops the
OpenShell fence. The contract is [shared/boundary.md](shared/boundary.md).

Quality reviews, audits, and docs. It does not take the operator's place. A
must-fix returns to the owning team.

| Team | Agent | Done looks like |
| --- | --- | --- |
| deploy | [teams/deploy/agent.md](teams/deploy/agent.md) | Green `darwinConfigurations.mac-studio` store path, stop set clear, generation recorded |
| provision | [architect](teams/provision/architect.md), [nix](teams/provision/nix.md), [helm](teams/provision/helm.md), [quadlet](teams/provision/quadlet.md), [opentofu](teams/provision/opentofu.md), [bash](teams/provision/bash.md) | One tool chosen, diff only in that tree |
| configure | [teams/configure/agent.md](teams/configure/agent.md) | Non-secret flake, Home Manager, homelab, or env example; `nix flake check` exits 0 |
| maintain | [teams/maintain/agent.md](teams/maintain/agent.md) | Pins moved together; holds kept; named generations not collected |
| secure | [teams/secure/agent.md](teams/secure/agent.md) | Real evidence or an explicit gap; healthy baseline only |
| harden | [teams/harden/agent.md](teams/harden/agent.md) | A control tightened; negative probes still deny |
| troubleshoot | [teams/troubleshoot/agent.md](teams/troubleshoot/agent.md) | Root cause, file and line, owning team; no activation |
| remediate | [full](teams/remediate/full-recovery.md), [partial](teams/remediate/partial-recovery.md), [cve](teams/remediate/cve.md), [backup](teams/remediate/backup.md) | Rebuild after erase, empty-dir restore, advisory removed, verified snapshot |
| quality | [review](teams/quality/review.md), [audit](teams/quality/audit.md), [debt](teams/quality/debt.md), [docs](teams/quality/docs.md), [meta](teams/quality/meta.md) | Ponytail report, ledger, or honest doc |

## Tool split

Delegation is `homelab/provision-plan.json` evaluated by `next_action`. Nix is
first. Helm, Kubernetes, Podman, CRI-O, Cilium, OpenTofu, and operator scripts
run only when that function returns `allowed`.

## Pairing

Ponytail, installed copy: `ponytail/SKILL.md`, `ponytail-review/SKILL.md`,
`ponytail-audit/SKILL.md`, `ponytail-debt/SKILL.md`, `ponytail-gain/SKILL.md`,
`ponytail-help/SKILL.md`.

Poteto playbooks, each owned by at least one agent: `investigation`, `bug-fix`,
`perf-issue`, `hillclimb`, `runtime-forensics`, `trace-forensics`, `feature`,
`refactoring`, `prototype`, `visual-parity`, `authoring-a-skill`, `eval`,
`babysit`, `shipping`, `autonomous-run`, `autopilot-full`, `autopilot-stack`,
`session-pickup`, `pause-safely`, `multi-phase-plan`, `worktree-cleanup`,
`opening-a-pr`.

`figure-it-out`, `interrogate`, `architect`, `unslop`, `technical-writing`, and
`blast-radius` are paired from the same pstack tree.

## Each step

`.cursor/hooks.json` runs `.cursor/hooks/step-alert.py` after every tool step, after a failed tool step, and when a subagent stops. The script appends one secret-free line to `.agents/runs/steps.jsonl` and alerts this agent. Adjust a team, agent, skill, command, or example only when that step contradicted a written Done when. One adjustment. Then stop. The ledger is local and gitignored.

Check: `make check-agents`.
