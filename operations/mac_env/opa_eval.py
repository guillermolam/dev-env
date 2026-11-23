"""Local OPA process boundary and validated decisions; failures never allow changes."""

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from mac_env.config import validate_document
from mac_env.validation import require, string_list

DROPPED_BUILTINS = {"time.now_ns", "opa.runtime"}
DROPPED_PREFIXES = ("http.", "net.")
DECISION_KEYS = {"outcome", "eligible", "reasons", "rule_ids", "affected_tools"}


class DecisionError(RuntimeError):
    pass


def policy_dir():
    return Path(os.environ.get("MAC_ENV_POLICY", Path(__file__).resolve().parents[1] / "policy"))


def find_opa():
    name = os.environ.get("MAC_ENV_OPA", "opa")
    found = shutil.which(name)
    return Path(found).resolve() if found else None


def block(reason, rule_id="MACENV-OPA"):
    return {
        "outcome": "block",
        "eligible": False,
        "reasons": [reason],
        "rule_ids": [rule_id],
        "affected_tools": [],
    }


def permitted_builtin(item):
    name = item.get("name", "")
    return name not in DROPPED_BUILTINS and not name.startswith(DROPPED_PREFIXES)


def restrict_capabilities(document):
    return {**document, "builtins": list(filter(permitted_builtin, document.get("builtins", [])))}


def controlled_env(directory):
    return {
        "PATH": "/usr/bin:/bin",
        "TMPDIR": str(directory),
        "HOME": str(directory),
        "LANG": "C.UTF-8",
    }


def opa_command(args, directory, timeout):
    result = subprocess.run(
        args, capture_output=True, text=True, timeout=timeout, env=controlled_env(directory)
    )
    require(result.returncode == 0, "OPA evaluation failed", DecisionError)
    return json.loads(result.stdout)


def capabilities_file(opa, directory):
    raw = opa_command([str(opa), "capabilities", "--current"], directory, 20)
    document = restrict_capabilities(raw)
    names = {item["name"] for item in document["builtins"]}
    require(
        not names.intersection({"http.send", "time.now_ns"}), "unsafe OPA capability", DecisionError
    )
    require("time.parse_rfc3339_ns" in names, "required OPA capability missing", DecisionError)
    path = directory / "capabilities.json"
    path.write_text(json.dumps(document))
    return path


def validate_decision(document):
    require(isinstance(document, dict), "malformed decision", DecisionError)
    require(DECISION_KEYS <= document.keys(), "malformed decision", DecisionError)
    check_decision_fields(document)
    check_decision_outcome(document)
    return {key: document[key] for key in sorted(DECISION_KEYS)}


def check_decision_fields(document):
    require(document["outcome"] in {"allow", "defer", "block"}, "malformed outcome", DecisionError)
    require(type(document["eligible"]) is bool, "malformed eligibility", DecisionError)
    for key in ("reasons", "rule_ids", "affected_tools"):
        require(string_list(document[key]), f"malformed {key}", DecisionError)


def check_decision_outcome(document):
    allowed = document["outcome"] == "allow"
    require(document["eligible"] == allowed, "outcome does not match eligibility", DecisionError)
    require(bool(document["reasons"]) != allowed, "outcome does not match reasons", DecisionError)


def validate_layers(payload):
    require(isinstance(payload, dict), "input must be an object", DecisionError)
    layers = payload.get("policy_layers", {})
    require(isinstance(layers, dict), "policy layers must be an object", DecisionError)
    for layer in layers.values():
        validate_layer(layer)


def validate_layer(layer):
    require(isinstance(layer, dict), "policy layer must be an object", DecisionError)
    errors = validate_document({"schema_version": 1, **layer})
    require(not errors, "; ".join(errors), DecisionError)


def parse_decision(parsed):
    expressions = parsed["result"][0]["expressions"]
    require(len(parsed["result"]) == 1, "expected one result", DecisionError)
    require(len(expressions) == 1, "expected one decision", DecisionError)
    return validate_decision(expressions[0]["value"])


def evaluate_process(opa, payload, timeout):
    with tempfile.TemporaryDirectory(prefix="mac-env-opa-") as raw:
        return evaluate_directory(opa, payload, timeout, Path(raw))


def evaluate_directory(opa, payload, timeout, directory):
    capabilities = capabilities_file(opa, directory)
    input_path = directory / "input.json"
    input_path.write_text(json.dumps(payload))
    args = [
        str(opa),
        "eval",
        "--format",
        "json",
        "--fail",
        "--strict",
        "--strict-builtin-errors",
        f"--timeout={timeout}s",
        "--capabilities",
        str(capabilities),
        "--data",
        str(policy_dir()),
        "--input",
        str(input_path),
        "data.macenv.decision.decision",
    ]
    parsed = opa_command(args, directory, timeout + 10)
    return checked_decision(parsed)


def checked_decision(parsed):
    try:
        return parse_decision(parsed)
    except (KeyError, IndexError, TypeError, DecisionError):
        return block("malformed OPA decision", "MACENV-OPA-MALFORMED")


def evaluate_input(payload, timeout_seconds=10):
    opa = find_opa()
    if opa is None:
        return block("OPA decision unavailable", "MACENV-OPA-MISSING")
    return evaluate_available(opa, payload, timeout_seconds)


def evaluate_available(opa, payload, timeout):
    try:
        validate_layers(payload)
        return evaluate_process(opa, payload, timeout)
    except (OSError, subprocess.TimeoutExpired, DecisionError, ValueError, TypeError, KeyError):
        return block("OPA decision unavailable or invalid policy", "MACENV-OPA-UNAVAILABLE")
