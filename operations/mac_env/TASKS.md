# Tasks

| ID | Status | Acceptance evidence | Blocker |
| --- | --- | --- | --- |
| T01 | Tested | Root documents and task tables updated | None |
| T02 | Tested | CLI, config validation, lock, redaction, and controlled execution tests | Not installed |
| T03 | Partial | Inventory diff, Git, Nix, and Homebrew parser tests; live signature collection absent | Signature and full receipt collection |
| T04 | Tested | Private CSV/Markdown/JSON and incomplete-diff behavior | Live snapshots remain outside Git |
| T05 | Partial | Non-destructive folder apply test | Brew and dotfiles are not migrated |
| T06 | Partial | Vulnix parser and fail-closed collector tests | Live Vulnix, Kolide, Objective-See, and integrity interfaces |
| T07 | Tested | Rego tests for auto, hold, manual, and self-authorization; Python policy regressions | No approved production baseline |
| T08 | Tested with fake Restic | Exit 3 preserves the prior manifest; nonempty restore is refused | Repository and credentials unset |
| T09 | Partial | Capability failures and disabled apply tested | No verified rollback adapter |
| T10 | Tested | Secret redaction, symlink refusal, quarantine undo | OCR detector not configured |
| T11 | Blocked | Disabled plist and refusing installer | Deployment inputs absent |
| T12 | Partial | Runbook and restore safety test | No spare-machine drill |
| T13 | Partial | Local 6 Rego and 56 Python tests; CI job added | CI job and Nix package build not executed here |
| T14 | Tested locally | 300 Python functions; cyclomatic/cognitive maxima 3/3; Ruff passes; CI gate added | Hosted CI and Nix build not run |

Dependencies follow T01 through T13 in [PLAN.md](PLAN.md). A later task is not
operational merely because its code exists.

## Agent migration and language additions

| ID | Status | Acceptance evidence | Blocker |
| --- | --- | --- | --- |
| T15 | Bootstrap verified | OpenShell 0.1.9 installed; mTLS and sandbox denial probes passed | Fleet confinement not established |
| T16 | Planned | HOME metadata/provenance fields and coverage rules specified | Scoped collector and deployment review |
| T17 | Planned | Agent and tool migration acceptance specified | Per-agent integration and reviewed cutover |
| T18 | Planned | Identity/audit/OPA failure cases specified | Existing Rego defects and telemetry integration |
| T19 | Planned | Julia/Zig/Rust/LuaJIT toolchain and smoke-test plan | Package ownership and Darwin/Linux validation |
| T20 | Planned | Migration/recovery acceptance specified | Backup destination and spare-machine drill |

Dependencies and the execution prompt are in [AGENT_SECURITY_PLAN.md](AGENT_SECURITY_PLAN.md).
