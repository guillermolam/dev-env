# Recovery runbook

Timed checklists with evidence columns: [CHECKLISTS.md](CHECKLISTS.md).

This runbook is not an automated erase tool. `mac-env restore files` restores
into a new empty directory only. No command in this repository wipes a disk.


## Deleted file

1. Select the last verified snapshot from a recovery manifest.
2. Restore it to a new empty directory.
3. Compare the restored file with the current location before replacing anything.
4. Preserve permissions and macOS metadata reported by the backup tool. If the
   backup reports cloud-only files or an active database as incomplete, do not
   claim those objects were restored.

## Configuration rollback

Nix and nix-darwin generations can be rolled back only through their own tools
after identifying the last known-good generation. This controller does not yet
claim a tested unattended rollback. Do not garbage-collect a generation that a
recovery manifest still references.

## New Mac

1. Install macOS for the target architecture. This repository currently builds
   the Apple Silicon `mac-studio` profile.
2. Install Nix, then build the pinned flake. A Nix build restores declared
   software and configuration only.
3. Restore verified data selectively. Do not copy an old system user account
   over the new account without review.
4. Rebuild security baselines from fresh evidence. Do not reuse a baseline from
   a machine suspected of compromise.

## 1Password

Use 1Password item history and recently deleted items. Rebuilding Nix does not
restore a vault item. This version does not export vault contents.

## Confirmed compromise

1. Preserve evidence and disconnect the machine from untrusted networks before
   changing the disk.
2. Rotate credentials from a separate trusted device.
3. Erase and reinstall only through an explicitly invoked macOS Recovery
   procedure. Do not start that procedure from a scanner alert or from this
   controller.
4. Install Nix, rebuild the pinned configuration, and restore only verified data
   that is still needed.

Passing scans do not prove the absence of compromise. A recovery manifest is
evidence of what was backed up, not a guarantee that the source was clean.
