#!/bin/sh
# Refuses to copy files or bootstrap launchd until doctor reports no blockers.
# Always exits 2. Prints live doctor output when the controller can run.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
echo "Refusing to install mac-env."
echo "Production scheduling stays disabled until doctor.ready is true."
OPA="${MAC_ENV_OPA:-$ROOT/operations/.cache/opa}"
if [ -x "$OPA" ] && command -v python3 >/dev/null 2>&1; then
	echo "Live doctor blockers:"
	PYTHONPATH="$ROOT/operations" MAC_ENV_OPA="$OPA" \
		python3 -m mac_env doctor || true
else
	echo "Deployment blockers (static fallback):"
	echo "- backup destination is not configured"
	echo "- backup credential reference is not configured"
	echo "- approved baseline is not present"
	echo "- security collectors do not have complete coverage"
	echo "Set MAC_ENV_OPA or fetch operations/.cache/opa to see live doctor output."
fi
echo "Offsite preflight:"
sh "$ROOT/scripts/offsite-preflight.sh" || true
echo "Do not bootstrap the LaunchDaemon."
echo "After inputs exist and doctor.ready is true, install is a separate reviewed operation."
exit 2
