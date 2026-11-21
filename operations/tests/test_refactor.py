"""Regression checks for the responsibilities split during the complexity refactor."""

import ast
import csv
import json
import os
import tempfile
import tomllib
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch

from inventory import FIELDS, export
from mac_env.agent_inventory import inventory_agents
from mac_env.backup import BackupError, ResticClient
from mac_env.config import validate_document
from mac_env.evidence_scaffold import scaffold_evidence
from mac_env.files import atomic_write
from mac_env.housekeeping import quarantine, scan, undo
from mac_env.inventory_collectors import Snapshot, collect_launch_definitions
from mac_env.inventory_ext import diff_reports, enrich
from mac_env.local_backup import bootstrap_local_backup
from mac_env.offsite_backup import backup_status, bootstrap_offsite_backup
from mac_env.opa_eval import DecisionError, evaluate_available, validate_decision
from mac_env.recovery_drill import run_recovery_drill
from mac_env.runtime import INSTALLED_STATE_DIR, redact, resolve_state_dir, state_dir
from mac_env.security import SOURCE_ENV, collect_security
from mac_env.tools_policy import _render, load_tools, set_tool
from mac_env.workflows import approve_baseline, doctor
from policy import evaluate
from test_controller import NOW, collectors
from tools.check_complexity import ROOT, exceeds_limit, file_metrics, function_nodes, measure


class ValidationRegressionTests(unittest.TestCase):
    def test_invalid_types_are_reported_without_crashing(self):
        for value in ([], {}, 1, True, None, "autoo"):
            with self.subTest(value=value):
                errors = validate_document(
                    {"schema_version": 1, "tools": {"brew:formula:git": {"mode": value}}}
                )
                self.assertTrue(errors)

    def test_unknown_scope_fields_are_rejected(self):
        document = {"schema_version": 1, "hosts": {"mac": {"updates": {}, "ignore_failures": True}}}
        self.assertTrue(validate_document(document))

    def test_valid_configuration_round_trip(self):
        document = {
            "schema_version": 1,
            "updates": {"max_backup_age_seconds": 60},
            "hosts": {"mac": {"updates": {"allow_major": True}}},
            "exceptions": [
                {
                    "id": "test",
                    "scope": "finding:CVE-test",
                    "reason": "fixture",
                    "approver": "test",
                    "expires_at": "2030-01-01T00:00:00Z",
                }
            ],
        }
        self.assertEqual(validate_document(document), [])
        self.assertEqual(tomllib.loads(_render(document)), document)

    def test_invalid_policy_blocks_before_opa_execution(self):
        payload = {"policy_layers": {"tool": {"tools": {"brew:formula:git": {"mode": "autoo"}}}}}
        with patch("mac_env.opa_eval.subprocess.run") as run:
            self.assertEqual(evaluate_available(Path("/unused"), payload, 1)["outcome"], "block")
            run.assert_not_called()

    def test_decision_must_agree_with_eligibility(self):
        with self.assertRaises(DecisionError):
            validate_decision(
                {
                    "outcome": "block",
                    "eligible": True,
                    "reasons": ["blocked"],
                    "rule_ids": [],
                    "affected_tools": [],
                }
            )

    def test_nested_redaction_preserves_types(self):
        document = {"items": ["password=private", 2, {"value": "Bearer abcdefgh"}]}
        self.assertEqual(redact(document), {"items": ["[redacted]", 2, {"value": "[redacted]"}]})


class FilesystemRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def plan(self, entries):
        path = self.root / "plan.json"
        path.write_text(json.dumps({"root": str(self.root), "matches": entries}))
        return path

    def test_quarantine_validates_every_entry_before_moving(self):
        first = self.root / "first"
        first.write_text("fixture")
        link = self.root / "link"
        link.symlink_to(first)
        plan = self.plan([{"id": "first", "path": str(first)}, {"id": "link", "path": str(link)}])
        with self.assertRaises(ValueError):
            quarantine(plan, self.root / "quarantine")
        self.assertTrue(first.exists())

    def test_quarantine_interruption_remains_reversible(self):
        first = self.root / "first"
        first.write_text("fixture")
        plan = self.plan([{"id": "first", "path": str(first)}])
        with patch("mac_env.housekeeping.shutil.move", side_effect=OSError("interrupted")):
            with self.assertRaises(OSError):
                quarantine(plan, self.root / "quarantine")
        undo(self.root / "quarantine/undo.json")
        self.assertEqual(first.read_text(), "fixture")

    def test_scan_reports_directory_symlink(self):
        source = self.root / "source"
        source.mkdir()
        (source / "link").symlink_to(self.root)
        report = scan(source, self.root / "report")
        self.assertEqual(report["matches"][0]["reason"], "symlink skipped")

    def test_quarantine_rejects_destination_traversal(self):
        first = self.root / "first"
        first.write_text("fixture")
        with self.assertRaises(ValueError):
            quarantine(
                self.plan([{"id": "../escape", "path": str(first)}]), self.root / "quarantine"
            )
        self.assertTrue(first.exists())

    def test_atomic_write_preserves_previous_file_on_replace_failure(self):
        target = self.root / "state.json"
        target.write_text("previous")
        with patch("mac_env.files.os.replace", side_effect=OSError("failed")):
            with self.assertRaises(OSError):
                atomic_write(target, "new")
        self.assertEqual(target.read_text(), "previous")
        self.assertEqual(list(self.root.iterdir()), [target])

    def test_tool_edit_preserves_other_policy_sections(self):
        with patch.dict(os.environ, {"MAC_ENV_STATE_DIR": str(self.root)}):
            path = self.root / "policy/tools.toml"
            path.parent.mkdir()
            path.write_text("schema_version = 1\n[updates]\nmax_backup_age_seconds = 60\n")
            set_tool("brew:formula:git", "auto")
            self.assertEqual(load_tools()["updates"]["max_backup_age_seconds"], 60)

    def test_approved_baseline_is_consumable(self):
        document = approve_baseline(collectors(), self.root / "baseline.json", "test", True)
        self.assertEqual(evaluate(collectors(), document, datetime.fromisoformat(NOW)), [])

    def test_empty_baseline_is_rejected(self):
        with self.assertRaises(RuntimeError):
            approve_baseline({}, self.root / "baseline.json", "test", True)

    def test_enriched_inventory_exports_all_formats(self):
        row = dict.fromkeys(FIELDS, "")
        row.update(kind="package", name="git", version="1")
        report = enrich({"rows": [row], "probes": [], "coverage": "fixture"})
        output = self.root / "inventory"
        export(report, output)
        with (output / "inventory.csv").open() as handle:
            self.assertEqual(next(csv.DictReader(handle))["record_id"], "package:git:")
        self.assertTrue((output / "inventory.md").is_file())

    def test_launch_definition_name_keeps_extension(self):
        with patch("pathlib.Path.glob", return_value=[Path("test.plist")]):
            snapshot = Snapshot()
            collect_launch_definitions(snapshot)
        self.assertEqual(snapshot.rows[0]["name"], "test.plist")


class BoundaryRegressionTests(unittest.TestCase):
    def test_observation_time_is_not_inventory_drift(self):
        row = {"record_id": "package:git:", "name": "git", "observed_at": "old"}
        result = diff_reports({"rows": [row]}, {"rows": [{**row, "observed_at": "new"}]})
        self.assertEqual(result["changed"], [])

    def test_version_change_is_inventory_drift(self):
        row = {"record_id": "package:git:", "name": "git", "version": "1"}
        result = diff_reports({"rows": [row]}, {"rows": [{**row, "version": "2"}]})
        self.assertEqual(len(result["changed"]), 1)

    def test_backup_arguments_keep_options_before_path_separator(self):
        with tempfile.TemporaryDirectory() as raw:
            password = Path(raw) / "password"
            password.write_text("secret\n")
            password.chmod(0o600)
            runner = Mock(return_value={"code": 0, "stdout": '{"snapshot_id":"abc"}'})
            client = ResticClient(
                {"restic": "restic", "repository": "repo", "password_file": str(password)},
                runner,
            )
            self.assertEqual(client.backup(["--untrusted-name"]), "abc")
            self.assertEqual(
                runner.call_args.args[0],
                [
                    "restic",
                    "--repo",
                    "repo",
                    "--password-file",
                    str(password),
                    "backup",
                    "--json",
                    "--",
                    "--untrusted-name",
                ],
            )


class ComplexityGateTests(unittest.TestCase):
    def test_high_complexity_is_detected(self):
        source = "def example(a, b, c):\n    if a:\n        if b:\n            if c:\n                return 1\n"
        node = ast.parse(source).body[0]
        row = measure(ROOT / "fixture.py", node)
        self.assertTrue(exceeds_limit(row))
        self.assertEqual(row["cyclomatic"], 4)

    def test_nested_and_async_functions_are_measured(self):
        source = "async def outer():\n    def inner():\n        return 1\n    return inner()\n"
        self.assertEqual(
            [node.name for node in function_nodes(ast.parse(source))], ["outer", "inner"]
        )

    def test_check_includes_the_checker_itself(self):
        rows = file_metrics(ROOT / "tools/check_complexity.py")
        self.assertTrue(rows)
        self.assertFalse(any(map(exceeds_limit, rows)))


class StateDirRegressionTests(unittest.TestCase):
    def test_doctor_does_not_create_missing_state_dir(self):
        with tempfile.TemporaryDirectory() as raw:
            missing = Path(raw) / "absent"
            env = {"MAC_ENV_STATE_DIR": str(missing)}
            with patch.dict(os.environ, env, clear=False):
                report = doctor()
            self.assertFalse(missing.exists())
            self.assertEqual(report["state_dir"], str(missing))
            self.assertFalse(report["state_dir_exists"])

    def test_installed_state_flag_selects_system_path(self):
        env = {"MAC_ENV_USE_INSTALLED_STATE": "1", "MAC_ENV_STATE_DIR": ""}
        with patch.dict(os.environ, env, clear=False):
            self.assertEqual(resolve_state_dir(), INSTALLED_STATE_DIR)

    def test_state_dir_override_wins_and_creates(self):
        with tempfile.TemporaryDirectory() as raw:
            target = Path(raw) / "created"
            with patch.dict(os.environ, {"MAC_ENV_STATE_DIR": str(target)}):
                path = state_dir()
            self.assertEqual(path, target)
            self.assertTrue(target.is_dir())


class CoverageAndDrillTests(unittest.TestCase):
    def test_configured_evidence_files_clear_named_gaps(self):
        with tempfile.TemporaryDirectory() as raw:
            env = evidence_env(Path(raw))
            with patch.dict(os.environ, env, clear=False):
                with patch("mac_env.security.shutil.which", return_value=None):
                    report = collect_security(now=datetime.fromisoformat(NOW))
            self.assertEqual(report["coverage_gaps"], [])

    def test_doctor_ready_with_fixture_inputs(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            env = readiness_env(root)
            approve_baseline(collectors(), root / "state" / "baseline.json", "fixture", True)
            with patch.dict(os.environ, env, clear=False):
                with patch("mac_env.security.shutil.which", return_value=None):
                    report = doctor()
            self.assertEqual(report["blockers"], [])
            self.assertTrue(report["ready"])

    def test_recovery_drill_with_fake_restic(self):
        with tempfile.TemporaryDirectory() as raw:
            workspace = Path(raw) / "drill"
            result = run_recovery_drill(workspace, restic="restic", runner=drill_fake_restic)
            self.assertTrue(result["ok"])
            self.assertEqual(result["snapshot_id"], "drill1")
            self.assertTrue(Path(result["restored"]).is_file())

    def test_agent_inventory_hashes_config_without_values(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "home"
            cursor = root / ".cursor"
            cursor.mkdir(parents=True)
            secret = cursor / "settings.json"
            secret.write_text('{"token":"do-not-export"}\n')
            output = Path(raw) / "out"
            report = inventory_agents(root, output)
            text = (output / "agents.json").read_text()
            self.assertNotIn("do-not-export", text)
            self.assertTrue(any(row["kind"] == "agent_config" for row in report["rows"]))
            self.assertTrue((output / "agents.csv").is_file())

    def test_bootstrap_local_requires_confirm(self):
        with self.assertRaises(BackupError):
            bootstrap_local_backup(["/tmp"], confirm=False, runner=drill_fake_restic)

    def test_bootstrap_local_with_fake_restic(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            source = root / "data"
            source.mkdir()
            (source / "file.txt").write_text("keep\n")
            with patch.dict(os.environ, {"MAC_ENV_STATE_DIR": str(root / "state")}):
                result = bootstrap_local_backup(
                    [str(source)], confirm=True, restic="restic", runner=drill_fake_restic
                )
            self.assertTrue(result["ok"])
            self.assertTrue(result["bootstrap"])
            self.assertTrue(Path(result["env_snippet"]).is_file())

    def test_scaffold_evidence_is_honest(self):
        cleared = {key: "" for key in SOURCE_ENV.values()}
        with tempfile.TemporaryDirectory() as raw:
            output = Path(raw) / "evidence"
            with patch.dict(os.environ, cleared, clear=False):
                with patch("mac_env.security.shutil.which", return_value=None):
                    with patch("mac_env.host_evidence.live_firewall", return_value=gap_record()):
                        with patch("mac_env.host_evidence.live_tooling", return_value=gap_record()):
                            with patch(
                                "mac_env.host_evidence.live_access", return_value=gap_record()
                            ):
                                with patch(
                                    "mac_env.host_evidence.live_integrity",
                                    return_value=gap_record(),
                                ):
                                    report = scaffold_evidence(output)
            self.assertFalse(report["ready_for_doctor"])
            self.assertTrue(report["coverage_gaps"])
            self.assertTrue((output / "vulnix.json").is_file())

    def test_local_only_restic_blocks_doctor(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            env = readiness_env(root)
            env["MAC_ENV_RESTIC_REPOSITORY"] = str(root / "state" / "local-restic" / "repo")
            approve_baseline(collectors(), root / "state" / "baseline.json", "fixture", True)
            with patch.dict(os.environ, env, clear=False):
                with patch("mac_env.security.shutil.which", return_value=None):
                    report = doctor()
            self.assertFalse(report["ready"])
            self.assertTrue(any("local-only" in item for item in report["blockers"]))
            self.assertIn("offsite-preflight", report.get("next", ""))
            self.assertIn("R2", report.get("next", ""))

    def test_unset_backup_destination_hints_offsite(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            env = readiness_env(root)
            env["MAC_ENV_RESTIC_REPOSITORY"] = ""
            approve_baseline(collectors(), root / "state" / "baseline.json", "fixture", True)
            with patch.dict(os.environ, env, clear=False):
                with patch("mac_env.security.shutil.which", return_value=None):
                    report = doctor()
            self.assertFalse(report["ready"])
            self.assertTrue(any("not configured" in item for item in report["blockers"]))
            self.assertIn("offsite-preflight", report.get("next", ""))

    def test_live_firewall_ok_when_enabled(self):
        from mac_env.host_evidence import live_firewall

        def runner(args, timeout=1, env=None):
            if "--getglobalstate" in args:
                return {"code": 0, "stdout": "Firewall is enabled. (State = 1)\n", "stderr": ""}
            return {"code": 0, "stdout": "Firewall stealth mode is on\n", "stderr": ""}

        with patch("mac_env.host_evidence.Path.exists", return_value=True):
            record = live_firewall(NOW, runner=runner)
        self.assertEqual(record["status"], "ok")
        self.assertEqual(record["findings"], [])

    def test_offsite_bootstrap_rejects_local_restic(self):
        with self.assertRaises(BackupError):
            bootstrap_offsite_backup(
                "/tmp/state/local-restic/repo",
                "/tmp/password",
                ["/tmp/data"],
                confirm=True,
                runner=drill_fake_restic,
            )

    def test_backup_status_reports_local_only(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            env = {
                "MAC_ENV_STATE_DIR": str(root / "state"),
                "MAC_ENV_RESTIC_REPOSITORY": str(root / "state" / "local-restic" / "repo"),
                "MAC_ENV_RESTIC_PASSWORD_FILE": str(root / "password"),
            }
            (root / "password").write_text("x\n")
            (root / "password").chmod(0o600)
            with patch.dict(os.environ, env, clear=False):
                status = backup_status()
            self.assertTrue(status["local_only"])
            self.assertFalse(status["offsite_ready"])


def drill_fake_restic(args, timeout=1, env=None):
    for name, handler in DRILL_RESTIC_HANDLERS:
        if name in args:
            return handler(args)
    return {"code": 0, "stdout": "drill1", "stderr": ""}


def write_drill_restore(args):
    target = Path(args[args.index("--target") + 1])
    payload = target / "source" / "hello.txt"
    payload.parent.mkdir(parents=True, exist_ok=True)
    payload.write_text("mac-env-recovery-drill\n")
    return {"code": 0, "stdout": "", "stderr": ""}


DRILL_RESTIC_HANDLERS = (
    ("init", lambda _args: {"code": 0, "stdout": "", "stderr": ""}),
    ("backup", lambda _args: {"code": 0, "stdout": '{"snapshot_id":"drill1"}\n', "stderr": ""}),
    ("restore", write_drill_restore),
)


def evidence_env(root):
    env = {"MAC_ENV_STATE_DIR": str(root / "state")}
    body = json.dumps({"status": "ok", "observed_at": NOW, "findings": [], "critical": 0})
    for name, key in SOURCE_ENV.items():
        path = root / f"{name}.json"
        path.write_text(body)
        env[key] = str(path)
    return env


def readiness_env(root):
    env = evidence_env(root)
    password = root / "password"
    password.write_text("fixture-password\n")
    password.chmod(0o600)
    env["MAC_ENV_RESTIC_REPOSITORY"] = str(root / "repo")
    env["MAC_ENV_RESTIC_PASSWORD_FILE"] = str(password)
    return env


def gap_record():
    return {
        "status": "error",
        "observed_at": NOW,
        "findings": [],
        "critical": 0,
        "coverage": "fixture gap",
    }
