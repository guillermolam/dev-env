# Project rules

These rules apply to the implemented controller and to unfinished deployment.
Passing a unit test does not mean a safeguard is installed.

## Scope and ownership

- Keep source, Rego policy, schemas, and documentation versioned together.
- Install operational state under `/private/var/lib/mac-environment` and logs
  under `/private/var/log/mac-environment`. Reserve `/nix` for Nix.
- Privileged code and configuration must be root-owned. Do not execute a
  writable checkout or search `PATH` as root.
- Run Homebrew and user-file operations as the target user.
- Keep host architecture explicit. The implemented profile is Apple Silicon.

## Policy

- OPA is the eligibility engine. Do not keep a second policy implementation or
  treat an OPA failure as success.
- Evaluate the installed trusted policy. A candidate update cannot supply the
  policy that authorizes itself.
- Tool identities are namespaced inventory IDs. Modes are `auto`, `hold`, and
  `manual`. Unlisted tools are manual.
- A hold in any applicable layer wins over `auto`. Remove that hold explicitly;
  a narrower `auto` does not release it.
- Holds apply to the whole change set, including dependencies, removals, and a
  protected Nix runtime closure. An adapter that cannot constrain dependencies
  cannot perform that unattended update.
- `auto` never bypasses vulnerability, alert, backup, freshness, or capability
  checks.
- Missing, stale, malformed, or failed evidence blocks eligibility. Compare
  finding identities and severity, not only counts.
- Unresolved suspicious access always blocks. Exceptions need a scope, reason,
  approver, and expiry. Permanent exceptions are rejected.
- Reject unknown policy keys and executable policy fields.

## Changes, backups, and recovery

- Build and validate candidates before activation. Record the source revision,
  lock file, policy fingerprint, and candidate fingerprint.
- Revalidate the saved plan immediately before execution. A changed candidate or
  evidence file invalidates it.
- Production apply stays disabled until destination, credentials, baseline, and
  collector coverage are configured.
- Partial backups, including Restic exit code 3, are failures. Publish a
  recovery manifest only after verification, and preserve the previous manifest
  on failure.
- Do not reset Git working trees or overwrite user files during provisioning.
- Quarantine is explicit and reversible. Do not automatically delete personal
  files, export 1Password vaults, reboot, or erase disks.
- Restore files only into a new empty directory first.
- Inventory reports are observations. They are not tamper-proof forensic
  evidence, and unknown provenance must remain unknown.

## Reliability

- Every Python function, method, nested function and test under `operations/`
  must have cyclomatic and cognitive complexity at most 3. Only generated
  `.cache` contents are excluded; do not add per-function suppressions.
- Measure cyclomatic complexity with Radon 6.0.1 and cognitive complexity with
  cognitive-complexity 1.3.0. The latter is that library's implementation, not a
  claim of identical Sonar scores. Ruff also enforces McCabe complexity 3.
- Prefer small domain functions, dataclasses for state, standard-library
  dispatch and injected command runners. Keep validation, collection, parsing,
  decisions and side effects separate; do not introduce class hierarchies just
  to lower a metric or hide branches outside measured functions.
- Run the quality and regression commands documented in README.md before
  changing a task to tested. Preserve validation and failure handling in refactors.

- Use locks, timeouts, and bounded retries. Do not blindly retry activation,
  deletion, or restore.
- Emit redacted structured logs. Keep secrets out of Git, the Nix store, command
  arguments, and reports.
- Tests must use fixtures and disposable directories. Update PLAN.md,
  FEATURES.md, and TASKS when status changes.
- Distinguish implemented, tested, installed, and operational. Do not claim an
  unexecuted build, restore, or migration succeeded.

## Agents and HOME

- NVIDIA OpenShell is mandatory for agent harnesses and executable tools.
  Verify the runtime boundary and loaded policy; do not trust a marker or alias.
- Host OpenShell transport is limited to reviewed control-plane operations.
  A failed sandbox call must never trigger host execution as a fallback.
- Keep agent runtime, gateway administration and host privileged operations
  separate. Workloads cannot widen their own policy or attach providers.
- Platform teams proceed without asking. Wake the operator only for a fatal
  error, a panic, a cyberattack, a data-integrity failure, or a fence drop.
  See `.agents/shared/boundary.md`.
- HOME discovery starts with metadata from a constrained trusted collector.
  Do not mount HOME or copy complete agent credential/config directories.
- Inventory hooks, plugins, skills, MCP servers and autorun paths without
  executing them. Record unknown coverage and redact secret-bearing arguments.
- Agent/toolchain updates obey existing parameterized OPA controls and holds.
  Julia, Zig, Rust and LuaJIT do not replace the Python controller.
- Follow AGENT_SECURITY_PLAN.md for the staged migration. A document is guidance,
  not evidence that every installed agent has been confined.
