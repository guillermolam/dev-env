#!/usr/bin/env python3
"""Show the census board on every hook. Continue workload A while left is not 0."""

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOARD = ROOT / ".agents" / "runs" / "census.txt"
BINARY = ROOT / "census" / "target" / "debug" / "mac-env-census"
CONTINUE = (
    "Workload A left is not 0. Continue the first id in workload_a_open. "
    "A step without its predicate stays open. A missing token is a recorded gap. "
    "Do not ask the operator. Do not drop the OpenShell fence."
)
HOLD = (
    "Workload A left is not 0. The first open id already has a recorded gap. "
    "Leave that predicate open. Do not ask the operator. Do not drop the OpenShell fence."
)


def read_forced():
    path = os.environ.get("CENSUS_BOARD_FILE")
    if path:
        return Path(path).read_text()
    return ""


def run_binary():
    if not BINARY.is_file():
        return
    try:
        subprocess.run(
            [str(BINARY), "--repo", str(ROOT), "--board", str(BOARD)],
            check=False,
            timeout=8,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return


def board_text():
    forced = read_forced()
    if forced:
        return forced
    run_binary()
    if BOARD.is_file():
        return BOARD.read_text()
    return "census\nbinary_missing=1\n"


def workload_left(text):
    for line in text.splitlines():
        if line.startswith("workload_a current="):
            return line.rsplit("left=", 1)[-1].strip()
    return ""


def open_ids(text):
    for line in text.splitlines():
        if line.startswith("workload_a_open="):
            return line.split("=", 1)[1].strip()
    return ""


def first_open(text):
    ids = open_ids(text)
    if not ids or ids == "none":
        return ""
    return ids.split(",", 1)[0]


def receipts_dir():
    override = os.environ.get("CENSUS_RECEIPTS")
    if override:
        return Path(override)
    return ROOT / "receipts"


def gap_held(text):
    step = first_open(text).lower()
    if not step:
        return False
    folder = receipts_dir()
    if not folder.is_dir():
        return False
    return any(item.is_file() for item in folder.glob(step + "-blocked*"))


def should_continue(kind, text):
    if kind != "stop":
        return False
    if workload_left(text) in ("", "0"):
        return False
    return not gap_held(text)


def held_stop(kind, text):
    if kind != "stop":
        return False
    return workload_left(text) not in ("", "0")


def emit(kind, text):
    if should_continue(kind, text):
        return {"followup_message": text + CONTINUE}
    if held_stop(kind, text):
        return {"additional_context": text + HOLD}
    return {"additional_context": text}


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "postToolUse"
    sys.stdin.read()
    text = board_text()
    json.dump(emit(kind, text), sys.stdout)
    sys.stdout.write("\n")
    sys.stderr.write(text if text.endswith("\n") else text + "\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        sys.stdout.write("{}\n")
        raise SystemExit(0)
