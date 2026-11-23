"""Validate policy documents without deciding eligibility."""

import re
from datetime import datetime

from mac_env.validation import nonempty_string, require, require_keys, require_mapping

MODES = {"auto", "hold", "manual"}
EXCEPTION_FIELDS = {"id", "scope", "reason", "approver", "expires_at"}
ROOT_FIELDS = {"schema_version", "updates", "tools", "channels", "hosts", "exceptions"}
TIME_VALUE = re.compile(r"^(?:[01][0-9]|2[0-3]):[0-5][0-9]$")


def mode(value):
    return isinstance(value, str) and value in MODES


def boolean(value):
    return type(value) is bool


def nonnegative_integer(value):
    return type(value) is int and value >= 0


def clock_time(value):
    return isinstance(value, str) and bool(TIME_VALUE.fullmatch(value))


UPDATE_FIELDS = {
    "default_tool_mode": mode,
    "allow_reboot": boolean,
    "allow_major": boolean,
    "allow_removals": boolean,
    "require_rollback": boolean,
    "require_ac_power": boolean,
    "max_evidence_age_seconds": nonnegative_integer,
    "max_backup_age_seconds": nonnegative_integer,
    "max_new_findings": nonnegative_integer,
    "max_critical": nonnegative_integer,
    "min_free_bytes": nonnegative_integer,
    "maintenance_start": clock_time,
    "maintenance_end": clock_time,
}
TOOL_FIELDS = {
    "mode": mode,
    "reason": nonempty_string,
    "pin": nonempty_string,
    "allow_major": boolean,
}


def validate_document(document, label="policy"):
    try:
        check_document(document, label)
    except ValueError as error:
        return [str(error)]
    return []


def check_fields(document, schema, label):
    require_mapping(document, label)
    require_keys(document, schema.keys(), label)
    for key, value in document.items():
        require(schema[key](value), f"{label}.{key}: invalid value")


def check_document(document, label):
    require_mapping(document, label)
    require_keys(document, ROOT_FIELDS, label)
    require(type(document.get("schema_version")) is int, f"{label}: invalid schema version")
    require(document.get("schema_version") == 1, f"{label}: schema_version must be 1")
    check_layer(document, label)
    check_scopes(document.get("channels", {}), f"{label}.channels")
    check_scopes(document.get("hosts", {}), f"{label}.hosts")


def check_layer(document, label):
    check_fields(document.get("updates", {}), UPDATE_FIELDS, f"{label}.updates")
    check_tools(document.get("tools", {}), f"{label}.tools")
    check_exceptions(document.get("exceptions", []), f"{label}.exceptions")


def check_scopes(scopes, label):
    require_mapping(scopes, label)
    for name, value in scopes.items():
        check_scope(value, f"{label}.{name}")


def check_scope(value, label):
    require_mapping(value, label)
    if "updates" not in value:
        check_fields(value, UPDATE_FIELDS, label)
        return
    require_keys(value, {"updates", "tools", "exceptions"}, label)
    check_layer(value, label)


def check_tools(tools, label):
    require_mapping(tools, label)
    for tool_id, spec in tools.items():
        check_tool(tool_id, spec, label)


def check_tool(tool_id, spec, label):
    require(isinstance(tool_id, str), f"{label}: tool id must be a string")
    require(tool_id.count(":") >= 2, f"{label}: tool id is not namespaced")
    check_fields(spec, TOOL_FIELDS, f"{label}.{tool_id}")
    if spec.get("mode") in {"hold", "manual"}:
        require(nonempty_string(spec.get("reason")), f"{label}.{tool_id}: reason is required")


def check_exceptions(exceptions, label):
    require(isinstance(exceptions, list), f"{label}: must be a list")
    for index, item in enumerate(exceptions):
        check_exception(item, f"{label}[{index}]")


def check_exception(item, label):
    require_mapping(item, label)
    require(item.keys() == EXCEPTION_FIELDS, f"{label}: invalid exception fields")
    require(all(map(nonempty_string, item.values())), f"{label}: fields must be non-empty strings")
    expires = datetime.fromisoformat(item["expires_at"])
    require(expires.tzinfo is not None, f"{label}: permanent or naive exceptions are rejected")
