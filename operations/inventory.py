#!/usr/bin/env python3
"""Collect private inventory snapshots and export CSV, Markdown and JSON."""

import argparse
import csv
import json
import os
from pathlib import Path

from mac_env.inventory_collectors import collect as collect
from mac_env.inventory_collectors import command as command

FIELDS = [
    "kind",
    "name",
    "version",
    "install_method",
    "path",
    "provenance",
    "evidence",
    "confidence",
    "observed_at",
    "notes",
    "record_id",
]


def csv_cell(value):
    text = str(value)
    return "'" + text if text.startswith(("=", "+", "-", "@", "\t", "\r")) else value


def csv_row(row):
    return {field: csv_cell(row.get(field, "")) for field in FIELDS}


def export_csv(report, destination):
    with destination.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(map(csv_row, report["rows"]))


def markdown_cell(value):
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("|", "&#124;")
        .replace("\n", " ")
        .replace("\r", " ")
    )


def markdown_row(values):
    return "| " + " | ".join(map(markdown_cell, values)) + " |"


def inventory_row(row):
    return markdown_row(row.get(field, "") for field in FIELDS)


def probe_row(probe):
    command = probe.get("command", [probe.get("path", "")])
    return markdown_row([" ".join(command), probe["status"]])


def export_markdown(report, destination):
    lines = [
        "# Installed environment inventory",
        "",
        report["coverage"],
        "",
        markdown_row(FIELDS),
        markdown_row(["---"] * len(FIELDS)),
    ]
    lines.extend(map(inventory_row, report["rows"]))
    lines.extend(["", "## Collection status", "", "| Probe | Status |", "| --- | --- |"])
    lines.extend(map(probe_row, report["probes"]))
    destination.write_text("\n".join(lines) + "\n")


def export(report, destination):
    destination.mkdir(parents=True, exist_ok=False, mode=0o700)
    (destination / "inventory.json").write_text(json.dumps(report, indent=2) + "\n")
    export_csv(report, destination / "inventory.csv")
    export_markdown(report, destination / "inventory.md")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New private snapshot directory")
    parser.add_argument("--git-root", type=Path, default=Path.home() / "Git")
    args = parser.parse_args()
    os.umask(0o077)
    result = collect(Path(__file__).resolve().parent.parent, args.git_root)
    export(result, args.output)
    print(
        json.dumps(
            {
                "snapshot": str(args.output),
                "rows": len(result["rows"]),
                "failed_probes": sum(p["status"] != "ok" for p in result["probes"]),
            }
        )
    )


if __name__ == "__main__":
    main()
