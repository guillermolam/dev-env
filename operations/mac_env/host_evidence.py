"""Live host probes for security collectors when file evidence is unset."""

import os
from pathlib import Path

from mac_env.runtime import run_command

FIREWALL = "/usr/libexec/ApplicationFirewall/socketfilterfw"


def probe_error(reason, observed_at):
    return {
        "status": "error",
        "observed_at": observed_at,
        "findings": [],
        "critical": 0,
        "coverage": reason,
    }


def live_firewall(observed_at, runner=run_command):
    if not Path(FIREWALL).exists():
        return probe_error("firewall command unavailable", observed_at)
    state = runner([FIREWALL, "--getglobalstate"], timeout=10)
    if state["code"] != 0:
        return probe_error("firewall enablement probe failed", observed_at)
    return firewall_record(state["stdout"], observed_at, runner)


def firewall_record(stdout, observed_at, runner):
    enabled = "enabled" in stdout.lower() or "state = 1" in stdout.lower()
    if not enabled:
        return probe_error("application firewall is disabled", observed_at)
    findings = stealth_findings(runner)
    return {
        "status": "ok",
        "observed_at": observed_at,
        "findings": findings,
        "critical": 0,
        "coverage": "Application Firewall global enablement via socketfilterfw",
    }


def stealth_findings(runner):
    result = runner([FIREWALL, "--getstealthmode"], timeout=10)
    if result["code"] != 0:
        return ["stealth_mode_probe_failed"]
    if "off" in result["stdout"].lower():
        return ["stealth_mode_off"]
    return []


def live_access(observed_at, runner=run_command):
    result = runner(["fdesetup", "status"], timeout=10)
    if result["code"] != 0:
        return probe_error("FileVault status probe failed", observed_at)
    if "filevault is on" not in result["stdout"].lower():
        return probe_error("FileVault is not enabled", observed_at)
    return {
        "status": "ok",
        "observed_at": observed_at,
        "findings": [],
        "critical": 0,
        "coverage": "FileVault enablement via fdesetup status",
    }


def live_integrity(observed_at, runner=run_command):
    result = runner(["csrutil", "status"], timeout=10)
    if result["code"] != 0:
        return probe_error("SIP status probe failed", observed_at)
    if "enabled" not in result["stdout"].lower():
        return probe_error("System Integrity Protection is not enabled", observed_at)
    return {
        "status": "ok",
        "observed_at": observed_at,
        "findings": [],
        "critical": 0,
        "coverage": "SIP enablement via csrutil status",
    }


def live_tooling(observed_at, runner=run_command):
    gap = tooling_gap(runner)
    if gap:
        return probe_error(gap, observed_at)
    return {
        "status": "ok",
        "observed_at": observed_at,
        "findings": [],
        "critical": 0,
        "coverage": "nix, python3, and restic availability",
    }


def tooling_gap(runner):
    missing = missing_core_tools(runner)
    if missing:
        return "missing tools: " + ", ".join(missing)
    return restic_gap(runner)


def missing_core_tools(runner):
    return [name for name in ("nix", "python3") if not tool_present(name, runner)]


def restic_gap(runner):
    if restic_present(runner):
        return ""
    return "restic is not available (PATH or MAC_ENV_RESTIC)"


def tool_present(name, runner):
    result = runner(["/usr/bin/which", name], timeout=5)
    return result["code"] == 0 and bool(result["stdout"].strip())


def restic_present(runner):
    configured = os.environ.get("MAC_ENV_RESTIC", "").strip()
    if configured and Path(configured).is_file():
        return True
    return tool_present("restic", runner)
