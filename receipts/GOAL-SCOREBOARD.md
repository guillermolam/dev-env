# Goal scoreboard — recover-ready deterministic system

Updated: 2026-11-21 (evening). Evidence-only. Not a completion claim.

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Deterministic Nix rebuild | Partial | Flake + packages; HM profile; darwin gcroot absent | Operator `darwin-rebuild` |
| Auto-update gates (OPA) | Code-ready | Rego tests green; production apply disabled | Enable only after doctor.ready + rollback |
| Top security posture | Baseline **approved** | `make doctor` + evidence → sole local-only restic blocker; stealth still off | Offsite + T17 + stealth |
| Automated operations | Partial | Doctor sole blocker = local-only restic (`make doctor`) | R2 token → rclone → bootstrap-offsite |
| Self-improvement | Partial | Harness L3 local; **Harness Verification CI green**; Shipped Checkpoints failed on wrong runner pin (fix staged) | Push fix; nix CI green |
| Reliability / backup | **Blocked on credentials** | Local OK; R2 bucket `mac-env-restic` ready; rclone remotes empty | Operator R2 API token |
| Compromise recovery path | Documented | CHECKLISTS.md B + RUNBOOK | Spare/clean device drill timed |
| New Mac path | Scripted | `scripts/new-mac-bootstrap.sh` | Section A filled |
| Agent confinement | Partial | Controller proven earlier; host gateway LaunchAgent **not** provisioned (`make openshell-status`) | Operator `make openshell-provision` |
| Hosted CI | Mixed | Harness Verification success (`receipts/ci-observe-2026-11-21.json`); checkpoints fail fixed locally | Re-observe after push |
| uv / git hooks | Unblocked | Homebrew uv + hooks | Keep on PATH |
| HOME agent inventory | Done (host) | 35 rows under state dir | T17 cutover |

## Live receipts this goal

- `receipts/recovery-drill-2026-11-21.json`
- `receipts/local-bootstrap-2026-11-21.json`
- `receipts/local-restore-roundtrip-2026-11-21.json`
- `receipts/openshell-image-2026-11-21.json`
- `receipts/security-live-2026-11-21.json`
- `receipts/r2-bucket-2026-11-21.json`
- `receipts/ci-observe-2026-11-21.json`

## Still blocking UpdateGoal(complete)

1. **Offsite:** Cloudflare R2 API token → `make rclone-r2` → 1P → `sh scripts/bootstrap-offsite-once.sh --confirm`
2. Spare-machine CHECKLISTS A/B with initials/times
3. Hosted CI: checkpoints pin fix + green nix
4. Optional: OpenShell LaunchAgent provision; `sudo` stealth; T17 cutover

Done (evidence): harness L3, local restore round-trip, security live+baseline, OpenShell controller 71/71, R2 bucket, harness CI green, `make doctor` sole local-only blocker.

Operator progress probe: `make goal-progress` / `make doctor`
