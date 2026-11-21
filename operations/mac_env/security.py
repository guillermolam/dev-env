"""Security collection and parsing; incomplete coverage never becomes success."""

import json
import os
import shutil
from datetime import UTC, datetime
from pathlib import Path

from mac_env.runtime import run_command
from mac_env.validation import nonempty_string, require, require_mapping, string_list

SOURCE_ENV = {
    "firewall": "MAC_ENV_FIREWALL_EVIDENCE",
    "tooling": "MAC_ENV_TOOLING_EVIDENCE",
    "access": "MAC_ENV_ACCESS_EVIDENCE",
    "integrity": "MAC_ENV_INTEGRITY_EVIDENCE",
    "vulnix": "MAC_ENV_VULNIX_EVIDENCE",
}


def unavailable(reason, observed_at):
    return {
        "status": "error",
        "observed_at": observed_at,
        "findings": [],
        "critical": 0,
        "coverage": reason,
    }


def parse_vulnix(document):
    require(isinstance(document, list), "unsupported vulnix schema")
    findings = []
    for entry in document:
        findings.extend(entry_advisories(entry))
    return summarize_findings(findings)


def entry_advisories(entry):
    require(isinstance(entry, dict), "unsupported vulnix entry")
    advisories = entry.get("affected_by", entry.get("cves", []))
    require(isinstance(advisories, list), "unsupported vulnix advisories")
    return list(map(parse_advisory, advisories))


def parse_advisory(advisory):
    if isinstance(advisory, dict):
        identifier = advisory.get("id")
        require(nonempty_string(identifier), "unsupported vulnix advisory")
        return identifier, critical_score(advisory.get("cvss", 0))
    require(nonempty_string(advisory), "unsupported vulnix advisory")
    return advisory, False


def critical_score(score):
    return isinstance(score, (int, float)) and score >= 9


def summarize_findings(findings):
    identifiers = sorted({identifier for identifier, _critical in findings})
    critical = sum(critical for _identifier, critical in findings)
    return identifiers, critical, None


def coverage_gaps(evidence):
    return [record["coverage"] for record in evidence.values() if record["status"] != "ok"]


def collect_security(now=None, runner=run_command):
    observed_at = (now or datetime.now(UTC)).isoformat()
    evidence = {
        "vulnix": collect_vulnix(observed_at, runner),
        "firewall": collect_named("firewall", observed_at, runner),
        "tooling": collect_named("tooling", observed_at, runner),
        "access": collect_named("access", observed_at, runner),
        "integrity": collect_named("integrity", observed_at, runner),
    }
    notes = {
        "sbomnix": "not provisioned; supplemental coverage is unavailable",
        "firewall_probe": probe_firewall(runner),
        "sources": SOURCE_ENV,
    }
    return {"evidence": evidence, "notes": notes, "coverage_gaps": coverage_gaps(evidence)}


def collect_named(name, observed_at, runner=run_command):
    env_name = SOURCE_ENV[name]
    path = os.environ.get(env_name, "").strip()
    if path:
        return load_evidence_file(path, observed_at)
    return live_or_unavailable(name, observed_at, runner)


def live_or_unavailable(name, observed_at, runner):
    from mac_env import host_evidence

    probes = {
        "firewall": host_evidence.live_firewall,
        "tooling": host_evidence.live_tooling,
        "access": host_evidence.live_access,
        "integrity": host_evidence.live_integrity,
    }
    probe = probes.get(name)
    if probe is None:
        return unavailable(f"{name} source is not configured ({SOURCE_ENV[name]})", observed_at)
    return probe(observed_at, runner)


def load_evidence_file(path, observed_at):
    try:
        document = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError, UnicodeError):
        return unavailable("evidence file unreadable or invalid JSON", observed_at)
    try:
        return normalize_evidence_record(document, observed_at)
    except ValueError as error:
        return unavailable(str(error), observed_at)


def normalize_evidence_record(document, observed_at):
    require_mapping(document, "evidence record")
    status = document.get("status")
    require(nonempty_string(status), "evidence record: status required")
    findings = document.get("findings", [])
    require(string_list(findings), "evidence record: findings must be strings")
    critical = document.get("critical", 0)
    require(isinstance(critical, int) and critical >= 0, "evidence record: invalid critical")
    return evidence_record_body(document, status, findings, critical, observed_at)


def evidence_record_body(document, status, findings, critical, observed_at):
    record = {
        "status": status,
        "observed_at": document.get("observed_at") or observed_at,
        "findings": findings,
        "critical": critical,
        "coverage": document.get("coverage", "configured evidence file"),
    }
    database = document.get("database_observed_at")
    if database:
        record["database_observed_at"] = database
    return record


def collect_vulnix(observed_at, runner):
    path = os.environ.get(SOURCE_ENV["vulnix"], "").strip()
    if path:
        return load_evidence_file(path, observed_at)
    return run_vulnix_scan(observed_at, runner)


def run_vulnix_scan(observed_at, runner):
    binary = shutil.which("vulnix")
    if not binary:
        return {**unavailable("vulnix is not installed", observed_at), "database_observed_at": ""}
    argv = vulnix_argv(binary)
    if not argv:
        return {
            **unavailable(
                "vulnix scan target missing (no current-system; set MAC_ENV_VULNIX_ROOT)",
                observed_at,
            ),
            "database_observed_at": "",
        }
    return vulnix_result(runner(argv, timeout=300), observed_at)


def vulnix_argv(binary):
    configured = os.environ.get("MAC_ENV_VULNIX_ROOT", "").strip()
    if configured:
        return [binary, "--json", "--profile", configured]
    return vulnix_default_argv(binary)


def vulnix_default_argv(binary):
    if Path("/nix/var/nix/gcroots/current-system").exists():
        return [binary, "--json", "--system"]
    profile = Path.home() / ".nix-profile"
    if profile.exists():
        return [binary, "--json", "--profile", str(profile)]
    return None


def vulnix_result(result, observed_at):
    try:
        document = json.loads(result["stdout"] or "")
        findings, critical, _database_time = parse_vulnix(document)
    except ValueError:
        return vulnix_parse_failure(result, observed_at)
    return vulnix_with_database(findings, critical, observed_at)


def vulnix_parse_failure(result, observed_at):
    if result["code"] != 0:
        return unavailable("vulnix failed", observed_at)
    return unavailable("vulnix output schema is unsupported", observed_at)


def vulnix_with_database(findings, critical, observed_at):
    database = os.environ.get("MAC_ENV_VULNIX_DB_OBSERVED_AT", "").strip()
    if not database:
        record = unavailable(
            "vulnix advisory database observation time is unavailable", observed_at
        )
        record.update(findings=findings, critical=critical, database_observed_at="")
        return record
    return {
        "status": "ok",
        "observed_at": observed_at,
        "findings": findings,
        "critical": critical,
        "coverage": "vulnix JSON scan with attested database_observed_at",
        "database_observed_at": database,
    }


def probe_firewall(runner):
    binary = "/usr/libexec/ApplicationFirewall/socketfilterfw"
    if not Path(binary).exists():
        return "firewall command unavailable"
    result = runner([binary, "--getglobalstate"], timeout=10)
    if result["code"] != 0:
        return "firewall enablement probe failed"
    return "enablement probe completed; alert coverage remains incomplete"
