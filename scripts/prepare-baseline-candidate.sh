#!/bin/sh
# Build an evidence bundle for operator baseline approval. Does NOT approve.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EV="${1:-$HOME/.local/state/mac-environment/evidence}"
OUT="${2:-$HOME/.local/state/mac-environment/baseline-candidate}"
mkdir -p "$OUT"
BUNDLE="$OUT/evidence.json"
export BUNDLE
export PYTHONPATH="${PYTHONPATH:-$ROOT/operations}"

# shellcheck disable=SC1090
[ -f "$EV/env.exports" ] && . "$EV/env.exports"
[ -f "$EV/runtime.env" ] && . "$EV/runtime.env"

python3 - <<'PY'
import json
import os
from pathlib import Path

from mac_env.security import collect_security

report = collect_security()
path = Path(os.environ["BUNDLE"])
path.write_text(json.dumps({"evidence": report["evidence"]}, indent=2) + "\n")
print(
    json.dumps(
        {
            "bundle": str(path),
            "gaps": report["coverage_gaps"],
            "ready": not report["coverage_gaps"],
        },
        indent=2,
    )
)
PY

echo
echo "Review $BUNDLE then (operator only):"
echo "PYTHONPATH=operations python3 -m mac_env policy approve-baseline --confirm \\"
echo "  --approver \"\$USER\" --evidence $BUNDLE"
