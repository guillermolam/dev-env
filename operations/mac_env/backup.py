"""Restic backup and selective restore; publish only after successful verification."""

import json
import os
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from mac_env.files import atomic_write as atomic_write
from mac_env.runtime import run_command
from mac_env.validation import require


class BackupError(RuntimeError):
    pass


def repository_config():
    return {
        "repository": os.environ.get("MAC_ENV_RESTIC_REPOSITORY", ""),
        "password_file": os.environ.get("MAC_ENV_RESTIC_PASSWORD_FILE", ""),
        "restic": os.environ.get("MAC_ENV_RESTIC", "restic"),
    }


@dataclass
class ResticClient:
    config: dict
    runner: Callable = run_command

    def run(self, arguments, timeout=3600):
        args = [
            self.config["restic"],
            "--repo",
            self.config["repository"],
            "--password-file",
            self.config["password_file"],
            *arguments,
        ]
        return self.runner(args, timeout=timeout, env=restic_env(self.config))

    def validate(self):
        require(
            bool(self.config.get("repository")), "backup destination is not configured", BackupError
        )
        require(
            bool(self.config.get("password_file")),
            "backup credential reference is not configured",
            BackupError,
        )
        require_password_file_mode(self.config["password_file"])

    def init_repository(self):
        self.validate()
        result = self.run(["init"])
        require(result["code"] == 0, "repository init failed", BackupError)

    def backup(self, paths):
        self.validate()
        result = self.run(["backup", "--json", "--", *paths])
        check_backup_result(result)
        snapshot = parse_snapshot_id(result["stdout"])
        require(bool(snapshot), "backup did not report a snapshot id", BackupError)
        return snapshot

    def verify(self, snapshot):
        listed = self.run(["snapshots", "--json", snapshot], timeout=300)
        require(listed["code"] == 0, "snapshot verification failed", BackupError)
        require(snapshot in listed["stdout"], "snapshot verification failed", BackupError)
        checked = self.run(["check"])
        require(checked["code"] == 0, "repository check failed", BackupError)


def check_backup_result(result):
    require(result["code"] != 3, "partial backup is not a recovery point", BackupError)
    require(result["code"] == 0, backup_failure_message(result), BackupError)


def backup_failure_message(result):
    return "backup failed: " + command_detail(result)


def command_detail(result):
    text = str(result.get("stderr") or "")
    return text.strip() or "no stderr"


def require_password_file_mode(path):
    target = Path(path)
    require(target.is_file(), "backup credential reference is not a file", BackupError)
    mode = target.stat().st_mode & 0o777
    require(mode & 0o077 == 0, "password file must not be group/world readable", BackupError)


def create_backup(decision, paths, manifest_path, config=None, runner=run_command):
    require(
        decision.get("eligible") is True,
        "backup blocked: " + "; ".join(decision.get("reasons", [])),
        BackupError,
    )
    client = ResticClient(config or repository_config(), runner)
    snapshot = client.backup(paths)
    client.verify(snapshot)
    manifest = {
        "snapshot_id": snapshot,
        "repository": client.config["repository"],
        "paths": paths,
        "decision": {"eligible": True, "rule_ids": decision.get("rule_ids", [])},
    }
    atomic_write(Path(manifest_path), json.dumps(manifest, indent=2) + "\n")
    return manifest


def verify_snapshot(snapshot, config, runner=run_command):
    client = ResticClient(config, runner)
    client.validate()
    client.verify(snapshot)


def check_restore_destination(destination):
    require(
        destination.resolve() not in {Path("/"), Path.home().resolve()},
        "refusing to restore over a live root",
        BackupError,
    )
    if destination.exists():
        require(
            not any(destination.iterdir()),
            "restore destination must be a new empty directory",
            BackupError,
        )


def restore_files(snapshot, destination, config=None, runner=run_command):
    destination = Path(destination)
    check_restore_destination(destination)
    client = ResticClient(config or repository_config(), runner)
    client.validate()
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    result = client.run(["restore", snapshot, "--target", str(destination)])
    require(result["code"] == 0, "restore failed", BackupError)
    return destination


def snapshot_from_line(line):
    try:
        document = json.loads(line)
    except json.JSONDecodeError:
        return None
    return snapshot_from_document(document)


def snapshot_from_document(document):
    if not isinstance(document, dict):
        return None
    return string_or_none(document.get("snapshot_id"))


def string_or_none(value):
    return value if isinstance(value, str) and value else None


def parse_snapshot_id(stdout):
    return next(filter(None, map(snapshot_from_line, stdout.splitlines())), None)


def restic_env(config):
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", ""),
        "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
        "RESTIC_REPOSITORY": config["repository"],
    }
    if config.get("password_file"):
        env["RESTIC_PASSWORD_FILE"] = config["password_file"]
    return env
