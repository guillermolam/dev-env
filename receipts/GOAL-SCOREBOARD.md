# Goal scoreboard — recover-ready deterministic system

Updated: 2026-11-21T20:35Z. Evidence-only. Not a completion claim.

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Deterministic Nix rebuild | CI-proven | **nix CI green** `44944323290` (flake check + darwin system build) | Operator `darwin-rebuild switch` |
| Auto-update gates (OPA) | Code-ready | Rego + controller tests green in CI | Enable only after doctor.ready |
| Top security posture | Baseline approved | `make doctor` sole blocker = local-only restic | Offsite + stealth |
| Automated operations | Partial | Doctor sole local-only blocker | R2 token → bootstrap-offsite → install |
| Self-improvement | **Hosted green** | Harness L3; Harness+Checkpoints+nix all success on `423a160` | Keep gates |
| Reliability / backup | Blocked on credentials | Local OK; R2 bucket ready; rclone empty; netbird NeedsLogin | Operator R2 API token |
| Compromise recovery path | Documented | CHECKLISTS B | Spare/clean device drill |
| New Mac path | Partial evidence | `make checklist-evidence` | Spare Mac A1–A13 |
| Agent confinement | Partial | Controller proven; gateway LaunchAgent not provisioned | `make openshell-provision` |

## Still blocking UpdateGoal(complete)

1. **Offsite:** R2 API token → `make rclone-r2` → `bootstrap-offsite-once.sh --confirm`
2. Spare-machine CHECKLISTS A/B with initials/times
3. Optional: OpenShell LaunchAgent; stealth; T17; darwin-rebuild

Receipt: `receipts/ci-observe-2026-11-21.json`
