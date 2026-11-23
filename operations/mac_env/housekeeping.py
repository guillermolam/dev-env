"""Local scanning and explicit quarantine with a durable undo manifest."""

import hashlib
import json
import os
import shutil
from pathlib import Path

from mac_env.files import atomic_write
from mac_env.runtime import SECRET_PATTERNS, redact
from mac_env.validation import require


def scan(root, output):
    root = Path(root).resolve()
    matches = list(filter(None, map(scan_file, walk(root))))
    report = {
        "root": str(root),
        "matches": matches,
        "ocr": "local OCR detector is not configured; image coverage is incomplete",
        "proposed_only": True,
    }
    destination = Path(output)
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    atomic_write(destination / "housekeeping.json", json.dumps(report, indent=2) + "\n")
    return report


def scan_file(path):
    if path.is_symlink():
        return summary(path, "symlink skipped")
    try:
        return inspect_file(path)
    except OSError:
        return summary(path, "unreadable")


def inspect_file(path):
    if not path.is_file():
        return summary(path, "not a regular file")
    if path.stat().st_size > 1_000_000:
        return summary(path, "file too large for this scanner")
    return inspect_text(path, path.read_text(errors="ignore"))


def inspect_text(path, text):
    if any(pattern.search(text) for pattern in SECRET_PATTERNS):
        return summary(path, "possible secret or credential")
    return None


def quarantine_entry(item, root, destination):
    source = Path(item["path"])
    require(not source.is_symlink(), "refusing to quarantine a symlink")
    source.resolve().relative_to(root)
    require(source.is_file(), "source must be a regular file")
    name = item["id"]
    require(Path(name).name == name, "invalid quarantine id")
    require(name not in {".", "..", "undo.json"}, "invalid quarantine id")
    target = destination / name
    require(not os.path.lexists(target), "quarantine target already exists")
    return {"id": name, "path": str(source), "quarantine_path": str(target)}


def quarantine_entries(plan, destination):
    root = Path(plan["root"]).resolve()
    entries = [quarantine_entry(item, root, destination) for item in plan.get("matches", [])]
    names = {entry["id"] for entry in entries}
    require(len(names) == len(entries), "duplicate quarantine ids")
    return entries


def quarantine(plan_path, quarantine_root):
    plan = json.loads(Path(plan_path).read_text())
    destination = Path(quarantine_root)
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    require(not os.path.lexists(destination / "undo.json"), "use a new quarantine directory")
    entries = quarantine_entries(plan, destination)
    manifest = {"moved": entries}
    atomic_write(destination / "undo.json", json.dumps(manifest, indent=2) + "\n")
    for entry in entries:
        shutil.move(entry["path"], entry["quarantine_path"])
    return manifest


def restore_quarantined(entry):
    source = Path(entry["quarantine_path"])
    destination = Path(entry["path"])
    if not source.exists():
        require(destination.exists(), "quarantined file is missing")
        return
    require(
        not os.path.lexists(destination),
        "refusing to overwrite during quarantine undo",
        FileExistsError,
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(source, destination)


def undo(manifest_path):
    manifest = json.loads(Path(manifest_path).read_text())
    for entry in manifest["moved"]:
        restore_quarantined(entry)
    return manifest


def directory_names(paths):
    return sorted(path.name for path in paths)


def split_directories(directory, names):
    paths = [Path(directory) / name for name in names]
    symlinks = list(filter(Path.is_symlink, paths))
    kept = directory_names(set(paths) - set(symlinks))
    return kept, symlinks


def walk(root):
    for directory, dirnames, filenames in os.walk(root, followlinks=False):
        kept, symlinks = split_directories(directory, dirnames)
        dirnames[:] = kept
        yield from symlinks
        yield from (Path(directory) / name for name in filenames)


def summary(path, reason):
    return {
        "id": hashlib.sha256(str(path).encode()).hexdigest()[:16],
        "path": str(path),
        "reason": reason,
        "public_name": "[redacted-name]" if redact(path.name) != path.name else path.name,
    }
