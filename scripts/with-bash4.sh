#!/bin/sh
# macOS /bin/bash is 3.2 and cannot run verify-harness.sh (needs declare -A).
set -eu

is_bash4() {
	candidate=$1
	command -v "$candidate" >/dev/null 2>&1 || return 1
	major=$("$candidate" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null) || return 1
	case $major in
	'' | *[!0-9]*) return 1 ;;
	esac
	[ "$major" -ge 4 ]
}

run_with() {
	candidate=$1
	shift
	exec "$candidate" "$@"
}

if is_bash4 bash; then
	run_with bash "$@"
fi
if is_bash4 /opt/homebrew/bin/bash; then
	run_with /opt/homebrew/bin/bash "$@"
fi
if is_bash4 /usr/local/bin/bash; then
	run_with /usr/local/bin/bash "$@"
fi

for candidate in /nix/store/*-bash-5*/bin/bash; do
	if [ -x "$candidate" ] && is_bash4 "$candidate"; then
		run_with "$candidate" "$@"
	fi
done

echo "with-bash4.sh: need bash 4+ (BASH_VERSINFO>=4). Install bash via Nix/Homebrew." >&2
exit 127
