"""Next provision step from the pinned plan. No side effects."""

import json
from pathlib import Path

from mac_env.validation import require

PLAN_PATH = Path(__file__).resolve().parents[2] / "homelab" / "provision-plan.json"
REQUIRES = {
    "nix_built": ("nix_built",),
    "runtime_up": ("nix_built", "runtime_up"),
    "cluster_ready": ("nix_built", "homelab_enabled", "digests_pinned", "cluster_ready"),
    "linux_node": ("nix_built", "linux_node"),
    "cloud_account": ("cloud_account",),
}


def load_plan(path=PLAN_PATH):
    rows = json.loads(Path(path).read_text())
    require(isinstance(rows, list) and bool(rows), "plan")
    return rows


def gap_for(when, facts):
    for name in REQUIRES[when]:
        if not facts.get(name):
            return name
    return ""


def technology(row, gap):
    if gap == "nix_built" or not row.get("then"):
        return "nix"
    return row["then"]


def pack(row, gap):
    return {
        "id": row["id"],
        "technology": technology(row, gap),
        "allowed": gap == "",
        "gap": gap,
    }


def next_action(row, facts):
    require(row.get("when") in REQUIRES, "when")
    return pack(row, gap_for(row["when"], facts))
