"""Scoped HOME agent metadata inventory. No secret values; hashes only."""

import csv
import hashlib
import json
import os
from datetime import UTC, datetime
from pathlib import Path

from mac_env.files import atomic_write
from mac_env.validation import require

COLLECTOR_VERSION = "1"
AGENT_HOME_NAMES = (
    ".codex",
    ".claude",
    ".cursor",
    ".continue",
    ".config",
    ".agents",
)
CONFIG_SUFFIXES = (".json", ".jsonl", ".toml", ".yaml", ".yml", ".md", ".plist")
FIELDS = (
    "record_id",
    "kind",
    "name",
    "path",
    "resolved_path",
    "owner_mode",
    "config_hash",
    "symlink_target",
    "coverage",
    "notes",
)


def inventory_agents(root, output, now=None):
    root = Path(root)
    require(root.is_dir(), "inventory root must be a directory")
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    observed_at = (now or datetime.now(UTC)).isoformat()
    rows, errors = collect_agent_rows(root)
    report = {
        "collector_version": COLLECTOR_VERSION,
        "observed_at": observed_at,
        "root": str(root),
        "rows": rows,
        "errors": errors,
        "coverage_complete": not errors,
    }
    write_inventory_outputs(output, report)
    return report


def collect_agent_rows(root):
    rows, errors = [], []
    for name in AGENT_HOME_NAMES:
        path = root / name
        rows.extend(inspect_path(path, name, errors))
    rows.extend(inspect_launch_agents(root, errors))
    return rows, errors


def inspect_path(path, name, errors):
    if not path.exists():
        return [missing_row(name, path)]
    return inspect_existing(path, name, errors)


def inspect_existing(path, name, errors):
    if path.is_symlink():
        return [symlink_row(name, path, errors)]
    if path.is_dir():
        return directory_rows(name, path, errors)
    return [file_row("agent_home_file", name, path, errors)]


def missing_row(name, path):
    return row("agent_home", name, path, coverage="absent", notes="not present")


def symlink_row(name, path, errors):
    target, coverage = safe_symlink_target(path, errors)
    return row(
        "agent_home_symlink",
        name,
        path,
        resolved=target,
        symlink_target=target,
        coverage=coverage,
    )


def directory_rows(name, path, errors):
    rows = [row("agent_home", name, path, coverage="present", notes="directory")]
    rows.extend(config_children(name, path, errors))
    return rows


def config_children(name, path, errors):
    return [
        file_row("agent_config", child.name, child, errors)
        for child in list_children(path, errors)
        if is_config_file(child)
    ]


def is_config_file(path):
    return path.is_file() and path.suffix.lower() in CONFIG_SUFFIXES


def inspect_launch_agents(root, errors):
    launch = root / "Library" / "LaunchAgents"
    if not launch.is_dir():
        return [missing_row("LaunchAgents", launch)]
    return launch_agent_rows(launch, errors)


def launch_agent_rows(launch, errors):
    rows = [row("startup", "LaunchAgents", launch, coverage="present")]
    for child in list_plists(launch, errors):
        rows.append(file_row("launch_agent", child.name, child, errors))
    return rows


def list_children(path, errors):
    try:
        return sorted(path.iterdir())
    except OSError as error:
        errors.append(f"{path}: {error}")
        return []


def list_plists(launch, errors):
    try:
        return sorted(launch.glob("*.plist"))
    except OSError as error:
        errors.append(f"{launch}: {error}")
        return []


def file_row(kind, name, path, errors):
    digest, coverage = hash_file(path, errors)
    mode = file_mode(path, errors)
    return row(kind, name, path, owner_mode=mode, config_hash=digest, coverage=coverage)


def hash_file(path, errors):
    try:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        errors.append(f"{path}: {error}")
        return "", "unreadable"
    return digest, "hashed"


def file_mode(path, errors):
    try:
        return oct(path.stat().st_mode & 0o777)
    except OSError as error:
        errors.append(f"{path}: {error}")
        return ""


def safe_symlink_target(path, errors):
    try:
        target = os.readlink(path)
    except OSError as error:
        errors.append(f"{path}: {error}")
        return "", "unreadable_symlink"
    return target, "symlink"


def row(
    kind,
    name,
    path,
    resolved="",
    owner_mode="",
    config_hash="",
    symlink_target="",
    coverage="unknown",
    notes="",
):
    path = Path(path)
    return {
        "record_id": f"{kind}:{name}:{path}",
        "kind": kind,
        "name": name,
        "path": str(path),
        "resolved_path": resolved or str(path),
        "owner_mode": owner_mode,
        "config_hash": config_hash,
        "symlink_target": symlink_target,
        "coverage": coverage,
        "notes": notes,
    }


def write_inventory_outputs(output, report):
    atomic_write(output / "agents.json", json.dumps(report, indent=2) + "\n")
    write_csv(output / "agents.csv", report["rows"])
    atomic_write(output / "agents.md", markdown_summary(report))


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        for item in rows:
            writer.writerow({key: item.get(key, "") for key in FIELDS})


def markdown_summary(report):
    lines = markdown_header(report)
    lines.extend(markdown_rows(report["rows"]))
    lines.extend(markdown_errors(report["errors"]))
    return "\n".join(lines) + "\n"


def markdown_header(report):
    return [
        "# Agent inventory",
        "",
        f"- collector: {report['collector_version']}",
        f"- observed_at: {report['observed_at']}",
        f"- root: {report['root']}",
        f"- rows: {len(report['rows'])}",
        f"- errors: {len(report['errors'])}",
        f"- coverage_complete: {report['coverage_complete']}",
        "",
        "| kind | name | coverage | mode | hash |",
        "| --- | --- | --- | --- | --- |",
    ]


def markdown_rows(rows):
    return [markdown_row(item) for item in rows]


def markdown_row(item):
    digest = (item.get("config_hash") or "")[:12]
    return (
        f"| {item['kind']} | {item['name']} | {item['coverage']} | "
        f"{item.get('owner_mode', '')} | {digest} |"
    )


def markdown_errors(errors):
    if not errors:
        return []
    return ["", "## Errors", ""] + [f"- {error}" for error in errors]
