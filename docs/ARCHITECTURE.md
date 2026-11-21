# Architecture

Recover-ready Apple Silicon Mac environment: declarative Nix configuration plus
a fail-closed Python controller whose backup and update eligibility is decided
by local OPA/Rego. Goal: rebuild software/config from a pinned flake, restore
verified data selectively, and keep agents inside OpenShell.

## System overview

| Layer | Role | Operational today? |
| --- | --- | --- |
| nix-darwin + Home Manager | Declared system and user packages | Config exists; activation is operator-run |
| `mac-env` controller | Inventory, policy, backup/restore wrappers, daily gates | Tested; not installed; mutation disabled |
| OPA/Rego | Eligibility engine (no Python policy fallback) | Tested locally; production apply disabled |
| OpenShell | Required agent execution boundary | Bootstrap verified historically; fleet cutover pending |
| Restic + recovery runbook | Encrypted backup and selective restore | Code tested with fakes; destination unset |
| Homelab modules | Optional DNS/PKI/VPN/K8s integrations | Declared; disabled by default |

Runtime state belongs under `/private/var/lib/mac-environment` (logs under
`/private/var/log/mac-environment`) after a reviewed install. Resolution order:
`MAC_ENV_STATE_DIR` → `MAC_ENV_USE_INSTALLED_STATE=1` → 
`$HOME/.local/state/mac-environment`. The LaunchDaemon template sets the
installed path. Developer runs keep the user path. Secrets and restic password
files stay outside Git and outside agent mounts. Recovery checklists:
`operations/recovery/CHECKLISTS.md`.


## Component map

| Component | Responsibility | Key files |
| --- | --- | --- |
| Flake / Darwin | Pin inputs; build `darwinConfigurations.mac-studio` | `flake.nix`, `hosts/mac-studio/` |
| Home Manager | User packages and runtime declarations | `home/` |
| Homelab | Optional services; digests and enable flags | `homelab/` |
| Controller CLI | Doctor, daily, policy, backup, provision, housekeeping | `operations/mac_env/` |
| Policy | Tool modes, eligibility, fail-closed decisions | `operations/policy/` |
| Security collectors | Evidence for firewall/endpoint/access/integrity/vuln | `operations/mac_env/security.py`, collectors |
| Backup | Restic command construction; restore into empty dirs | `operations/mac_env/backup.py` |
| Deploy | Root-owned install template; disabled LaunchDaemon | `operations/deploy/` |
| Recovery docs | Compromise / new-Mac / selective restore boundaries | `operations/recovery/RUNBOOK.md` |
| Agent security | OpenShell inventory, cutover, audit plan | `AGENT_SECURITY_PLAN.md` |
| Harness | Agent-legible index, architecture, CI verify | `AGENTS.md`, `docs/`, `scripts/verify-harness.sh` |

## Dependency rules

- Controllers and agents **must not** supply the policy that authorizes their
  own candidate updates.
- OPA is the only eligibility engine. Missing/stale/malformed evidence blocks.
- `hold` wins over `auto` across layers, including indirect Nix changes.
- Homelab and LaunchDaemon stay disabled until operator inputs and evidence exist.
- Agents propose; operators approve activation, baselines, gateway/policy changes,
  backup destinations, and restores into live paths.
- Python under `operations/` stays at cyclomatic and cognitive complexity ≤ 3.

## Data flow

```text
collectors → evidence → OPA decision → plan → (disabled) apply
                ↘ daily report + coverage_gaps
restic → verified snapshot → recovery manifest → restore to NEW empty directory
flake lock → nix build → operator darwin-rebuild → generation rollback path
OpenShell gateway → sandbox workload → audited tool calls (no HOME mount)
```

## Recovery model

1. **Config/software:** pinned flake + known-good nix-darwin generation.
2. **User data:** restic selective restore into a new empty directory; compare
   before replace.
3. **Secrets:** 1Password item history only; no vault export in this repo.
4. **Compromise:** preserve evidence → rotate from a clean device → erase via
   macOS Recovery (manual) → rebuild from pin → restore only verified data →
   approve a **new** baseline (never reuse a compromised one).
5. **New Mac:** install macOS (aarch64) → Determinate Nix → build flake →
   selective restore → fresh security evidence.

## Key decisions

| Decision | Rationale | Date |
| --- | --- | --- |
| OPA over Python eligibility | Single fail-closed decision surface | 2026-11 |
| OpenShell required for agents | Contain tool/MCP blast radius; no host fallback | 2026-11 |
| Production apply disabled until inputs exist | Incomplete collectors must not authorize mutation | 2026-11 |
| Restore only into empty directories | Prevent silent overwrite of live trees | 2026-11 |
| Homelab disabled by default | No accidental LAN/public exposure | 2026-11 |

## Status sources

- [PLAN.md](../PLAN.md) — completed work and deployment blockers
- [FEATURES.md](../FEATURES.md) — capability matrix
- [TASKS.csv](../TASKS.csv) — task IDs and evidence
- [docs/plans/dev-env-operations-plan.md](plans/dev-env-operations-plan.md) — teams, risks, operator decisions
- [docs/exec-plans/active/](exec-plans/active/) — current multi-file work
