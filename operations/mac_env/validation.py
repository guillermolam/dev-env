"""Small validation primitives shared by the controller's trust boundaries."""

from collections.abc import Mapping


def require(condition: bool, message: str, error: type[Exception] = ValueError) -> None:
    if not condition:
        raise error(message)


def nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value)


def string_list(value: object) -> bool:
    return isinstance(value, list) and all(map(nonempty_string, value))


def require_mapping(value: object, label: str) -> None:
    require(isinstance(value, Mapping), f"{label}: must be a table")


def require_keys(value: Mapping, allowed: set, label: str) -> None:
    unexpected = value.keys() - allowed
    require(not unexpected, f"{label}: unknown keys {sorted(unexpected)}")
