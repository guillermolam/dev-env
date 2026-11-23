#!/usr/bin/env python3
"""Alert the agent on one harness step and append a secret-free receipt."""

import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEDGER = ROOT / ".agents" / "runs" / "steps.jsonl"
ALERT = (
    "If this step contradicted a team Done when, adjust that spec, skill, "
    "command, or example once. If it did not, change nothing. "
    "Do not ask the operator. Do not drop the OpenShell fence."
)


def load_event():
    raw = sys.stdin.read()
    try:
        event = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}
    return event if isinstance(event, dict) else {}


def tool_name(event):
    value = event.get("tool_name") or event.get("tool") or event.get("subagent_type")
    text = str(value or "unknown").split()[0][:64]
    lowered = text.lower()
    if any(mark in lowered for mark in ("token", "secret", "password", "key=")):
        return "redacted"
    return text


def receipt(event, kind):
    name = tool_name(event)
    ok = "error" not in event and event.get("status") not in ("error", "failed")
    stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    ident = hashlib.sha256(f"{stamp}|{kind}|{name}|{ok}".encode()).hexdigest()[:12]
    return {"id": ident, "at": stamp, "event": kind, "tool": name, "ok": bool(ok)}


def emit(kind, row):
    text = f"Step {row['id']} event={row['event']} tool={row['tool']} ok={row['ok']}. {ALERT}"
    if kind == "subagentStop":
        return {"followup_message": text}
    return {"additional_context": text}


def write_receipt(row):
    try:
        LEDGER.parent.mkdir(parents=True, exist_ok=True)
        with LEDGER.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, separators=(",", ":")) + "\n")
    except OSError:
        return


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "postToolUse"
    event = load_event()
    row = receipt(event, kind[:64])
    write_receipt(row)
    json.dump(emit(kind, row), sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        sys.stdout.write("{}\n")
        raise SystemExit(0)
