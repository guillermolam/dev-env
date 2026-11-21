# Implementation plan

Updated: 2026-11-21. The controller is tested. Deployment is not installed, and
daily mutation is not enabled. Agent harness reached Level 2 PARTIAL locally
(`make verify-harness`: 0 errors; hooks and shipped checkpoints still open).

## Completed in this repository

- Preserved the existing Apple Silicon nix-darwin and Home Manager configuration.
- Added an unactivated `mac-env` flake package that wraps the controller and
  Nixpkgs OPA. The package has not been built in this session.
- Replaced the Python eligibility engine with local OPA/Rego v1. The old
  `check.py` command remains a wrapper.
- Added per-tool `auto`, `hold`, and `manual` policy, with hold winning across
  layers and indirect Nix changes.
- Added inventory comparison, provenance parsers, fail-closed collectors, Restic
  wrapper, update gates, reversible housekeeping, a disabled LaunchDaemon
  template, and a recovery runbook.
- Validated 6 Rego tests and 56 Python tests with OPA 1.22.4
  (`e6dfa065844e3a1553d665ccc4a2c0a25d1ca3925f6ed8fbaf0fa1ec2060d2a5`).

No live Vulnix scan, backup, restore drill, Nix activation, or migration has
been executed. The Nixpkgs OPA used by the flake package was not version-compared
with the tested 1.22.4 binary.

## Complexity refactor completed

- Enforced per-function cyclomatic and cognitive complexity <= 3 with pinned
  Radon and cognitive-complexity analyzers, plus Ruff style/format/McCabe checks.
- Baseline: 153 measured functions, 39 violations; worst collector 35/77.
  Result: 300 measured functions, no violations, maximum 3/3 (tests included).
- Split inventory collectors/export, schema validation, OPA execution/parsing,
  Restic command construction, quarantine planning, and private atomic writes.
- Preserved CLI/function entry points and the existing 34 tests. Added 22 tests
  for validation, serialization, export, drift detection, baseline compatibility,
  quarantine interruption, command arguments and the complexity checker.
- Added quality checks to CI; local lint, formatting, Python and Rego checks pass.
  Hosted CI and the Nix build were not run in this refactor.

## Review findings still open

- Production adapters, full backup/restore verification and security sources.
- Live restic destination (or install restic and run recovery-drill), spare-machine
  drill, OpenShell work image with python3/opa/restic (operator inputs).
- Real alert pipelines behind `MAC_ENV_*_EVIDENCE` (file fixtures work for tests).

## Review findings closed 2026-11-21

- Candidate security status/freshness (`MACENV-CANDIDATE-SECURITY-STATUS`,
  `MACENV-CANDIDATE-SECURITY-STALE`, `MACENV-CANDIDATE-DB-STALE`).
- Parameterized `max_new_findings` / `max_critical` and absolute critical caps.
- Policy numeric/bool/string/`default_tool_mode` precedence aligned with
  tool-mode resolution: tool > channel > host > shared > defaults.
- Evidence: `opa test` 10/10 (was 6/6) on pinned OPA 1.22.4.
- State dir resolution: override → `MAC_ENV_USE_INSTALLED_STATE` → user path;
  doctor no longer creates the directory; approve-baseline defaults to
  `<state_dir>/baseline.json`; LaunchDaemon template exports installed paths.
- Nix `mac-env` wrapper PATH includes `python3`, `opa`, `nix`, `restic`, plus
  `/opt/homebrew/bin` and system bins for collectors.
- Evidence: 59/59 Python tests; complexity max 3/3 on 305 functions.

Keep unattended mutation disabled until backup destination, collectors, and
install inputs exist.

## Remaining deployment inputs

- Encrypted Restic repository and a password-file reference stored outside Git.
- Explicitly approved healthy baseline. Approval code refuses unhealthy evidence
  and is not a substitute for review.
- Working interfaces for firewall alerts, endpoint alerts, suspicious access,
  and integrity. Their absence is recorded as incomplete coverage.
- Pinned Vulnix with a verified JSON schema and advisory-database observation
  time. The parser exists; the installed tool was not available for a live run.
- A tested rollback path before any channel can be marked unattended.
- A spare machine before claiming full migration or filesystem recovery.

These inputs block installation and activation. They do not block the tests
already run.

## Next commands

Do not run the installer. It exits 2 on purpose:

```sh
sh operations/deploy/install.sh
PYTHONPATH=operations MAC_ENV_OPA=operations/.cache/opa python3 -m mac_env doctor
```

After the missing inputs exist, build the package, compare its OPA version with
1.22.4, install root-owned files, and rerun `doctor`. Leave the LaunchDaemon
disabled until `doctor` reports complete coverage and a verified backup. Do not
run `darwin-rebuild switch` merely to install this controller.

## OpenShell and HOME agents take priority

The user requires NVIDIA OpenShell for every agent, including this assistant's
execution. A separately approved bootstrap installed OpenShell 0.1.9 and verified
mTLS, loaded policy, non-root execution, filesystem/network denials and no HOME
or Docker-socket mount on the existing OrbStack engine. Fleet enforcement and
desktop harness integration remain unverified.

Follow [AGENT_SECURITY_PLAN.md](AGENT_SECURITY_PLAN.md) for tasks T15-T20, the
provenance inventory, language additions and faster-model execution prompt.
The next step is T16's constrained collector and migration assessment, followed
by reviewed agent cutovers. Julia, Zig, Rust and LuaJIT remain planned additions.
No HOME scan, agent migration or language activation was performed in bootstrap.
Existing Rego and deployment blockers remain open.

## Nix runtime and homelab modules added 2026-11-20

- Added Nix-owned runtime packages with release hashes for Podman 6.2.0,
  Podman Desktop 1.30.7, OrbStack 2.2.5, Colima 0.10.3, and Incus client 7.6.
- Declared rootless Podman and Colima Incus VMs, constrained mounts/resources,
  OrbStack LAN-exposure hardening, and signed self-hosted NetBird UI support.
- Added disabled-by-default host CoreDNS/etcd/OpenBao services and rendered
  cert-manager, ExternalDNS, 1Password Operator, and OpenBao Agent integration.
- No Nix evaluation, package build, activation, runtime smoke test, VPN test,
  certificate issuance, outage test, or recovery drill has run yet. The central
  homelab remains disabled until the required nonsecret configuration and
  immutable image digests are supplied.
