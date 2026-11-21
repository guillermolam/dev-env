"""User-managed per-tool update policy. Editing it does not install or update software."""

import json
import os
import tomllib
from datetime import UTC, datetime
from functools import singledispatch

from mac_env.config import validate_document
from mac_env.files import atomic_write
from mac_env.runtime import state_dir
from mac_env.validation import require


def policy_path():
    path = state_dir() / "policy" / "tools.toml"
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path


def load_tools():
    path = policy_path()
    if not path.exists():
        return {"schema_version": 1, "tools": {}}
    with path.open("rb") as handle:
        document = tomllib.load(handle)
    document.setdefault("schema_version", 1)
    document.setdefault("tools", {})
    return document


def list_tools():
    return load_tools().get("tools", {})


def set_tool(tool_id, mode, reason="", pin=""):
    document = load_tools()
    spec = {"mode": mode}
    if reason:
        spec["reason"] = reason
    if pin:
        spec["pin"] = pin
    document.setdefault("tools", {})[tool_id] = spec
    _write(document)
    _journal("set", tool_id, mode)
    return spec


def remove_tool(tool_id):
    document = load_tools()
    document.setdefault("tools", {}).pop(tool_id, None)
    _write(document)
    _journal("remove", tool_id, "manual")
    return document["tools"]


def _write(document):
    errors = validate_document(document, "tools")
    require(not errors, "; ".join(errors))
    path = policy_path()
    atomic_write(path, _render(document))


def _render(document):
    return "\n".join(toml_pair(key, value) for key, value in document.items()) + "\n"


def toml_pair(key, value):
    return f"{json.dumps(key)} = {toml_value(value)}"


@singledispatch
def toml_value(value):
    return json.dumps(value)


@toml_value.register(dict)
def toml_table(value):
    return "{ " + ", ".join(toml_pair(key, item) for key, item in value.items()) + " }"


@toml_value.register(list)
def toml_array(value):
    return "[" + ", ".join(map(toml_value, value)) + "]"


def _journal(action, tool_id, mode):
    path = policy_path().with_name("tools.journal.jsonl")
    record = {
        "timestamp": datetime.now(UTC).isoformat(),
        "action": action,
        "tool_id": tool_id,
        "mode": mode,
    }
    with path.open("a") as handle:
        handle.write(json.dumps(record) + "\n")
    os.chmod(path, 0o600)
