#!/bin/sh
# Fail-closed preflight for compromise-ready offsite backup.
# Exit 0 only when a non-local destination path is plausibly available.
set -eu
fail=0
ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'BAD %s\n' "$1"; fail=1; }

if command -v rclone >/dev/null 2>&1; then
	remotes=$(rclone listremotes 2>/dev/null || true)
	if [ -n "$remotes" ]; then
		ok "rclone remotes present"
	else
		bad "rclone installed but no remotes (rclone config; R2 Path C in docs/operations/offsite-restic.md)"
	fi
else
	bad "rclone missing"
fi

if command -v netbird >/dev/null 2>&1; then
	nb_status=$(netbird status 2>&1 || true)
	case "$nb_status" in
	*NeedsLogin*|*LoginFailed*|*Disconnected*)
		bad "netbird not connected (netbird up) — needed for homelab SFTP"
		;;
	*Connected*|*Management*|*Peers*)
		ok "netbird appears up"
		;;
	*)
		bad "netbird status unclear"
		;;
	esac
else
	bad "netbird missing (optional for SFTP homelab path)"
fi

repo="${MAC_ENV_RESTIC_REPOSITORY:-}"
if [ -z "$repo" ]; then
	bad "MAC_ENV_RESTIC_REPOSITORY unset"
elif printf '%s' "$repo" | grep -q 'local-restic'; then
	bad "MAC_ENV_RESTIC_REPOSITORY is local-only"
elif printf '%s' "$repo" | grep -Eq '^(rclone:|sftp:|s3:|b2:|azure:|gs:|rest:)'; then
	case "$repo" in
	*127.0.0.1*|*localhost*|*\[::1\]*)
		bad "repository points at loopback (not compromise-ready)"
		;;
	*)
		ok "MAC_ENV_RESTIC_REPOSITORY scheme looks remote"
		;;
	esac
else
	bad "MAC_ENV_RESTIC_REPOSITORY scheme not recognized as remote"
fi

if [ -n "${MAC_ENV_RESTIC_PASSWORD_FILE:-}" ] && [ -f "${MAC_ENV_RESTIC_PASSWORD_FILE}" ]; then
	ok "password file present"
else
	bad "MAC_ENV_RESTIC_PASSWORD_FILE missing"
fi

echo "---"
if [ "$fail" -eq 0 ]; then
	echo "Offsite preflight passed. Next: sh scripts/bootstrap-offsite-once.sh --confirm"
	exit 0
fi
echo "Offsite preflight failed. See docs/operations/offsite-restic.md"
exit 1
