#!/bin/sh
# Refresh and print the census board. Counts only. CENSUS_SOFT=1 never fails.
set -u
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
bin="$root/census/target/debug/mac-env-census"
mkdir -p "$root/.agents/runs"
if [ ! -x "$bin" ]; then
	cargo="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo"
	if [ -x "$cargo" ]; then
		CARGO_TARGET_DIR="$root/census/target" \
			"$cargo" build --manifest-path "$root/census/Cargo.toml" --quiet || true
	fi
fi
if [ -x "$bin" ]; then
	"$bin" --repo "$root" --board "$root/.agents/runs/census.txt" >/dev/null
	rc=$?
	sh "$root/scripts/census-format.sh" < "$root/.agents/runs/census.txt"
	exit "$rc"
fi
echo "census binary missing" >&2
if [ "${CENSUS_SOFT:-}" = 1 ]; then
	exit 0
fi
exit 1
