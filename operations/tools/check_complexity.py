#!/usr/bin/env python3
"""Enforce per-function Radon and cognitive-complexity limits, including tests."""

import ast
import json
from pathlib import Path

from cognitive_complexity.api import get_cognitive_complexity
from radon.complexity import cc_visit_ast

LIMIT = 3
ROOT = Path(__file__).resolve().parents[1]


def source_files():
    return sorted(path for path in ROOT.rglob("*.py") if ".cache" not in path.parts)


def function_nodes(tree):
    return [
        node for node in ast.walk(tree) if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    ]


def measure(path, node):
    block = cc_visit_ast(ast.Module(body=[node], type_ignores=[]))[0]
    return {
        "file": str(path.relative_to(ROOT.parent)),
        "line": node.lineno,
        "function": node.name,
        "cyclomatic": block.complexity,
        "cognitive": get_cognitive_complexity(node),
    }


def file_metrics(path):
    return [measure(path, node) for node in function_nodes(ast.parse(path.read_text()))]


def exceeds_limit(row):
    return max(row["cyclomatic"], row["cognitive"]) > LIMIT


def maximum(rows, field):
    return max((row[field] for row in rows), default=0)


def main():
    rows = []
    for path in source_files():
        rows.extend(file_metrics(path))
    failures = list(filter(exceeds_limit, rows))
    print(
        json.dumps(
            {
                "limit": LIMIT,
                "functions": len(rows),
                "max_cyclomatic": maximum(rows, "cyclomatic"),
                "max_cognitive": maximum(rows, "cognitive"),
                "violations": failures,
            },
            indent=2,
        )
    )
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
