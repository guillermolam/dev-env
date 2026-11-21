#!/usr/bin/env python3
"""Evaluate collector evidence. This command never creates or approves backups."""

import argparse
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

from policy import evaluate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("baseline", type=Path)
    args = parser.parse_args()
    try:
        evidence = json.loads(args.evidence.read_text())
        baseline = json.loads(args.baseline.read_text())
        reasons = evaluate(evidence, baseline)
    except (OSError, ValueError, TypeError):
        reasons = ["Cannot read valid evidence and baseline"]
    print(
        json.dumps(
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "event": "backup_eligibility",
                "eligible": not reasons,
                "reasons": reasons,
            }
        )
    )
    return 2 if reasons else 0


if __name__ == "__main__":
    sys.exit(main())
