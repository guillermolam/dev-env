# CHECKLISTS local progress (not a spare-machine drill)

Date: 2026-11-21. Evidence-only. Empty cells in CHECKLISTS.md remain undone.

## D. Local drill — DONE

| Step | Evidence |
| --- | --- |
| recovery-drill | `receipts/recovery-drill-2026-11-21.json` |
| local bootstrap | `receipts/local-bootstrap-2026-11-21.json` |
| restore round-trip | `receipts/local-restore-roundtrip-2026-11-21.json` ROUNDTRIP_OK |

## A. New Mac — partial (same host tooling only)

| Step | Status | Evidence |
| --- | --- | --- |
| A3 Nix present | ok | `nix --version` on host |
| A4 flake present | ok | repo checkout |
| A4b new-mac-bootstrap | syntax + prereq partial | `scripts/new-mac-bootstrap.sh` |
| A5–A13 | **not done** | requires spare Mac / activation / offsite |

## B. Compromise — not executed

No erase, no credential rotation, no spare device. Documented only.

## Blocker for A8 / doctor.ready

Offsite destination unavailable: `receipts/offsite-blocker-2026-11-21.json`.
