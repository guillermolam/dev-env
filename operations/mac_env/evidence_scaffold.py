"""Write honest per-collector evidence files from live collection (no fake ok)."""

import json
from pathlib import Path

from mac_env.files import atomic_write
from mac_env.security import SOURCE_ENV, collect_security


def scaffold_evidence(output, runner=None):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    report = collect_security() if runner is None else collect_security(runner=runner)
    written = write_collector_files(output, report["evidence"])
    env_path = output / "env.exports"
    atomic_write(env_path, evidence_exports(output) + "\n")
    return {
        "output": str(output),
        "files": written,
        "coverage_gaps": report["coverage_gaps"],
        "env_exports": str(env_path),
        "ready_for_doctor": not report["coverage_gaps"],
    }


def write_collector_files(output, evidence):
    written = []
    for name, record in evidence.items():
        path = output / f"{name}.json"
        atomic_write(path, json.dumps(record, indent=2) + "\n")
        written.append({"collector": name, "path": str(path), "status": record.get("status")})
    return written


def evidence_exports(output):
    lines = ["# Source after review. Does not invent healthy coverage."]
    for name, env_name in SOURCE_ENV.items():
        lines.append(f'export {env_name}="{Path(output) / (name + ".json")}"')
    return "\n".join(lines)
