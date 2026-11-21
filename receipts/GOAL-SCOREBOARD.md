# Goal scoreboard — recover-ready deterministic system

Updated: 2026-11-21. Evidence-only. Not a completion claim.

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Deterministic Nix rebuild | Partial | Flake + `nix build .#restic` / `.#vulnix` works; HM profile present; darwin system gcroot absent | Operator `darwin-rebuild` |
| Auto-update gates (OPA) | Code-ready | Rego tests green; production apply disabled | Enable only after doctor.ready + rollback |
| Top security posture | Baseline **approved** | Live collectors ok; baseline `approver=glam` automatic=false (`receipts/baseline-approved-2026-11-21.json`); stealth still off (needs root) | Offsite + T17 + stealth |
| Automated operations | Partial | doctor blocker reduced to **local-only restic only** | offsite then install |
| Self-improvement | Local done | Harness **Level 3 COMPLETE**; 69 unit tests OK | Hosted CI green observed |
| Reliability / backup | **Blocked on credentials** | Local OK; baseline OK; sole doctor blocker = local-only restic; R2 bucket `mac-env-restic` created empty (`receipts/r2-bucket-2026-11-21.json`); rclone still has no remotes; netbird NeedsLogin | Operator R2 API token → `rclone config` Path C → bootstrap-offsite |
| Compromise recovery path | Documented | CHECKLISTS.md B + RUNBOOK | Spare/clean device drill timed |
| New Mac path | Scripted | `scripts/new-mac-bootstrap.sh` | Section A filled |
| Agent confinement | **Live** | `mac-env-controller` Ready; net deny; OPA 10/10 + **71/71** unittest in sandbox | T17 fleet cutover |
| Hosted CI | Stale | Last green nix CI 2026-11-06 (`receipts/ci-observe-2026-11-21.json`); harness workflows local only | Commit/push harness workflows + re-observe |
| uv / git hooks | Unblocked | Homebrew `uv` 0.13.9 + guard script sync | Keep on PATH |
| HOME agent inventory | Done (host) | 35 rows under state dir | T17 cutover |

## Live receipts this goal

- `receipts/recovery-drill-2026-11-21.json`
- `receipts/local-bootstrap-2026-11-21.json`
- `receipts/local-restore-roundtrip-2026-11-21.json`
- `receipts/openshell-image-2026-11-21.json`
- `receipts/security-live-2026-11-21.json`

## Still blocking UpdateGoal(complete)

1. **Offsite only for doctor.ready:** Cloudflare R2 API token → `rclone config` Path C (bucket ready) → 1P secrets → `sh scripts/bootstrap-offsite-once.sh --confirm`
2. Spare-machine CHECKLISTS A/B with initials/times
3. Hosted CI: commit/push harness workflows (last green nix CI 2026-11-06; actionlint local OK)
4. Optional: `sudo` stealth mode; T17 agent cutover

Done this goal (evidence): harness L3, local restore round-trip, security live+baseline, OpenShell controller 71/71, 1P env placeholders, R2 `mac-env-restic` bucket.

Operator progress probe: `make goal-progress`
