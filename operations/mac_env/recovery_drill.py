"""Disposable local backup/restore drill. Never targets a live home or root."""

import json
import os
import shutil
from pathlib import Path

from mac_env.backup import BackupError, ResticClient, require_password_file_mode, restore_files
from mac_env.files import atomic_write
from mac_env.validation import require


def resolve_restic(binary):
    chosen = binary or os.environ.get("MAC_ENV_RESTIC") or shutil.which("restic")
    require(bool(chosen), "restic binary missing; set MAC_ENV_RESTIC", BackupError)
    return confirm_restic(chosen)


def confirm_restic(chosen):
    path = Path(chosen)
    if path.exists():
        return str(path)
    found = shutil.which(chosen)
    require(bool(found), "restic binary missing; set MAC_ENV_RESTIC", BackupError)
    return found


def prepare_workspace(workspace):
    workspace = Path(workspace)
    require(not workspace.exists() or not any(workspace.iterdir()), "workspace must be empty")
    workspace.mkdir(parents=True, exist_ok=True, mode=0o700)
    source = workspace / "source"
    source.mkdir(mode=0o700)
    payload = source / "hello.txt"
    payload.write_text("mac-env-recovery-drill\n", encoding="utf-8")
    password = workspace / "password"
    password.write_text("drill-only-not-for-production\n", encoding="utf-8")
    password.chmod(0o600)
    require_password_file_mode(password)
    return {
        "workspace": workspace,
        "source": source,
        "payload": payload,
        "password": password,
        "repo": workspace / "repo",
        "restore": workspace / "restore",
        "manifest": workspace / "manifest.json",
    }


def run_recovery_drill(workspace, restic=None, runner=None):
    paths = prepare_workspace(workspace)
    binary = (restic or "restic") if runner else resolve_restic(restic)
    return execute_drill(paths, binary, runner)


def execute_drill(paths, binary, runner):
    config = {
        "repository": str(paths["repo"]),
        "password_file": str(paths["password"]),
        "restic": binary,
    }
    client = ResticClient(config, runner) if runner else ResticClient(config)
    client.init_repository()
    snapshot = client.backup([str(paths["source"])])
    client.verify(snapshot)
    write_drill_manifest(paths, config, snapshot)
    restore_files(snapshot, paths["restore"], config, client.runner)
    restored = find_restored_payload(paths["restore"])
    require(
        restored.read_text(encoding="utf-8") == "mac-env-recovery-drill\n",
        "restored payload mismatch",
        BackupError,
    )
    return {
        "ok": True,
        "snapshot_id": snapshot,
        "manifest": str(paths["manifest"]),
        "restored": str(restored),
        "repository": config["repository"],
    }


def write_drill_manifest(paths, config, snapshot):
    manifest = {
        "snapshot_id": snapshot,
        "repository": config["repository"],
        "paths": [str(paths["source"])],
        "drill": True,
    }
    atomic_write(paths["manifest"], json.dumps(manifest, indent=2) + "\n")


def find_restored_payload(root):
    matches = sorted(Path(root).rglob("hello.txt"))
    require(len(matches) == 1, "restored payload missing or ambiguous", BackupError)
    return matches[0]
