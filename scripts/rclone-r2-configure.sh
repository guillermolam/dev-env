#!/bin/sh
# Non-secret helper: configure rclone remote "r2" for mac-env-restic.
# Requires R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY in the environment
# (from Cloudflare dashboard → R2 → Manage R2 API Tokens). Never prints them.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
BUCKET="${R2_BUCKET:-mac-env-restic}"
REMOTE="${RCLONE_REMOTE_NAME:-r2}"

if [ -z "$ACCOUNT_ID" ]; then
	echo "Set CLOUDFLARE_ACCOUNT_ID (Cloudflare account id for R2 endpoint)." >&2
	exit 1
fi
if [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ]; then
	echo "Set R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY (do not commit)." >&2
	echo "Docs: $ROOT/docs/operations/offsite-restic.md Path C" >&2
	exit 1
fi
if ! command -v rclone >/dev/null 2>&1; then
	echo "rclone missing" >&2
	exit 1
fi

endpoint="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"
rclone config create "$REMOTE" s3 \
	provider Cloudflare \
	access_key_id "$R2_ACCESS_KEY_ID" \
	secret_access_key "$R2_SECRET_ACCESS_KEY" \
	endpoint "$endpoint" \
	acl private

echo "OK remote ${REMOTE}: configured"
echo "Next: export MAC_ENV_RESTIC_REPOSITORY=rclone:${REMOTE}:${BUCKET}/mac-studio"
echo "Then: sh $ROOT/scripts/rclone-offsite-check.sh"
echo "Then: sh $ROOT/scripts/bootstrap-offsite-once.sh --confirm"
