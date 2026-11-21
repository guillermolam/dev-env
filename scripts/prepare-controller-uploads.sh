#!/bin/sh
# Stage host (darwin) tools for local use AND linux/arm64 tools for OpenShell.
# Does not create sandboxes or touch the gateway.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
OUT="${1:-$ROOT/.cache/controller-uploads}"
LINUX_OUT="$OUT/linux-arm64"
mkdir -p "$OUT" "$LINUX_OUT"

OPA_LINUX_SHA="ea958fca8a657e4ce04df74c9b1c30220b368ddcf75fb3aa50bf306d55775dbf"
RESTIC_VER="0.19.1"

echo "== host opa (darwin) =="
python3 operations/tools/fetch_opa.py
cp -f operations/.cache/opa "$OUT/opa"
chmod 755 "$OUT/opa"

echo "== host restic =="
RESTIC_STORE=$(nix build --impure --no-link --print-out-paths '.#restic')
cp -f "$RESTIC_STORE/bin/restic" "$OUT/restic"
chmod 755 "$OUT/restic"

echo "== linux/arm64 opa =="
curl -fsSL "https://github.com/open-policy-agent/opa/releases/download/v1.22.4/opa_linux_arm64" \
	-o "$LINUX_OUT/opa"
ACTUAL=$(shasum -a 256 "$LINUX_OUT/opa" | awk '{print $1}')
if [ "$ACTUAL" != "$OPA_LINUX_SHA" ]; then
	echo "OPA linux checksum mismatch: $ACTUAL" >&2
	rm -f "$LINUX_OUT/opa"
	exit 1
fi
chmod 755 "$LINUX_OUT/opa"

echo "== linux/arm64 restic =="
SUMS=$(mktemp)
ARCHIVE=$(mktemp)
curl -fsSL "https://github.com/restic/restic/releases/download/v${RESTIC_VER}/SHA256SUMS" -o "$SUMS"
curl -fsSL "https://github.com/restic/restic/releases/download/v${RESTIC_VER}/restic_${RESTIC_VER}_linux_arm64.bz2" \
	-o "$ARCHIVE.bz2"
EXPECTED=$(awk '/restic_'"$RESTIC_VER"'_linux_arm64\.bz2$/ {print $1; exit}' "$SUMS")
ACTUAL=$(shasum -a 256 "$ARCHIVE.bz2" | awk '{print $1}')
if [ -z "$EXPECTED" ] || [ "$ACTUAL" != "$EXPECTED" ]; then
	echo "restic linux archive checksum mismatch: got $ACTUAL expected $EXPECTED" >&2
	rm -f "$SUMS" "$ARCHIVE.bz2"
	exit 1
fi
bunzip2 -c "$ARCHIVE.bz2" > "$LINUX_OUT/restic"
rm -f "$SUMS" "$ARCHIVE.bz2"
chmod 755 "$LINUX_OUT/restic"

(
	cd "$OUT"
	shasum -a 256 opa restic > SHA256SUMS
	cd linux-arm64
	shasum -a 256 opa restic > SHA256SUMS
)

echo "Staged host tools in $OUT"
cat "$OUT/SHA256SUMS"
echo "Staged linux/arm64 tools in $LINUX_OUT"
cat "$LINUX_OUT/SHA256SUMS"
echo "OpenShell upload: openshell sandbox upload NAME --no-git-ignore $LINUX_OUT/opa /tmp/opa"
