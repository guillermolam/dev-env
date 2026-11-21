#!/bin/sh
# Fail closed until an rclone remote exists for offsite restic.
set -eu
if ! command -v rclone >/dev/null 2>&1; then
	echo "BAD rclone missing (brew install rclone / HM package)"
	exit 1
fi
remotes=$(rclone listremotes 2>/dev/null || true)
if [ -z "$remotes" ]; then
	echo "BAD no rclone remotes — run: rclone config"
	echo "Then set MAC_ENV_RESTIC_REPOSITORY=rclone:<remote>:<path>"
	exit 1
fi
echo "OK remotes:"
printf '%s\n' "$remotes"
exit 0
