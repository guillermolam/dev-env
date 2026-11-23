import csv
import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest.mock import patch

from inventory import export
from mac_env.backup import (
    BackupError,
    create_backup,
    parse_snapshot_id,
    restore_files,
)
from mac_env.config import validate_document
from mac_env.housekeeping import quarantine, scan, undo
from mac_env.inventory_ext import classify_git, diff_reports, parse_brew_receipts, parse_nix_profile
from mac_env.opa_eval import evaluate_input, restrict_capabilities
from mac_env.runtime import LockError, OperationLock
from mac_env.security import parse_vulnix
from mac_env.tools_policy import list_tools, remove_tool, set_tool
from mac_env.updates import apply_plan, fingerprint, plan_channel
from mac_env.workflows import approve_baseline, provision_apply

NOW = "2026-11-19T03:30:00+00:00"
ENTRY = {"status": "ok", "observed_at": NOW, "findings": [], "critical": 0}


def collectors(**updates):
    document = {
        name: dict(ENTRY) for name in ("access", "firewall", "integrity", "tooling", "vulnix")
    }
    document.update(updates)
    return document


def layers(tools=None, updates=None):
    return {
        "defaults": {
            "schema_version": 1,
            "updates": {
                "default_tool_mode": "manual",
                "allow_reboot": False,
                "allow_major": False,
                "allow_removals": False,
                "require_rollback": True,
                "require_ac_power": True,
                "max_evidence_age_seconds": 86400,
                "max_backup_age_seconds": 86400,
                "min_free_bytes": 10,
                "maintenance_start": "03:00",
                "maintenance_end": "05:00",
                **(updates or {}),
            },
            "tools": {},
        },
        "tool": {"tools": tools or {}},
    }


def update_input(**overrides):
    candidate = {
        "channel": "homebrew",
        "fingerprint": "abc",
        "requires_reboot": False,
        "tools": [{"id": "brew:formula:git", "change": "upgrade", "version": "2", "major": False}],
        "dependencies": [],
        "removals": [],
        "runtime_closure_changed": [],
        "adapter": {
            "can_scan_candidate": True,
            "can_rollback": True,
            "can_unattended": True,
            "can_constrain_dependencies": True,
            "estimated_bytes": 1,
        },
    }
    payload = {
        "operation": "update",
        "now": NOW,
        "initiated": "scheduled",
        "evidence": collectors(),
        "baseline": collectors(),
        "candidate_security": {"vulnix": dict(ENTRY)},
        "candidate_supplies_policy": False,
        "policy_fingerprint_matches": True,
        "saved_plan_fingerprint": "",
        "host": {
            "ac_power": True,
            "free_bytes": 100,
            "local_time": "03:30",
            "last_verified_backup_at": NOW,
        },
        "policy_layers": layers({"brew:formula:git": {"mode": "auto"}}),
        "candidate": candidate,
    }
    payload.update(overrides)
    return payload


class PolicyTests(unittest.TestCase):
    def test_unlisted_tool_is_manual(self):
        decision = evaluate_input(update_input(policy_layers=layers()))
        self.assertEqual(decision["outcome"], "defer")
        self.assertTrue(any("manual" in reason for reason in decision["reasons"]))

    def test_expired_exception_does_not_suppress(self):
        payload = update_input()
        payload["evidence"] = collectors(vulnix={**ENTRY, "findings": ["CVE-new"]})
        payload["baseline"] = collectors(vulnix={**ENTRY, "findings": []})
        payload["policy_layers"]["tool"]["exceptions"] = [
            {
                "id": "EX-1",
                "scope": "finding:CVE-new",
                "reason": "temporary",
                "approver": "owner",
                "expires_at": "2020-01-01T00:00:00+00:00",
            }
        ]
        self.assertEqual(evaluate_input(payload)["outcome"], "block")

    def test_nix_hold_without_constraint_blocks(self):
        payload = update_input()
        payload["candidate"]["channel"] = "nix"
        payload["candidate"]["adapter"]["can_constrain_dependencies"] = False
        payload["candidate"]["dependencies"] = None
        payload["candidate"]["runtime_closure_changed"] = None
        payload["policy_layers"] = layers(
            {"nix:profile:system:opentofu": {"mode": "hold", "reason": "stable"}}
        )
        payload["candidate"]["tools"] = [
            {"id": "nix:profile:system:nil", "change": "upgrade", "version": "1", "major": False}
        ]
        decision = evaluate_input(payload)
        self.assertEqual(decision["outcome"], "block")
        self.assertTrue(any("nix hold" in reason for reason in decision["reasons"]))

    def test_malformed_opa_output_blocks(self):
        with tempfile.TemporaryDirectory() as raw:
            binary = Path(raw) / "opa"
            binary.write_text(
                textwrap.dedent("""\
                #!/usr/bin/env python3
                import sys
                if sys.argv[1] == "capabilities":
                    print('{"builtins":[{"name":"time.parse_rfc3339_ns"}]}')
                else:
                    print("{}")
            """)
            )
            binary.chmod(0o755)
            with patch.dict(os.environ, {"MAC_ENV_OPA": str(binary)}):
                decision = evaluate_input(update_input())
        self.assertFalse(decision["eligible"])
        self.assertIn("MACENV-OPA-MALFORMED", decision["rule_ids"])


class UpdateTests(unittest.TestCase):
    def test_changed_candidate_is_not_applied(self):
        plan = {
            "candidate": {"tools": [{"id": "brew:formula:git"}]},
            "candidate_fingerprint": "stale",
            "evidence_fingerprint": "same",
            "current_evidence_fingerprint": "same",
        }
        self.assertFalse(apply_plan(plan)["applied"])

    def test_production_apply_stays_disabled(self):
        candidate = {"tools": [{"id": "brew:formula:git"}]}
        plan = {
            "candidate": candidate,
            "candidate_fingerprint": fingerprint(candidate),
            "evidence_fingerprint": "same",
            "current_evidence_fingerprint": "same",
            "input": update_input(),
        }
        self.assertEqual(apply_plan(plan)["reason"], "production apply is disabled")

    def test_channel_plan_reports_missing_capability(self):
        result = plan_channel(
            "nix",
            [],
            collectors(),
            collectors(),
            layers(),
            {
                "now": NOW,
                "ac_power": True,
                "free_bytes": 100,
                "local_time": "03:30",
                "last_verified_backup_at": NOW,
            },
        )
        self.assertNotEqual(result["decision"]["outcome"], "allow")


class BackupTests(unittest.TestCase):
    def test_partial_backup_does_not_publish_manifest(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            password = write_password(root)
            manifest = root / "manifest.json"
            manifest.write_text("previous\n")
            with self.assertRaises(BackupError):
                create_backup(
                    {"eligible": True, "reasons": [], "rule_ids": []},
                    ["."],
                    manifest,
                    backup_config(root, password),
                    lambda *_args, **_kwargs: {"code": 3, "stdout": "", "stderr": ""},
                )
            self.assertEqual(manifest.read_text(), "previous\n")

    def test_successful_backup_replaces_manifest_atomically(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            password = write_password(root)
            manifest = root / "manifest.json"
            create_backup(
                {"eligible": True, "reasons": [], "rule_ids": ["MACENV-OK"]},
                ["."],
                manifest,
                backup_config(root, password),
                fake_restic,
            )
            self.assertEqual(json.loads(manifest.read_text())["snapshot_id"], "abc123")

    def test_restore_refuses_nonempty_destination(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            password = write_password(root)
            (root / "existing").write_text("keep")
            with self.assertRaises(BackupError):
                restore_files("abc123", root, backup_config(root, password))

    def test_password_file_rejects_group_readable(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            password = write_password(root)
            password.chmod(0o640)
            with self.assertRaises(BackupError):
                create_backup(
                    {"eligible": True, "reasons": [], "rule_ids": []},
                    ["."],
                    root / "manifest.json",
                    backup_config(root, password),
                    fake_restic,
                )

    def test_snapshot_parser_ignores_non_json(self):
        self.assertEqual(parse_snapshot_id('noise\n{"snapshot_id":"abc123"}\n'), "abc123")
        self.assertIsNone(parse_snapshot_id("saved snapshot"))


def write_password(root):
    password = Path(root) / "password"
    password.write_text("test-password\n")
    password.chmod(0o600)
    return password


def backup_config(root, password):
    return {
        "repository": str(Path(root) / "repo"),
        "password_file": str(password),
        "restic": "restic",
    }


def fake_restic(args, timeout=1, env=None):
    if "backup" in args:
        return {"code": 0, "stdout": '{"snapshot_id":"abc123"}\n', "stderr": ""}
    return {"code": 0, "stdout": "abc123", "stderr": ""}


class HousekeepingTests(unittest.TestCase):
    def test_secret_is_redacted_and_quarantine_is_reversible(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "root"
            root.mkdir()
            secret = root / "note.txt"
            secret.write_text("password = hunter2\n")
            report = scan(root, Path(raw) / "report")
            self.assertNotIn("hunter2", Path(raw, "report", "housekeeping.json").read_text())
            plan = {
                "root": str(root),
                "matches": [
                    item for item in report["matches"] if item["path"].endswith("note.txt")
                ],
            }
            plan_path = Path(raw) / "plan.json"
            plan_path.write_text(json.dumps(plan))
            quarantine(plan_path, Path(raw) / "quarantine")
            self.assertFalse(secret.exists())
            undo(Path(raw) / "quarantine" / "undo.json")
            self.assertEqual(secret.read_text(), "password = hunter2\n")

    def test_symlink_quarantine_is_refused(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "root"
            root.mkdir()
            link = root / "link"
            link.symlink_to(root)
            plan = {"root": str(root), "matches": [{"id": "x", "path": str(link)}]}
            plan_path = Path(raw) / "plan.json"
            plan_path.write_text(json.dumps(plan))
            with self.assertRaises(ValueError):
                quarantine(plan_path, Path(raw) / "quarantine")


class InventoryTests(unittest.TestCase):
    def test_incomplete_collection_does_not_confirm_removal(self):
        old = {"rows": [{"record_id": "package:git:/opt/git", "name": "git"}]}
        new = {"rows": []}
        result = diff_reports(old, new)
        self.assertEqual(result["removed"], [])
        self.assertTrue(result["unconfirmed_removals"])

    def test_complete_collection_reports_removal(self):
        old = {"coverage_complete": True, "rows": [{"record_id": "package:git:", "name": "git"}]}
        new = {"coverage_complete": True, "rows": []}
        self.assertEqual(len(diff_reports(old, new)["removed"]), 1)

    def test_nix_and_brew_parsers_reject_unknown_schema(self):
        with self.assertRaises(ValueError):
            parse_nix_profile([])
        self.assertEqual(
            parse_nix_profile(
                {"elements": [{"attrPath": "nixpkgs#nil", "storePaths": ["/nix/store/example"]}]}
            )[0]["name"],
            "nixpkgs#nil",
        )
        with self.assertRaises(ValueError):
            parse_brew_receipts({"formulae": "bad"})

    def test_empty_git_repository_is_valid(self):
        with tempfile.TemporaryDirectory() as raw:
            subprocess.run(["git", "init"], cwd=raw, check=True, capture_output=True)
            from mac_env.runtime import run_command

            self.assertEqual(classify_git(raw, run_command), "empty_repository")

    def test_csv_formula_injection_is_neutralized(self):
        with tempfile.TemporaryDirectory() as raw:
            destination = Path(raw) / "snapshot"
            export(
                {
                    "rows": [
                        {
                            "kind": "package",
                            "name": "=cmd",
                            "version": "",
                            "install_method": "",
                            "path": "",
                            "provenance": "",
                            "evidence": "",
                            "confidence": "",
                            "observed_at": "",
                            "notes": "",
                        }
                    ],
                    "probes": [],
                    "coverage": "test",
                },
                destination,
            )
            with (destination / "inventory.csv").open() as handle:
                self.assertTrue(next(csv.DictReader(handle))["name"].startswith("'"))


class ConfigAndWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.environ = patch.dict(os.environ, {"MAC_ENV_STATE_DIR": self.temporary.name})
        self.environ.start()

    def tearDown(self):
        self.environ.stop()
        self.temporary.cleanup()

    def test_unknown_policy_key_and_permanent_exception_are_rejected(self):
        self.assertTrue(validate_document({"schema_version": 1, "command": "rm"}))
        self.assertTrue(
            validate_document(
                {
                    "schema_version": 1,
                    "exceptions": [
                        {
                            "id": "x",
                            "scope": "finding:CVE",
                            "reason": "because",
                            "approver": "owner",
                            "expires_at": "2026-11-19",
                        }
                    ],
                }
            )
        )

    def test_tool_policy_round_trip(self):
        set_tool("brew:formula:vault", "hold", "keep stable", "2.2.2")
        self.assertEqual(list_tools()["brew:formula:vault"]["pin"], "2.2.2")
        remove_tool("brew:formula:vault")
        self.assertNotIn("brew:formula:vault", list_tools())

    def test_unhealthy_baseline_cannot_be_approved(self):
        with self.assertRaises(RuntimeError):
            approve_baseline(
                {"vulnix": {**ENTRY, "status": "error"}},
                Path(self.temporary.name) / "baseline.json",
                "owner",
                True,
            )

    def test_provision_apply_does_not_overwrite(self):
        target = Path(self.temporary.name) / "home"
        (target / "Documents").mkdir(parents=True)
        (target / "Documents" / "keep").write_text("safe")
        result = provision_apply({"folders": ["Documents", "Git"]}, target)
        self.assertIn(str(target / "Documents"), result["skipped"])
        self.assertEqual((target / "Documents" / "keep").read_text(), "safe")
        self.assertEqual(result["deleted"], [])

    def test_lock_excludes_second_operation(self):
        with OperationLock(Path(self.temporary.name) / "lock"):
            with self.assertRaises(LockError):
                with OperationLock(Path(self.temporary.name) / "lock"):
                    pass


class SecurityParserTests(unittest.TestCase):
    def test_vulnix_schema(self):
        findings, critical, database_time = parse_vulnix(
            [{"affected_by": [{"id": "CVE-2024-1", "cvss": 9.8}, "CVE-2024-2"]}]
        )
        self.assertEqual(findings, ["CVE-2024-1", "CVE-2024-2"])
        self.assertEqual(critical, 1)
        self.assertIsNone(database_time)
        with self.assertRaises(ValueError):
            parse_vulnix({"unexpected": True})


class CapabilityTests(unittest.TestCase):
    def test_network_builtins_are_removed(self):
        result = restrict_capabilities(
            {
                "builtins": [
                    {"name": "http.send"},
                    {"name": "net.lookup_ip_addr"},
                    {"name": "time.now_ns"},
                    {"name": "time.parse_rfc3339_ns"},
                ]
            }
        )
        names = [item["name"] for item in result["builtins"]]
        self.assertEqual(names, ["time.parse_rfc3339_ns"])


if __name__ == "__main__":
    unittest.main()
