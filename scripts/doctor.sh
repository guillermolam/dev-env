#!/bin/sh
# Non-mutating doctor with evidence + local-restic env when present.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EV="${MAC_ENV_EVIDENCE_DIR:-$HOME/.local/state/mac-environment/evidence}"
cd "$ROOT"
if [ -f "$EV/env.exports" ]; then
	# shellcheck disable=SC1090
	. "$EV/env.exports"
fi
if [ -f "$EV/runtime.env" ]; then
	# shellcheck disable=SC1090
	. "$EV/runtime.env"
fi
if [ -f "$ROOT/.cache/mac-env-state/local-restic/env.sh" ]; then
	# shellcheck disable=SC1090
	. "$ROOT/.cache/mac-env-state/local-restic/env.sh"
	export MAC_ENV_STATE_DIR="${MAC_ENV_STATE_DIR:-$ROOT/.cache/mac-env-state}"
fi
export PYTHONPATH="${PYTHONPATH:-$ROOT/operations}"
export MAC_ENV_OPA="${MAC_ENV_OPA:-$ROOT/operations/.cache/opa}"
if [ -z "${MAC_ENV_RESTIC:-}" ] && [ -x "$ROOT/.cache/controller-uploads/restic" ]; then
	export MAC_ENV_RESTIC="$ROOT/.cache/controller-uploads/restic"
fi
exec python3 -m mac_env doctor
