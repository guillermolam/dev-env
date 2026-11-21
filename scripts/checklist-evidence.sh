#!/bin/sh
# Capture auto-fillable CHECKLISTS evidence on this host. Never claims spare-Mac
# or compromise erase. Writes a receipt under receipts/ (no secrets).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
STAMP=$(date -u +%Y-%m-%dT%H%M%SZ)
OUT="${CHECKLIST_EVIDENCE_OUT:-$ROOT/receipts/checklist-evidence-$STAMP.md}"
UTC_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown)
NIX_VER=$(nix --version 2>/dev/null || echo missing)
HOST=$(uname -m)
BOOT_LOG=$(mktemp)
set +e
sh "$ROOT/scripts/new-mac-bootstrap.sh" >"$BOOT_LOG" 2>&1
BOOT_EC=$?
set -e
DOCTOR_JSON=$(mktemp)
set +e
sh "$ROOT/scripts/doctor.sh" >"$DOCTOR_JSON" 2>&1
DOCTOR_EC=$?
set -e

{
	echo "# Checklist evidence capture"
	echo
	echo "Recorded: $UTC_NOW"
	echo "Host arch: $HOST"
	echo "Commit: \`$COMMIT\`"
	echo
	echo "## Auto-filled (this host only)"
	echo
	echo "| Step | Status | Evidence |"
	echo "| --- | --- | --- |"
	echo "| A3 Nix | recorded | \`$NIX_VER\` |"
	echo "| A4 flake commit | recorded | \`$COMMIT\` |"
	echo "| A4b new-mac-bootstrap | exit $BOOT_EC | see log below |"
	echo "| A13 doctor | exit $DOCTOR_EC | sole blockers still require offsite |"
	echo
	echo "## Still blank in CHECKLISTS.md (operator / spare Mac)"
	echo
	echo "- A1–A2, A5–A12 on a **new** machine"
	echo "- Entire section B (compromise erase / trusted-device rotation)"
	echo "- A8 offsite \`MAC_ENV_RESTIC_*\` (R2 Path C token)"
	echo
	echo "## new-mac-bootstrap log"
	echo
	echo '```'
	cat "$BOOT_LOG"
	echo '```'
	echo
	echo "## doctor JSON"
	echo
	echo '```json'
	cat "$DOCTOR_JSON"
	echo '```'
} >"$OUT"

rm -f "$BOOT_LOG" "$DOCTOR_JSON"
printf 'Wrote %s\n' "$OUT"
# Receipt is the deliverable. Non-zero bootstrap is recorded inside; do not hide it.
if [ "$BOOT_EC" -ne 0 ]; then
	echo "new-mac-bootstrap exit $BOOT_EC (recorded; often nix-daemon down)" >&2
fi
exit 0