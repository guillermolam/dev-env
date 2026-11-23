"""Logging, locking, redaction, and controlled process execution."""

import fcntl
import json
import os
import re
import subprocess
import sys
from datetime import UTC, datetime
from functools import singledispatch
from pathlib import Path

from mac_env.validation import nonempty_string, require

SECRET_PATTERNS = (
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"ghp_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"(?i)(password|secret|token|api[_-]?key)\s*[:=]\s*\S+"),
    re.compile(r"https?://[^/\s:@]+:[^/\s@]+@"),
    re.compile(r"Bearer\s+[A-Za-z0-9._\-]{8,}"),
)


class LockError(RuntimeError):
    pass


INSTALLED_STATE_DIR = Path("/private/var/lib/mac-environment")
INSTALLED_LOG_DIR = Path("/private/var/log/mac-environment")


def user_state_dir():
    return Path.home() / ".local" / "state" / "mac-environment"


def resolve_state_dir():
    override = os.environ.get("MAC_ENV_STATE_DIR", "").strip()
    if override:
        return Path(override)
    if os.environ.get("MAC_ENV_USE_INSTALLED_STATE") == "1":
        return INSTALLED_STATE_DIR
    return user_state_dir()


def state_dir():
    path = resolve_state_dir()
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    return path


@singledispatch
def redact(value):
    return value


@redact.register(str)
def redact_text(value):
    for pattern in SECRET_PATTERNS:
        value = pattern.sub("[redacted]", value)
    return value


@redact.register(dict)
def redact_mapping(value):
    return {key: redact(item) for key, item in value.items()}


@redact.register(list)
def redact_sequence(value):
    return list(map(redact, value))


def valid_argument(value):
    return nonempty_string(value) and "\x00" not in value


def log_event(event, **fields):
    record = redact(
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "event": event,
            **fields,
        }
    )
    print(json.dumps(record, sort_keys=True), file=sys.stderr, flush=True)
    return record


def run_command(args, timeout=60, env=None, cwd=None):
    require(bool(args), "command arguments must be non-empty")
    require(all(map(valid_argument, args)), "command arguments must be non-empty strings")
    try:
        completed = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
            env=env if env is not None else {**os.environ, "HOMEBREW_NO_AUTO_UPDATE": "1"},
            shell=False,
        )
    except FileNotFoundError as error:
        return command_failure(args, 127, str(error))
    return {
        "args": args,
        "code": completed.returncode,
        "stdout": completed.stdout,
        "stderr": redact(completed.stderr),
    }


def command_failure(args, code, detail):
    return {"args": args, "code": code, "stdout": "", "stderr": redact(detail)}


class OperationLock:
    def __init__(self, path=None):
        self.path = Path(path) if path else state_dir() / "operation.lock"
        self.handle = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.handle = self.path.open("a+")
        try:
            fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            self.handle.close()
            raise LockError("another environment operation holds the lock") from error
        return self

    def __exit__(self, *_):
        fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        self.handle.close()
