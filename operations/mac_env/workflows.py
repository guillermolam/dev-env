"""Provisioning, daily read-only orchestration, recovery planning, and readiness."""

import json
import os
import tomllib
from pathlib import Path

from policy import REQUIRED

from mac_env.files import atomic_write
from mac_env.opa_eval import find_opa
from mac_env.runtime import (
    INSTALLED_STATE_DIR,
    OperationLock,
    log_event,
    resolve_state_dir,
    state_dir,
)
from mac_env.security import collect_security
from mac_env.validation import require, require_mapping


def provision_plan(project):
    project = Path(project)
    return {
        "architecture": "aarch64-darwin",
        "host": "mac-studio",
        "declared_packages": ["nil", "nixfmt", "nix-tree"],
        "unmanaged": ["Brewfile", ".zshrc", ".gitconfig", ".ssh"],
        "folders": ["Documents", "Desktop", "Downloads", "Pictures", "Git"],
        "source": str(project),
        "destructive": False,
    }


def provision_apply(plan, target):
    target = Path(target)
    created, skipped = [], []
    for name in plan["folders"]:
        path = target / name
        if path.exists():
            skipped.append(str(path))
            continue
        path.mkdir(parents=True, mode=0o700)
        created.append(str(path))
    return {"created": created, "skipped": skipped, "deleted": []}


def validate_baseline_records(evidence):
    require_mapping(evidence, "evidence")
    records = evidence.get("evidence", evidence)
    require_mapping(records, "evidence records")
    require(REQUIRED <= records.keys(), "baseline requires every collector", RuntimeError)
    for record in records.values():
        require_healthy_record(record)
    return records


def require_healthy_record(record):
    require_mapping(record, "collector")
    require(
        record.get("status") == "ok", "unhealthy evidence cannot become a baseline", RuntimeError
    )


def approve_baseline(evidence, output, approver, confirm=False):
    require(confirm, "baseline approval requires explicit confirmation", RuntimeError)
    require(bool(approver), "approver is required", RuntimeError)
    records = validate_baseline_records(evidence)
    document = {"approver": approver, "evidence": records, "automatic": False}
    path = Path(output)
    atomic_write(path, json.dumps(document, indent=2) + "\n")
    return document


def daily(project):
    with OperationLock():
        security = collect_security()
        summary = {
            "event": "daily",
            "applied_updates": False,
            "backup_created": False,
            "coverage_gaps": security["coverage_gaps"],
            "blockers": deployment_blockers(),
        }
        destination = state_dir() / "reports"
        destination.mkdir(parents=True, exist_ok=True, mode=0o700)
        (destination / "latest.json").write_text(json.dumps(summary, indent=2) + "\n")
        log_event("daily", backup_created=False, gaps=len(security["coverage_gaps"]))
        return summary


def doctor():
    blockers = deployment_blockers()
    opa = find_opa()
    state = resolve_state_dir()
    report = {
        "ready": not blockers,
        "opa": str(opa) if opa else None,
        "policy_evaluation_available": opa is not None,
        "blockers": blockers,
        "state_dir": str(state),
        "state_dir_exists": state.is_dir(),
        "using_installed_state": state == INSTALLED_STATE_DIR,
        "system_install": INSTALLED_STATE_DIR.is_dir(),
        "schedule_enabled": False,
    }
    hint = offsite_recovery_hint(blockers)
    if hint:
        report["next"] = hint
    return report


def offsite_recovery_hint(blockers):
    joined = " ".join(blockers)
    if not backup_needs_offsite_hint(joined):
        return ""
    return (
        "make offsite-preflight; then rclone config (R2 Path C) or "
        "netbird up; then sh scripts/bootstrap-offsite-once.sh --confirm "
        "(docs/operations/offsite-restic.md)"
    )


def backup_needs_offsite_hint(joined):
    return "local-only" in joined or "backup destination is not configured" in joined


def approved_baseline_present():
    try:
        approved = json.loads((resolve_state_dir() / "baseline.json").read_text())
        return baseline_has_approval(approved)
    except (OSError, ValueError):
        return False


def baseline_has_approval(approved):
    if not isinstance(approved, dict):
        return False
    return bool(approved.get("approver")) and approved.get("automatic") is False


def backup_configuration_blockers():
    required = {
        "MAC_ENV_RESTIC_REPOSITORY": "backup destination is not configured",
        "MAC_ENV_RESTIC_PASSWORD_FILE": "backup credential reference is not configured",
    }
    blockers = [message for name, message in required.items() if not os.environ.get(name)]
    blockers.extend(local_only_backup_blockers())
    return blockers


def local_only_backup_blockers():
    repository = os.environ.get("MAC_ENV_RESTIC_REPOSITORY", "").strip()
    if not repository:
        return []
    if not is_local_only_repository(repository):
        return []
    return ["backup destination is local-only; configure offsite MAC_ENV_RESTIC_REPOSITORY"]


def is_local_only_repository(repository):
    normalized = repository.replace("\\", "/")
    if "/local-restic/" in normalized or normalized.endswith("/local-restic"):
        return True
    return repository_under_local_restic(repository)


def repository_under_local_restic(repository):
    try:
        path = Path(repository).resolve()
        marker = (resolve_state_dir() / "local-restic").resolve()
    except OSError:
        return False
    return path == marker or marker in path.parents


def deployment_blockers():
    blockers = backup_configuration_blockers()
    if not approved_baseline_present():
        blockers.append("approved baseline is not present")
    blockers.extend(security_coverage_blockers())
    return blockers


def security_coverage_blockers():
    gaps = collect_security()["coverage_gaps"]
    if not gaps:
        return []
    return ["security coverage incomplete: " + "; ".join(gaps)]


def load_toml(path):
    with Path(path).open("rb") as handle:
        return tomllib.load(handle)
