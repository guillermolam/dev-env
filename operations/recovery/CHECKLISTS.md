# Recovery checklists

Fill every Evidence cell. Empty cells mean the step is not done. Do not mark a
machine recovered from intent alone.

Related: [RUNBOOK.md](RUNBOOK.md), [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md).

## A. New Mac (Apple Silicon)

Preconditions: spare or replacement Mac; this repo available over a clean
channel; restic destination reachable; 1Password account recoverable.

| Step | Action | Evidence (record) | Time (UTC) | Initials |
| --- | --- | --- | --- | --- |
| A1 | Install macOS for `aarch64` | macOS build / serial | | |
| A2 | Create local account (do not migrate old Local items blindly) | username | | |
| A3 | Install Determinate Nix | `nix --version` output | | |
| A4 | Clone/fetch this flake at a known commit | commit SHA | | |
| A4b | `make new-mac-bootstrap` (or `sh scripts/new-mac-bootstrap.sh`) | exit 0 output | | |
| A5 | `nix build --impure '.#darwinConfigurations.mac-studio.system'` | store path / exit 0 | | |
| A6 | Operator activates generation (`darwin-rebuild switch --impure`) | generation number | | |
| A7 | `nix build .#mac-env` and compare OPA version to pinned 1.22.4 | opa --version | | |
| A8 | Configure `MAC_ENV_RESTIC_*` outside Git | repo URL scheme only (no secret) | | |
| A9 | Restore selected paths into a **new empty** directory | restore path + snapshot ID | | |
| A10 | Compare restored vs intended; copy only after review | files reviewed | | |
| A11 | Unlock 1Password; rotate nothing unless compromise suspected | vault unlock OK | | |
| A12 | Collect fresh security evidence; approve **new** baseline | baseline path + approver | | |
| A13 | `mac-env doctor` — record blockers; schedule stays Disabled | doctor JSON excerpt | | |

Stop if any evidence cell is blank. Do not enable LaunchDaemon until doctor
blockers are only the intentional coverage items you accept in writing.

## B. Confirmed or suspected compromise

| Step | Action | Evidence | Time (UTC) | Initials |
| --- | --- | --- | --- | --- |
| B1 | Disconnect untrusted networks; preserve volatile evidence | what was preserved | | |
| B2 | From a **separate trusted** device, rotate credentials | rotation list (names only) | | |
| B3 | Do **not** reuse the old security baseline | old baseline ID quarantined | | |
| B4 | Erase/reinstall only via macOS Recovery (operator-invoked) | Recovery procedure used | | |
| B5 | Continue from A3 with a clean Mac | link to A checklist | | |
| B6 | Restore only verified snapshots still needed | snapshot IDs accepted | | |
| B7 | Rebuild OpenShell gateway/policy from known-good pins | OpenShell version + policy hash | | |
| B8 | Re-inventory agents (T16+) before any host agent launch | inventory report path | | |

Passing scans after B5 do not prove absence of compromise. Treat unknown
provenance as unknown.

## C. Selective file restore (no erase)

| Step | Action | Evidence | Time (UTC) | Initials |
| --- | --- | --- | --- | --- |
| C1 | Choose last **verified** snapshot from recovery manifest | snapshot ID | | |
| C2 | `mac-env restore files` into a new empty directory | destination path | | |
| C3 | Diff restored vs live; replace only after review | review notes path | | |
| C4 | Preserve previous recovery manifest on any failure | manifest paths | | |

## Operator inputs still required for A8/C1

- `MAC_ENV_RESTIC_REPOSITORY`
- `MAC_ENV_RESTIC_PASSWORD_FILE` (mode 0600; outside Git)
- Verified recovery manifest from a successful backup

## D. Local drill (no production repo)

Prove the restore path before configuring production storage:

```sh
nix build .#restic
PYTHONPATH=operations python3 -m mac_env recovery-drill \
  --workspace .cache/recovery-drill-live --restic ./result/bin/restic
sh scripts/check-recovery-prereqs.sh
```

Record snapshot_id and restored path from the JSON output. A disposable live
run on 2026-11-21 is recorded in `receipts/recovery-drill-2026-11-21.json`.
Local bootstrap + restore round-trip:
`receipts/local-bootstrap-2026-11-21.json`,
`receipts/local-restore-roundtrip-2026-11-21.json` (`ROUNDTRIP_OK`).
None of these satisfy A8; they only prove the controller path. Offsite and
OpenShell create remain operator-gated (`docs/openshell/CREATE.md`,
`receipts/GOAL-SCOREBOARD.md`).
