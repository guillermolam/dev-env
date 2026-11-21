# OpenShell work sandbox proposal

Status: implemented live as `mac-env-controller` (2026-11-21).
See `receipts/openshell-controller-2026-11-21.json`.

Operator create steps (exact CLI): [CREATE.md](CREATE.md).
Policy draft: [policy-controller.yaml](policy-controller.yaml).

## Why

`AGENTS.md` requires all agent execution inside a verified OpenShell sandbox.
The current Ready sandbox image lacks `python3`, `opa`, `restic`, and `git`, so
controller tests and recovery-drill cannot run confined (see ops plan R20/D17).

## Proposed sandbox

| Field | Value |
| --- | --- |
| Name | `mac-env-controller` (new) or redesignated `mac-env-work` |
| Purpose | Controller edits, tests, recovery-drill, agent-inventory fixtures |
| Network | Deny by default (no egress); artifacts staged by operator upload |
| Filesystem | Project upload only; no HOME, Docker socket, or OpenShell admin mounts |
| Landlock | Prefer `hard_requirement` once tested; document fallback |
| Identity | Non-root; NoNewPrivs; empty capability sets |

## Required tools (pinned artifacts, staged by operator)

| Tool | Source | Pin |
| --- | --- | --- |
| python3 | Ubuntu image or Nix closure | ≥ 3.11 |
| opa | `operations/tools/fetch_opa.py` digest | 1.22.4 (`e6dfa065…d2a5`) |
| restic | flake `.#restic` | 0.19.1 (nixpkgs lock) |
| bash | image | ≥ 4 (declare -A) |

Do not give the workload network to fetch these. Operator uploads verified
binaries into the sandbox after hash check.

## Acceptance probes (operator runs)

1. Gateway authenticated; policy revision + hash recorded
2. `python3 -c 'import sys; assert sys.version_info >= (3, 11)'`
3. `opa version` matches pin
4. `restic version`
5. Negative: write to `/Users` denied; TCP 1.1.1.1:443 denied
6. `make verify-harness` and `python -m unittest discover -s operations/tests` pass inside

## Out of scope for this sandbox

- `darwin-rebuild`, `sudo`, LaunchDaemon install
- Production restic credentials
- Gateway/policy self-modification
- Provider credentials until separately reviewed

## Operator decision

Approve creation of this image/sandbox, or document why `mac-env-work` will be
rebuilt instead. Until then, desktop agents remain non-compliant with `AGENTS.md`.
