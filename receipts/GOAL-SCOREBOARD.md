# Goal scoreboard — recover-ready deterministic system

Updated: 2026-11-21T20:03Z. Evidence-only. Not a completion claim.

| Requirement | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Deterministic Nix rebuild | Partial | Format OK; flake `opa` → `open-policy-agent` fix ready; nix-daemon down locally | Push opa fix; operator `darwin-rebuild` |
| Auto-update gates (OPA) | Code-ready | Rego tests green; production apply disabled | Enable only after doctor.ready |
| Top security posture | Baseline approved | `make doctor` sole blocker = local-only restic | Offsite + stealth |
| Automated operations | Partial | Doctor sole local-only blocker | R2 token → bootstrap-offsite |
| Self-improvement | Strong | Harness L3; **Harness Verification + Shipped Checkpoints CI green** (`44944032479`, `44944032339`) | nix CI green after opa attr fix |
| Reliability / backup | Blocked on credentials | Local OK; R2 bucket ready; rclone empty | Operator R2 API token |
| Compromise recovery path | Documented | CHECKLISTS B | Spare/clean device drill |
| New Mac path | Partial evidence | `make checklist-evidence` receipt; A3/A4 filled | Spare Mac A1–A13 |
| Agent confinement | Partial | Controller proven earlier; gateway LaunchAgent not provisioned | `make openshell-provision` |
| Hosted CI | Mixed | Checkpoints+harness green; nix flake check fails on `pkgs.opa` | Push `open-policy-agent` fix |

## Still blocking UpdateGoal(complete)

1. Offsite R2 API token → `make rclone-r2` → bootstrap-offsite
2. Spare-machine CHECKLISTS A/B with initials
3. nix CI green after opa package attr fix
4. Optional: OpenShell LaunchAgent; stealth; T17

Operator: `make goal-progress` / `make doctor` / `make checklist-evidence`
