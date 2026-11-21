#!/bin/sh
# Evidence-only recover-ready progress probe. Never activates or approves.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
EV="${MAC_ENV_EVIDENCE_DIR:-$HOME/.local/state/mac-environment/evidence}"

if [ -f "$EV/env.exports" ]; then
	# shellcheck disable=SC1090
	. "$EV/env.exports"
fi
if [ -f "$EV/runtime.env" ]; then
	# shellcheck disable=SC1090
	. "$EV/runtime.env"
fi
export PYTHONPATH="${PYTHONPATH:-$ROOT/operations}"
export MAC_ENV_OPA="${MAC_ENV_OPA:-$ROOT/operations/.cache/opa}"
if [ -z "${MAC_ENV_RESTIC:-}" ] && [ -x "$ROOT/.cache/controller-uploads/restic" ]; then
	export MAC_ENV_RESTIC="$ROOT/.cache/controller-uploads/restic"
fi

echo "== harness =="
make -s verify-harness 2>&1 | tail -3

echo "== backup status =="
python3 -m mac_env backup status

echo "== offsite preflight =="
sh "$ROOT/scripts/offsite-preflight.sh" || true

echo "== doctor =="
python3 -m mac_env doctor

echo "== scoreboard =="
sed -n '1,40p' "$ROOT/receipts/GOAL-SCOREBOARD.md"
