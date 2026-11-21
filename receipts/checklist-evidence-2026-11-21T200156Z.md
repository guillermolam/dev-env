# Checklist evidence capture

Recorded: 2026-11-21T20:01:56Z
Host arch: arm64
Commit: `db2f1e88841c3e45859a3b0edbc5e0e590854c38`

## Auto-filled (this host only)

| Step | Status | Evidence |
| --- | --- | --- |
| A3 Nix | recorded | `nix (Determinate Nix 3.24.2) 2.35.3` |
| A4 flake commit | recorded | `db2f1e88841c3e45859a3b0edbc5e0e590854c38` |
| A4b new-mac-bootstrap | exit 1 | see log below |
| A13 doctor | exit 0 | sole blockers still require offsite |

## Still blank in CHECKLISTS.md (operator / spare Mac)

- A1–A2, A5–A12 on a **new** machine
- Entire section B (compromise erase / trusted-device rotation)
- A8 offsite `MAC_ENV_RESTIC_*` (R2 Path C token)

## new-mac-bootstrap log

```

== 1. Host tools ==
OK  nix
OK  python3
OK  aarch64 host

== 2. Flake build (no activation) ==
BAD nix build .#restic failed

== 3. Controller prerequisites ==
OK  nix
OK  python3
OK  restic (MAC_ENV_RESTIC)
OK  opa
OK  flake.nix
OK  CHECKLISTS.md
OK  MAC_ENV_RESTIC_REPOSITORY set
OK  MAC_ENV_RESTIC_PASSWORD_FILE present
---
Prerequisites for production backup path look present.
Still required: offsite (non-local-restic) repo, approved baseline.

== 4. Next operator-only actions (not run here) ==
- Review generation: nix build --impure '.#darwinConfigurations.mac-studio.system'
- Activate only after review: sudo darwin-rebuild switch --impure --flake /Users/glam/Git/guillermolam/dev-env#mac-studio
- Source private restic env (local bootstrap or 1Password offsite)
- Fill operations/recovery/CHECKLISTS.md section A with evidence
- Provision OpenShell gateway: make openshell-provision && make openshell-start
- Approve OpenShell controller sandbox: docs/openshell/CREATE.md

== 5. Checklist pointer ==
OK  CHECKLISTS.md

Cold-start incomplete.
```

## doctor JSON

```json
{
  "blockers": [
    "backup destination is local-only; configure offsite MAC_ENV_RESTIC_REPOSITORY"
  ],
  "next": "make offsite-preflight; then rclone config (R2 Path C) or netbird up; then sh scripts/bootstrap-offsite-once.sh --confirm (docs/operations/offsite-restic.md)",
  "opa": "/Users/glam/Git/guillermolam/dev-env/operations/.cache/opa",
  "policy_evaluation_available": true,
  "ready": false,
  "schedule_enabled": false,
  "state_dir": "/Users/glam/Git/guillermolam/dev-env/.cache/mac-env-state",
  "state_dir_exists": true,
  "system_install": false,
  "using_installed_state": false
}
```
