#!/bin/sh
# One-shot offsite restic bootstrap after rclone (or other) remote exists.
# Refuses local-restic. Requires --confirm.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [ "${1:-}" != "--confirm" ]; then
	echo "Usage: $0 --confirm"
	echo "Requires MAC_ENV_RESTIC_REPOSITORY (non-local) and MAC_ENV_RESTIC_PASSWORD_FILE."
	exit 2
fi

sh "$ROOT/scripts/rclone-offsite-check.sh" || true

REPO="${MAC_ENV_RESTIC_REPOSITORY:?set MAC_ENV_RESTIC_REPOSITORY}"
PASS="${MAC_ENV_RESTIC_PASSWORD_FILE:?set MAC_ENV_RESTIC_PASSWORD_FILE}"
RESTIC="${MAC_ENV_RESTIC:-}"
if [ -z "$RESTIC" ] && [ -x "$ROOT/.cache/controller-uploads/restic" ]; then
	RESTIC="$ROOT/.cache/controller-uploads/restic"
fi
if [ -z "$RESTIC" ] && [ -x "$ROOT/result/bin/restic" ]; then
	RESTIC="$ROOT/result/bin/restic"
fi
: "${RESTIC:?set MAC_ENV_RESTIC or nix build .#restic}"

case "$REPO" in
*local-restic*)
	echo "Refusing local-restic repository: $REPO" >&2
	exit 1
	;;
esac

PATH_ARG="${OFFSITE_BACKUP_PATH:-$HOME/Documents}"
export PYTHONPATH="${PYTHONPATH:-$ROOT/operations}"
exec python3 -m mac_env backup bootstrap-offsite --confirm \
	--repository "$REPO" \
	--password-file "$PASS" \
	--path "$PATH_ARG" \
	--restic "$RESTIC"
