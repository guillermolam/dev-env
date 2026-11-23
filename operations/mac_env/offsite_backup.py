"""Operator-confirmed offsite restic init + verified snapshot (not local-restic)."""

import json
from pathlib import Path

from mac_env.backup import BackupError, ResticClient, require_password_file_mode
from mac_env.files import atomic_write
from mac_env.runtime import state_dir
from mac_env.validation import require
from mac_env.workflows import is_local_only_repository


def bootstrap_offsite_backup(
    repository, password_file, paths, confirm=False, restic=None, runner=None
):
    require(confirm, "offsite backup bootstrap requires --confirm", BackupError)
    require(bool(repository), "repository is required", BackupError)
    require(bool(paths), "at least one backup path required", BackupError)
    require(
        not is_local_only_repository(repository),
        "refusing local-only repository; use a remote or external path",
        BackupError,
    )
    require_password_file_mode(password_file)
    config = {
        "repository": repository,
        "password_file": str(Path(password_file).resolve()),
        "restic": restic or "restic",
    }
    snapshot = run_offsite_backup(config, paths, runner)
    manifest = write_offsite_manifest(config, paths, snapshot)
    return {
        "ok": True,
        "offsite": True,
        "snapshot_id": snapshot,
        "repository_scheme": repository_scheme(repository),
        "manifest": str(manifest),
        "note": "Offsite recovery point verified. Point MAC_ENV_RESTIC_* at this repo.",
    }


def run_offsite_backup(config, paths, runner):
    client = ResticClient(config, runner) if runner else ResticClient(config)
    ensure_repository(client, config["repository"])
    resolved = [str(Path(path).resolve()) for path in paths]
    snapshot = client.backup(resolved)
    client.verify(snapshot)
    return snapshot


def ensure_repository(client, repository):
    if path_repo_ready(repository):
        return
    if remote_repo_ready(client):
        return
    client.init_repository()


def path_repo_ready(repository):
    path = Path(repository)
    return path.is_dir() and any(path.iterdir())


def remote_repo_ready(client):
    listed = client.run(["snapshots", "--json"], timeout=60)
    return listed["code"] == 0


def write_offsite_manifest(config, paths, snapshot):
    destination = state_dir() / "offsite-restic"
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    manifest = destination / "manifest.json"
    document = {
        "snapshot_id": snapshot,
        "repository_scheme": repository_scheme(config["repository"]),
        "paths": [str(Path(path).resolve()) for path in paths],
        "bootstrap": True,
        "offsite": True,
    }
    atomic_write(manifest, json.dumps(document, indent=2) + "\n")
    return manifest


def repository_scheme(repository):
    if ":" in repository and not repository.startswith("/"):
        return repository.split(":", 1)[0]
    return "path"


def backup_status():
    import os

    from mac_env.workflows import is_local_only_repository

    repository = os.environ.get("MAC_ENV_RESTIC_REPOSITORY", "").strip()
    password = os.environ.get("MAC_ENV_RESTIC_PASSWORD_FILE", "").strip()
    return backup_status_body(repository, password, is_local_only_repository)


def backup_status_body(repository, password, local_check):
    from mac_env.workflows import backup_configuration_blockers

    local_only = bool(repository) and local_check(repository)
    return {
        "repository_configured": bool(repository),
        "password_file_configured": bool(password),
        "local_only": local_only,
        "offsite_ready": offsite_ready(repository, password, local_only),
        "repository_scheme": repository_scheme(repository) if repository else "",
        "blockers": backup_configuration_blockers(),
    }


def offsite_ready(repository, password, local_only):
    return bool(repository) and bool(password) and not local_only
