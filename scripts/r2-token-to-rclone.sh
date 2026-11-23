#!/bin/sh
# Create a bucket-scoped Cloudflare API token, derive R2 S3 keys, configure rclone.
# Never prints Access Key / Secret / OAuth. Requires: curl, jq, rclone, python3,
# and a Wrangler OAuth token on disk (wrangler whoami succeeds).
#
# Usage:
#   CLOUDFLARE_ACCOUNT_ID=... sh scripts/r2-token-to-rclone.sh --confirm
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-e89b452f10f28f09ecc0994164a26b49}"
BUCKET="${R2_BUCKET:-mac-env-restic}"
REMOTE="${RCLONE_REMOTE_NAME:-r2}"
WRANGLER_TOML="${WRANGLER_CONFIG:-$HOME/Library/Preferences/.wrangler/config/default.toml}"

if [ "${1:-}" != "--confirm" ]; then
	echo "Usage: CLOUDFLARE_ACCOUNT_ID=... $0 --confirm" >&2
	exit 2
fi
for bin in curl jq rclone python3; do
	command -v "$bin" >/dev/null 2>&1 || {
		echo "missing $bin" >&2
		exit 1
	}
done
[ -f "$WRANGLER_TOML" ] || {
	echo "wrangler config missing; run: wrangler login" >&2
	exit 1
}

# Extract oauth_token without printing it.
OAUTH=$(python3 - "$WRANGLER_TOML" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'(?m)^\s*oauth_token\s*=\s*"([^"]+)"\s*$', text)
if not m:
    raise SystemExit("oauth_token not found in wrangler config")
print(m.group(1), end="")
PY
)

# Resolve R2 object permission group ids (names only logged).
GROUPS_JSON=$(curl -fsS -H "Authorization: Bearer ${OAUTH}" \
	"https://api.cloudflare.com/client/v4/user/tokens/permission_groups")
READ_ID=$(printf '%s' "$GROUPS_JSON" | jq -r '
  .result[] | select(.name=="Workers R2 Storage Bucket Item Read") | .id' | head -1)
WRITE_ID=$(printf '%s' "$GROUPS_JSON" | jq -r '
  .result[] | select(.name=="Workers R2 Storage Bucket Item Write") | .id' | head -1)
if [ -z "$READ_ID" ] || [ -z "$WRITE_ID" ] || [ "$READ_ID" = null ] || [ "$WRITE_ID" = null ]; then
	echo "could not resolve R2 bucket item permission groups" >&2
	exit 1
fi
echo "OK permission groups resolved (read+write bucket item)"

RESOURCE="com.cloudflare.edge.r2.bucket.${ACCOUNT_ID}_default_${BUCKET}"
BODY=$(jq -n \
	--arg name "mac-env-restic-rclone" \
	--arg read "$READ_ID" \
	--arg write "$WRITE_ID" \
	--arg resource "$RESOURCE" \
	'{
          name: $name,
          policies: [{
            effect: "allow",
            resources: {($resource): "*"},
            permission_groups: [{id: $read}, {id: $write}]
          }]
        }')

CREATE_JSON=$(curl -fsS -X POST \
	-H "Authorization: Bearer ${OAUTH}" \
	-H "Content-Type: application/json" \
	--data "$BODY" \
	"https://api.cloudflare.com/client/v4/user/tokens")

SUCCESS=$(printf '%s' "$CREATE_JSON" | jq -r '.success')
if [ "$SUCCESS" != true ]; then
	echo "token create failed (errors redacted)" >&2
	printf '%s' "$CREATE_JSON" | jq -r '.errors[]?.message // empty' >&2
	exit 1
fi

# Access Key ID = token id; Secret = sha256(token value) per Cloudflare R2 docs.
ACCESS_KEY_ID=$(printf '%s' "$CREATE_JSON" | jq -r '.result.id')
TOKEN_VALUE=$(printf '%s' "$CREATE_JSON" | jq -r '.result.value')
SECRET_ACCESS_KEY=$(printf '%s' "$TOKEN_VALUE" | python3 -c 'import sys,hashlib; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())')

export CLOUDFLARE_ACCOUNT_ID="$ACCOUNT_ID"
export R2_ACCESS_KEY_ID="$ACCESS_KEY_ID"
export R2_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY"
export R2_BUCKET="$BUCKET"
export RCLONE_REMOTE_NAME="$REMOTE"
sh "$ROOT/scripts/rclone-r2-configure.sh"

# Drop secrets from this shell environment after configure.
unset OAUTH TOKEN_VALUE R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY ACCESS_KEY_ID SECRET_ACCESS_KEY CREATE_JSON BODY

echo "OK rclone remote ready; repository hint: rclone:${REMOTE}:${BUCKET}/mac-studio"
echo "Next: export MAC_ENV_RESTIC_REPOSITORY=rclone:${REMOTE}:${BUCKET}/mac-studio"
echo "Then: sh $ROOT/scripts/bootstrap-offsite-once.sh --confirm"
