"""Inventory identities, parsers and comparisons independent of collection I/O."""

import hashlib
import json
import shutil
from pathlib import Path

from inventory import collect, export

from mac_env.runtime import run_command
from mac_env.validation import require


def record_id(row):
    return ":".join(str(row.get(key, "")) for key in ("kind", "name", "path"))


def fingerprint_rows(rows):
    encoded = json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def enrich_row(row):
    row["record_id"] = record_id(row)
    row.setdefault("confidence", "observed")


def enrich(report, git_classifier=None):
    for row in report.get("rows", []):
        enrich_row(row)
    classify_probes(report.get("probes", []), git_classifier)
    return report


def failed_git_head(probe):
    command = probe.get("command", [])
    expected = command[:1] == ["git"] and command[-2:] == ["rev-parse", "HEAD"]
    return probe.get("status") == "failed" and expected


def classify_probes(probes, classifier):
    if classifier is None:
        return
    for probe in filter(failed_git_head, probes):
        classify_probe(probe, classifier)


def classify_probe(probe, classifier):
    kind = classifier(probe["command"][2])
    probe["classification"] = kind
    if kind == "empty_repository":
        probe.update(status="ok", note="valid repository with no commits")


def classify_git(path, runner):
    inside = runner(["git", "-C", str(path), "rev-parse", "--is-inside-work-tree"])
    if inside["code"] != 0:
        return "not_a_repository"
    head = runner(["git", "-C", str(path), "rev-parse", "HEAD"])
    return "has_commits" if head["code"] == 0 else "empty_repository"


def parse_nix_profile(document):
    require(isinstance(document, dict), "unsupported nix profile schema")
    require(isinstance(document.get("elements"), list), "unsupported nix profile schema")
    return list(map(nix_row, document["elements"]))


def nix_name(element):
    return element.get("attrPath") or element.get("originalUrl") or "unknown"


def nix_confidence(element):
    return "observed" if element.get("attrPath") or element.get("storePaths") else "unknown"


def nix_row(element):
    require(isinstance(element, dict), "unsupported nix profile element")
    return {
        "kind": "nix_package",
        "name": nix_name(element),
        "version": "",
        "install_method": "Nix profile",
        "path": " ".join(element.get("storePaths", [])),
        "provenance": "nix profile list --json",
        "evidence": "nix profile list --json",
        "confidence": nix_confidence(element),
        "notes": "Original installer identity is not available from the profile",
    }


def parse_brew_receipts(document):
    require(isinstance(document, dict), "unsupported Homebrew receipt schema")
    return brew_rows(document.get("formulae", []), "formula") + brew_rows(
        document.get("casks", []), "cask"
    )


def brew_rows(items, category):
    require(isinstance(items, list), "unsupported Homebrew receipt schema")
    return [_brew_row(item, category) for item in items]


def installed_version(item):
    installed = item.get("installed") or item.get("installed_versions") or []
    return last_version(installed)


def last_version(installed):
    if not isinstance(installed, list) or not installed:
        return ""
    return version_value(installed[-1])


def version_value(value):
    return value.get("version", "") if isinstance(value, dict) else str(value)


def _brew_row(item, category):
    require(isinstance(item, dict), "unsupported Homebrew receipt")
    name = item.get("token") or item.get("name")
    require(bool(name), "unsupported Homebrew receipt")
    return {
        "kind": "package",
        "name": name,
        "version": installed_version(item),
        "install_method": f"Homebrew {category}",
        "path": "",
        "provenance": "brew info --json=v2",
        "evidence": "brew info --json=v2 --installed",
        "confidence": "observed",
        "notes": "Receipt time and original installer identity are not inferred",
    }


def index_rows(report):
    return {row.get("record_id", record_id(row)): row for row in report.get("rows", [])}


def substantive(row):
    return {key: value for key, value in row.items() if key not in {"observed_at", "record_id"}}


def changed_row(key, old, new):
    if substantive(old) == substantive(new):
        return None
    return {"id": key, "before": old, "after": new}


def changed_rows(old, new):
    changes = (changed_row(key, old[key], new[key]) for key in old.keys() & new.keys())
    return list(filter(None, changes))


def missing_rows(old, new):
    return [old[key] for key in sorted(old.keys() - new.keys())]


def removal_status(rows, incomplete):
    if incomplete:
        return {"removed": [], "unconfirmed_removals": rows}
    return {"removed": rows, "unconfirmed_removals": []}


def diff_reports(old, new):
    old_rows, new_rows = index_rows(old), index_rows(new)
    incomplete = _incomplete(old) or _incomplete(new)
    return {
        "added": missing_rows(new_rows, old_rows),
        "changed": changed_rows(old_rows, new_rows),
        "incomplete": incomplete,
        **removal_status(missing_rows(old_rows, new_rows), incomplete),
    }


def _incomplete(report):
    return report.get("coverage_complete") is not True


def collect_inventory(project, git_root, output):
    report = enrich(collect(Path(project), Path(git_root)), classify_git_live)
    collect_nix_profile(report)
    export(report, Path(output))
    return report


def collect_nix_profile(report):
    nix = shutil.which("nix")
    if nix:
        args = [nix, "profile", "list", "--json"]
        record_nix_result(report, args, run_command(args, timeout=60))


def record_nix_result(report, args, result):
    if result["code"] != 0:
        report["probes"].append({"command": args, "status": "failed", "exit_code": result["code"]})
        return
    report["probes"].append({"command": args, "status": extend_nix_rows(report, result["stdout"])})


def extend_nix_rows(report, stdout):
    try:
        parsed = parse_nix_profile(json.loads(stdout))
        stamp_nix_rows(report, parsed)
        report["rows"].extend(parsed)
        return "ok"
    except ValueError:
        return "unsupported_schema"


def stamp_nix_rows(report, rows):
    for row in rows:
        enrich_row(row)
        row["observed_at"] = report.get("observed_at", "")


def classify_git_live(path):
    try:
        return classify_git(path, run_command)
    except (OSError, ValueError):
        return "unknown"
