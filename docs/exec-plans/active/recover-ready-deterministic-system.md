# Exec plan: recover-ready deterministic system

Status: active  
Opened: 2026-11-21  
Goal: rebuild/configure everything from known-good state after compromise, data
loss, or a new Mac — with auto-update gates, top security posture, automated
ops, and self-improvement loops.

## Non-goals (this plan)

- Enabling unattended mutation or LaunchDaemon before doctor + verified backup
- Vault export, automatic erase, or host activation by agents
- Claiming fleet OpenShell confinement before T17 evidence

## Phases

| Phase | Outcome | Evidence of done | Status |
| --- | --- | --- | --- |
| P1 Harness L1→L2 | Agents can verify docs/commands/CI | Level 3 COMPLETE locally | done (local) |
| P2 OpenShell work image | Controller tests runnable in sandbox | `mac-env-controller` Ready; OPA 10/10 + **71/71** tests in-sandbox | done (live) |
| P2b OpenShell Nix provision | Flake-owned gateway start (no brew) | Package + script in tree; operator `make openshell-start` pending | implemented (not live) |
| P3 Policy/controller defects | Rego freshness/thresholds; PATH; state-dir | Done in code (T23 + Rego) | done (code) |
| P4 Backup + restore drill | Verified snapshot + empty-dir restore | Local OK; R2 bucket `mac-env-restic` created; doctor still local-only until rclone+token; 1P placeholders | partial (await R2 API token + snapshot) |
| P5 Security coverage | Real collector sources or explicit gaps | Baseline **approved** (`receipts/baseline-approved-2026-11-21.json`) | done (live) |
| P6 Install path | Root-owned state; doctor can become ready | Fixture path proven; install still refused pending inputs | partial |
| P7 New-Mac / compromise drill | Timed checklist executed once | `scripts/new-mac-bootstrap.sh` + CREATE.md; timed drill still operator | blocked on P4 offsite |
| P8 Self-improve loop | Checkpoints + hooks + status discipline | Harness L3 local; scoreboard in `receipts/GOAL-SCOREBOARD.md`; hosted CI not observed | partial |

## Operator decisions still required

See [docs/plans/dev-env-operations-plan.md](../../plans/dev-env-operations-plan.md) §9.
Hard blockers for P4: R2 API token → rclone remote → `bootstrap-offsite --confirm`.
P2 sandbox image done (`mac-env-controller`).

## This change set (P1)

- `AGENTS.md` — index + `## Commands` + security rules retained
- `docs/ARCHITECTURE.md` — system / recovery model
- `scripts/verify-harness.sh`, `Makefile` targets
- `.github/workflows/harness-verify.yml`
- `.github/pull_request_template.md`
- This exec-plan

## Verification

```bash
make verify-harness
```

Record Level summary and remaining warnings in the session that lands P1.
