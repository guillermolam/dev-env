"""mac-env command line. Mutating commands revalidate plans and stay disabled in production."""

import argparse
import json
from pathlib import Path

from policy import evaluate

from mac_env.agent_inventory import inventory_agents
from mac_env.backup import BackupError, create_backup, repository_config, restore_files
from mac_env.config import validate_document
from mac_env.evidence_scaffold import scaffold_evidence
from mac_env.housekeeping import quarantine, scan, undo
from mac_env.inventory_ext import collect_inventory, diff_reports
from mac_env.local_backup import bootstrap_local_backup
from mac_env.offsite_backup import backup_status, bootstrap_offsite_backup
from mac_env.opa_eval import evaluate_input
from mac_env.recovery_drill import run_recovery_drill
from mac_env.runtime import LockError, log_event, state_dir
from mac_env.security import collect_security
from mac_env.tools_policy import list_tools, load_tools, remove_tool, set_tool
from mac_env.updates import apply_plan, plan_channel
from mac_env.workflows import approve_baseline, daily, doctor, provision_apply, provision_plan


def main(argv=None):
    parser = argparse.ArgumentParser(prog="mac-env")
    commands = parser.add_subparsers(dest="command", required=True)
    add_inventory(commands)
    add_agents(commands)
    add_security(commands)
    add_policy(commands)
    add_provision(commands)
    add_update(commands)
    add_backup(commands)
    add_restore(commands)
    add_housekeeping(commands)
    add_recovery_drill(commands)
    commands.add_parser("daily").set_defaults(
        func=lambda _args: print_json(daily(Path(__file__).resolve().parents[2]))
    )
    commands.add_parser("status").set_defaults(func=lambda _args: print_json(doctor()))
    commands.add_parser("doctor").set_defaults(func=lambda _args: print_json(doctor()))
    args = parser.parse_args(argv)
    return dispatch(args)


def dispatch(args):
    try:
        return args.func(args)
    except (BackupError, LockError, ValueError, RuntimeError, OSError) as error:
        log_event("command_failed", command=args.command, error=str(error))
        return 2


def add_inventory(commands):
    parser = commands.add_parser("inventory")
    sub = parser.add_subparsers(dest="action", required=True)
    collect = sub.add_parser("collect")
    collect.add_argument("--output", type=Path, required=True)
    collect.add_argument("--git-root", type=Path, default=Path.home() / "Git")
    collect.set_defaults(func=cmd_inventory_collect)
    diff = sub.add_parser("diff")
    diff.add_argument("old", type=Path)
    diff.add_argument("new", type=Path)
    diff.set_defaults(func=cmd_inventory_diff)
    export = sub.add_parser("export")
    export.add_argument("snapshot", type=Path)
    export.set_defaults(func=cmd_inventory_export)


def add_agents(commands):
    parser = commands.add_parser("agents")
    sub = parser.add_subparsers(dest="action", required=True)
    collect = sub.add_parser("inventory")
    collect.add_argument(
        "--root",
        type=Path,
        required=True,
        help="Scoped root to scan (fixture or HOME); never mounts into OpenShell",
    )
    collect.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Private output directory (mode 0700); keep out of Git",
    )
    collect.set_defaults(func=cmd_agents_inventory)


def add_security(commands):
    parser = commands.add_parser("security")
    sub = parser.add_subparsers(dest="action", required=True)
    collect = sub.add_parser("collect")
    collect.add_argument("--output", type=Path, required=True)
    collect.set_defaults(func=cmd_security)
    scaffold = sub.add_parser("scaffold-evidence")
    scaffold.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Private directory for honest evidence JSON + env.exports",
    )
    scaffold.set_defaults(func=cmd_security_scaffold)


def add_policy(commands):
    parser = commands.add_parser("policy")
    sub = parser.add_subparsers(dest="action", required=True)
    validate = sub.add_parser("validate")
    validate.add_argument("--policy", type=Path)
    validate.set_defaults(func=cmd_policy_validate)
    explain = sub.add_parser("explain")
    explain.add_argument("--input", type=Path, required=True)
    explain.set_defaults(func=cmd_explain)
    tools = sub.add_parser("tools")
    tool_commands = tools.add_subparsers(dest="tool_action", required=True)
    tool_commands.add_parser("list").set_defaults(func=cmd_tools_list)
    set_parser = tool_commands.add_parser("set")
    set_parser.add_argument("tool_id")
    set_parser.add_argument("--mode", required=True, choices=["auto", "hold", "manual"])
    set_parser.add_argument("--reason", default="")
    set_parser.add_argument("--pin", default="")
    set_parser.set_defaults(func=cmd_tools_set)
    remove = tool_commands.add_parser("remove")
    remove.add_argument("tool_id")
    remove.set_defaults(func=cmd_tools_remove)
    baseline = sub.add_parser("approve-baseline")
    baseline.add_argument("--evidence", type=Path, required=True)
    baseline.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Defaults to <state_dir>/baseline.json so doctor can find it",
    )
    baseline.add_argument("--approver", required=True)
    baseline.add_argument("--confirm", action="store_true")
    baseline.set_defaults(func=cmd_approve)


def add_provision(commands):
    parser = commands.add_parser("provision")
    sub = parser.add_subparsers(dest="action", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    plan.set_defaults(func=lambda args: print_json(provision_plan(args.project)))
    apply = sub.add_parser("apply")
    apply.add_argument("--plan", type=Path, required=True)
    apply.add_argument("--target", type=Path, required=True)
    apply.set_defaults(func=cmd_provision_apply)


def add_update(commands):
    parser = commands.add_parser("update")
    sub = parser.add_subparsers(dest="action", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument(
        "--channel", required=True, choices=["nix", "homebrew", "applications", "macos"]
    )
    plan.add_argument("--evidence", type=Path, required=True)
    plan.add_argument("--baseline", type=Path, required=True)
    plan.add_argument("--tool", action="append", default=[])
    plan.set_defaults(func=cmd_update_plan)
    apply = sub.add_parser("apply")
    apply.add_argument("--plan", type=Path, required=True)
    apply.set_defaults(func=cmd_update_apply)


def add_backup(commands):
    parser = commands.add_parser("backup")
    sub = parser.add_subparsers(dest="action", required=True)
    create = sub.add_parser("create")
    create.add_argument("--evidence", type=Path, required=True)
    create.add_argument("--baseline", type=Path, required=True)
    create.add_argument("--path", action="append", required=True)
    create.set_defaults(func=cmd_backup)
    verify = sub.add_parser("verify")
    verify.add_argument("--snapshot", required=True)
    verify.set_defaults(func=cmd_backup_verify)
    bootstrap = sub.add_parser("bootstrap-local")
    bootstrap.add_argument("--path", action="append", required=True)
    bootstrap.add_argument("--restic", default=None)
    bootstrap.add_argument("--confirm", action="store_true")
    bootstrap.set_defaults(func=cmd_backup_bootstrap_local)
    offsite = sub.add_parser("bootstrap-offsite")
    offsite.add_argument("--repository", required=True)
    offsite.add_argument("--password-file", type=Path, required=True)
    offsite.add_argument("--path", action="append", required=True)
    offsite.add_argument("--restic", default=None)
    offsite.add_argument("--confirm", action="store_true")
    offsite.set_defaults(func=cmd_backup_bootstrap_offsite)
    sub.add_parser("status").set_defaults(func=cmd_backup_status)


def add_restore(commands):
    parser = commands.add_parser("restore")
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("plan").set_defaults(func=cmd_restore_plan)
    files = sub.add_parser("files")
    files.add_argument("--snapshot", required=True)
    files.add_argument("--dest", type=Path, required=True)
    files.set_defaults(func=cmd_restore_files)


def add_housekeeping(commands):
    parser = commands.add_parser("housekeeping")
    sub = parser.add_subparsers(dest="action", required=True)
    scan_parser = sub.add_parser("scan")
    scan_parser.add_argument("--root", type=Path, required=True)
    scan_parser.add_argument("--output", type=Path, required=True)
    scan_parser.set_defaults(func=lambda args: print_json(scan(args.root, args.output)))
    quarantine_parser = sub.add_parser("quarantine")
    quarantine_parser.add_argument("--plan", type=Path, required=True)
    quarantine_parser.add_argument("--dest", type=Path, required=True)
    quarantine_parser.set_defaults(func=lambda args: print_json(quarantine(args.plan, args.dest)))
    undo_parser = sub.add_parser("undo")
    undo_parser.add_argument("--manifest", type=Path, required=True)
    undo_parser.set_defaults(func=lambda args: print_json(undo(args.manifest)))


def add_recovery_drill(commands):
    parser = commands.add_parser("recovery-drill")
    parser.add_argument(
        "--workspace",
        type=Path,
        required=True,
        help="Empty directory for disposable repo, restore, and manifest",
    )
    parser.add_argument("--restic", default=None, help="restic binary (default MAC_ENV_RESTIC)")
    parser.set_defaults(func=cmd_recovery_drill)


def cmd_inventory_collect(args):
    report = collect_inventory(Path(__file__).resolve().parents[2], args.git_root, args.output)
    print_json({"rows": len(report["rows"]), "snapshot": str(args.output)})
    return 0


def cmd_inventory_diff(args):
    old = json.loads((args.old / "inventory.json").read_text())
    new = json.loads((args.new / "inventory.json").read_text())
    print_json(diff_reports(old, new))
    return 0


def cmd_inventory_export(args):
    print((args.snapshot / "inventory.md").read_text())
    return 0


def cmd_security(args):
    report = collect_security()
    args.output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print_json({"gaps": len(report["coverage_gaps"])})
    return 0


def cmd_security_scaffold(args):
    print_json(scaffold_evidence(args.output))
    return 0


def cmd_backup_bootstrap_local(args):
    print_json(bootstrap_local_backup(args.path, confirm=args.confirm, restic=args.restic))
    return 0


def cmd_backup_bootstrap_offsite(args):
    print_json(
        bootstrap_offsite_backup(
            args.repository,
            args.password_file,
            args.path,
            confirm=args.confirm,
            restic=args.restic,
        )
    )
    return 0


def cmd_backup_status(args):
    print_json(backup_status())
    return 0


def cmd_agents_inventory(args):
    report = inventory_agents(args.root, args.output)
    print_json(
        {
            "rows": len(report["rows"]),
            "errors": len(report["errors"]),
            "coverage_complete": report["coverage_complete"],
            "output": str(args.output),
        }
    )
    return 0 if report["coverage_complete"] else 2


def read_policy(path):
    if path is None:
        return load_tools()
    if path.suffix == ".json":
        return json.loads(path.read_text())
    return load_toml(path)


def cmd_policy_validate(args):
    errors = validate_document(read_policy(args.policy))
    print_json({"valid": not errors, "errors": errors})
    return 2 if errors else 0


def cmd_explain(args):
    payload = json.loads(args.input.read_text())
    print_json(evaluate_input(payload))
    return 0


def cmd_tools_list(_args):
    print_json(list_tools())
    return 0


def cmd_tools_set(args):
    print_json(set_tool(args.tool_id, args.mode, args.reason, args.pin))
    return 0


def cmd_tools_remove(args):
    print_json(remove_tool(args.tool_id))
    return 0


def cmd_approve(args):
    evidence = json.loads(args.evidence.read_text())
    output = args.output if args.output is not None else state_dir() / "baseline.json"
    print_json(approve_baseline(evidence, output, args.approver, args.confirm))
    return 0


def cmd_provision_apply(args):
    print_json(provision_apply(json.loads(args.plan.read_text()), args.target))
    return 0


def cmd_update_plan(args):
    evidence = json.loads(args.evidence.read_text())
    baseline = json.loads(args.baseline.read_text())
    tools = [{"id": tool, "change": "upgrade", "version": "", "major": False} for tool in args.tool]
    result = plan_channel(
        args.channel,
        tools,
        evidence,
        baseline,
        {"defaults": {"schema_version": 1, "updates": {}, "tools": {}}, "tool": load_tools()},
        {},
    )
    print_json(result["decision"])
    return 0 if result["decision"]["outcome"] == "allow" else 2


def cmd_update_apply(args):
    result = apply_plan(json.loads(args.plan.read_text()))
    print_json(result)
    return 0 if result["applied"] else 2


def cmd_backup(args):
    evidence = json.loads(args.evidence.read_text())
    baseline = json.loads(args.baseline.read_text())
    reasons = evaluate(evidence, baseline)
    decision = {"eligible": not reasons, "reasons": reasons, "rule_ids": []}
    manifest = create_backup(
        decision, args.path, state_dir() / "manifest.json", repository_config()
    )
    print_json(manifest)
    return 0


def cmd_backup_verify(args):
    from mac_env.backup import verify_snapshot

    verify_snapshot(args.snapshot, repository_config())
    print_json({"verified": args.snapshot})
    return 0


def cmd_restore_plan(_args):
    print_json(
        {
            "runbook": "operations/recovery/RUNBOOK.md",
            "checklists": "operations/recovery/CHECKLISTS.md",
            "automatic_erase": False,
            "onepassword": "use 1Password item history; this controller does not export vaults",
            "blockers": doctor()["blockers"],
        }
    )
    return 0


def cmd_restore_files(args):
    print_json({"destination": str(restore_files(args.snapshot, args.dest))})
    return 0


def cmd_recovery_drill(args):
    print_json(run_recovery_drill(args.workspace, restic=args.restic))
    return 0


def load_toml(path):
    import tomllib

    with path.open("rb") as handle:
        return tomllib.load(handle)


def print_json(document):
    print(json.dumps(document, indent=2, sort_keys=True))
    return 0
