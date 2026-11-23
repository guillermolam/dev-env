"""Update planning. Production adapters cannot claim untested rollback or scan support."""

import hashlib
import json
from datetime import UTC, datetime

from mac_env.opa_eval import evaluate_input

ADAPTERS = {
    "nix": {
        "can_scan_candidate": False,
        "can_rollback": False,
        "can_unattended": False,
        "can_constrain_dependencies": False,
        "estimated_bytes": 0,
        "note": "darwin-rebuild rollback exists operationally but this controller has not verified it",
    },
    "homebrew": {
        "can_scan_candidate": False,
        "can_rollback": False,
        "can_unattended": False,
        "can_constrain_dependencies": False,
        "estimated_bytes": 0,
        "note": "Homebrew candidate scanning and rollback are not wired",
    },
    "applications": {
        "can_scan_candidate": False,
        "can_rollback": False,
        "can_unattended": False,
        "can_constrain_dependencies": False,
        "estimated_bytes": 0,
        "note": "Application update APIs are not assumed",
    },
    "macos": {
        "can_scan_candidate": False,
        "can_rollback": False,
        "can_unattended": False,
        "can_constrain_dependencies": False,
        "estimated_bytes": 0,
        "note": "macOS updates that require restart are deferred until explicitly supported",
    },
}


def fingerprint(payload):
    body = {key: value for key, value in payload.items() if key != "fingerprint"}
    encoded = json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def build_input(candidate, evidence, baseline, layers, host, initiated="scheduled"):
    return {
        "operation": "update",
        "now": host.get("now") or datetime.now(UTC).isoformat(),
        "initiated": initiated,
        "evidence": evidence,
        "baseline": baseline,
        "candidate": candidate,
        "candidate_security": host.get("candidate_security", {}),
        "candidate_supplies_policy": candidate.get("supplies_policy", False),
        "policy_fingerprint_matches": host.get("policy_fingerprint_matches", True),
        "saved_plan_fingerprint": host.get("saved_plan_fingerprint", ""),
        "host": host,
        "policy_layers": layers,
    }


def plan_channel(channel, tools, evidence, baseline, layers, host, initiated="scheduled"):
    adapter = dict(ADAPTERS[channel])
    candidate = {
        "channel": channel,
        "fingerprint": "",
        "tools": tools,
        "dependencies": [] if adapter["can_constrain_dependencies"] else None,
        "removals": [],
        "runtime_closure_changed": [] if adapter["can_constrain_dependencies"] else None,
        "requires_reboot": channel == "macos",
        "adapter": adapter,
        "supplies_policy": False,
    }
    candidate["fingerprint"] = fingerprint(candidate)
    payload = build_input(candidate, evidence, baseline, layers, host, initiated)
    decision = evaluate_input(payload)
    return {"candidate": candidate, "decision": decision, "input": payload}


def check_plan(plan):
    if fingerprint(plan["candidate"]) != plan.get("candidate_fingerprint"):
        return "candidate changed after approval"
    return check_evidence_fingerprint(plan)


def check_evidence_fingerprint(plan):
    previous = plan.get("evidence_fingerprint")
    if not previous or previous != plan.get("current_evidence_fingerprint"):
        return "evidence changed after approval"
    return None


def apply_plan(plan, executor=None):
    reason = check_plan(plan)
    if reason:
        return {"applied": False, "reason": reason}
    return apply_authorized_plan(plan, executor)


def apply_authorized_plan(plan, executor):
    decision = evaluate_input(plan["input"])
    if decision["outcome"] != "allow":
        return {"applied": False, "reason": "; ".join(decision["reasons"])}
    if executor is None:
        return {"applied": False, "reason": "production apply is disabled"}
    executor(plan["candidate"])
    return {"applied": True, "reason": "test executor completed"}
