#!/bin/sh
# Non-mutating prerequisite check for new-Mac / recover-ready work.
# Exit 0 only when every required tool is present. Does not activate Nix or install.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'BAD %s\n' "$1"; fail=1; }

command -v nix >/dev/null 2>&1 && ok "nix" || bad "nix missing"
command -v python3 >/dev/null 2>&1 && ok "python3" || bad "python3 missing"

if [ -n "${MAC_ENV_RESTIC:-}" ] && [ -x "${MAC_ENV_RESTIC}" ]; then
	ok "restic (MAC_ENV_RESTIC)"
elif command -v restic >/dev/null 2>&1; then
	ok "restic (PATH)"
elif [ -x "$ROOT/result/bin/restic" ]; then
	ok "restic (./result from nix build .#restic)"
elif [ -x "$ROOT/.cache/controller-uploads/restic" ]; then
	ok "restic (.cache/controller-uploads)"
else
	bad "restic missing — nix build .#restic or install via Home Manager"
fi

if [ -x "${MAC_ENV_OPA:-$ROOT/operations/.cache/opa}" ]; then
	ok "opa"
else
	bad "opa missing — python3 operations/tools/fetch_opa.py"
fi

[ -f "$ROOT/flake.nix" ] && ok "flake.nix" || bad "flake.nix missing"
[ -f "$ROOT/operations/recovery/CHECKLISTS.md" ] && ok "CHECKLISTS.md" || bad "CHECKLISTS.md missing"

if [ -n "${MAC_ENV_RESTIC_REPOSITORY:-}" ]; then
	ok "MAC_ENV_RESTIC_REPOSITORY set"
else
	bad "MAC_ENV_RESTIC_REPOSITORY unset (production backup)"
fi

if [ -n "${MAC_ENV_RESTIC_PASSWORD_FILE:-}" ] && [ -f "${MAC_ENV_RESTIC_PASSWORD_FILE}" ]; then
	ok "MAC_ENV_RESTIC_PASSWORD_FILE present"
else
	bad "MAC_ENV_RESTIC_PASSWORD_FILE missing"
fi

echo "---"
if [ "$fail" -eq 0 ]; then
	echo "Prerequisites for production backup path look present."
	echo "Still required: offsite (non-local-restic) repo, approved baseline."
	exit 0
fi
echo "Prerequisites incomplete. See operations/recovery/CHECKLISTS.md."
exit 1
