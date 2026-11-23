# dev-env operations plan

Status: draft for operator review. Created 2026-11-21 from read-only inspection of
this checkout, then re-verified inside an OpenShell sandbox the same day (section 2a).
Not committed, not pushed. Repo programs run: the agent-harness verify script, on the
host and inside the sandbox. Nothing here activates, builds, backs up, or changes the
host, and no controller, Nix or test command was run anywhere.

## 0. Evidence basis and limits

- Read: `README.md`, `AGENTS.md`, `RULES.md`, `PLAN.md`, `FEATURES.md`,
  `TASKS.csv`, `AGENT_SECURITY_PLAN.md`, `operations/` (README, RUNBOOK, installer,
  `check.py`, `inventory.py`, `policy.py`, `mac_env/cli.py`, `runtime.py`,
  `workflows.py`, `backup.py`, and grep-level reads of `opa_eval.py` and
  `tools_policy.py`; tests, tools, policy), `hosts/`, `homelab/`, `home/`, `flake.nix`,
  `pyproject.toml`, `.github/workflows/nix.yml`, `.gitignore`, `.git/HEAD`.
- Executed on the host: the agent-harness verify script (section 2), file tests, one
  SHA-256 read of `operations/.cache/opa`, and `command -v` lookups.
- Executed inside OpenShell sandbox `mac-env-work` (section 2a): the verify script,
  the cited path checks, identity and confinement probes, and a SHA-256 of the plan
  file. Control-plane calls to the gateway ran from the host client.
- Not executed: `nix` commands, `darwin-rebuild`, the controller CLI, OPA, ruff,
  unittest, restic. The `openshell` client ran only for control-plane calls
  (section 2a). Each command in section 6 is labelled `source`
  (matches repo text), `docs` (confirmed in upstream docs through Context7:
  nix-darwin rollback flags, restic restore/check), or `unverified`.
- git commands were blocked in this session by the github-release guard hook
  because `uv` is not on PATH. Branch, commit and dirty-state facts come from file
  reads only. `.git/HEAD` points at `refs/heads/nix-darwin-mac-studio`. Branch
  `main` also exists. Run `git status` and `git log` once the hook can run.
- The shared notes folder for this group of sessions was empty.
- `AGENTS.md` in this repo requires all agent repository inspection, editing and
  tests to run inside a verified NVIDIA OpenShell sandbox. The first pass (section 0
  reads, the first verify run, and this file's first write) ran on the host through
  the desktop harness, which does not meet `AGENTS.md`. The re-verification in section
  2a ran inside OpenShell. The plan file itself was written on the host and then
  uploaded, so its content is host-authored. See R1 and section 3.

## 1. Current state (as read)

| Area | State | Evidence |
| --- | --- | --- |
| Darwin config | `darwinConfigurations.mac-studio`, `aarch64-darwin`, `nix.enable = false` (Determinate Nix owns Nix) | `flake.nix`, `hosts/mac-studio/darwin.nix` |
| Controller (`operations/`) | Implemented and tested locally. Not installed. Schedule disabled. | `README.md`, `PLAN.md`, `FEATURES.md` |
| Production backup and apply | Disabled. No destination, no credential reference, no approved baseline, incomplete collector coverage. | `workflows.deployment_blockers()` |
| Homelab | All disabled. `enable = false`, service list empty, digests `null`. | `homelab/config.nix` |
| OpenShell | 0.1.9 installed through Homebrew (`/opt/homebrew/bin/openshell` is a symlink into the Cellar). Bootstrap sandbox verified. No existing agent migrated. | `AGENT_SECURITY_PLAN.md`, `FEATURES.md` |
| Claimed tests | 6 Rego, 56 Python | `FEATURES.md`. Source count: 6 `test_` rules in `decision_test.rego`; 56 `def test_` in `operations/tests/` (9 + 22 + 25). |
| Local test prerequisites | `operations/.cache/opa` is present, 62,520,178 bytes. Its SHA-256 matches the pinned `darwin_arm64` digest in `fetch_opa.py` (e6dfa065…d2a5). `operations/.cache/quality/` exists but is empty, so no quality venv. `opa` is not on PATH. | `test -e`, `shasum -a 256`, `command -v` |
| CI | `.github/workflows/nix.yml` only. Jobs: `darwin` (macos-15, build and flake check) and `controller` (ruff, complexity, OPA, Rego, unittest). | file read |
| Repo root extras | `Untitled-1.md` (pasted Context7 setup answer, not harness content), `result` symlink into the Nix store (gitignored), `.ruff_cache/` (not in `.gitignore`) | directory listing |

Repo layout (tracked-looking files, `.git` excluded):

```text
flake.nix  flake.lock  pyproject.toml  .gitignore  LICENSE
AGENTS.md  RULES.md  README.md  PLAN.md  FEATURES.md  TASKS.csv
AGENT_SECURITY_PLAN.md  Untitled-1.md
.github/workflows/nix.yml
home/{guillermo.nix,container-runtimes.nix}
hosts/mac-studio/{darwin.nix,netbird.nix,container-runtimes.nix,homelab-services.nix}
homelab/{config.nix,kubernetes.nix,netbird-package.nix,netbird-server.nix,openbao-agent.nix,runtime-packages.nix}
operations/{README.md,bootstrap-inventory.csv,check.py,inventory.py,policy.py}
operations/deploy/{install.sh,com.lamcloud.mac-environment.plist}
operations/mac_env/{cli,backup,runtime,workflows,tools_policy,security,inventory_collectors,inventory_ext,housekeeping,opa_eval,updates,files,config,validation}.py  operations/mac_env/TASKS.md
operations/policy/{defaults.toml,macenv/decision.rego,macenv/decision_test.rego}
operations/recovery/RUNBOOK.md
operations/tests/{test_controller,test_policy,test_refactor}.py
operations/tools/{check_complexity.py,fetch_opa.py}
```

## 2. Harness verify (agent-harness skill, verify step)

Run from the dev-env root. Harness output:

```text
Level 1 -- Basic
  ✓ AGENTS.md exists
  ✓ AGENTS.md is index-format (31 lines)
  ✗ AGENTS.md missing ## Commands section
  ✓ docs/ directory exists
Level 2 -- Verified
  ✓ All references resolve
  ✓ No build system files found to check commands against
  ✗ docs/ARCHITECTURE.md missing
  ✗ CI harness workflow missing -- create .github/workflows/harness-verify.yml
Level 3 -- Enforced
  ! No git hooks auto-setup detected (.envrc hooksPath, .husky/, or composer.json post-install-cmd)
  ! no .harness/checkpoints.yml
  ! PR template missing (.github/pull_request_template.md or org-level)
  ✓ No drift detected
Summary: Level 1 PARTIAL | 3 error(s), 3 warning(s)   (exit 1)
```

The first run, before `docs/` existed, reported 4 errors, including `docs/ directory
missing`. The block above is the second run, after `docs/` was created.

Environment problem: the script uses `declare -A`. macOS `/bin/bash` is 3.2 and
exits 2 with `declare: -A: invalid option`. The run above used a Nix-provided bash
5.x from the Nix store. Run the script with bash 4 or newer on any host. The OpenShell
image has bash 5.2 and runs the script unchanged (section 2a).

Remediation suggestions. Not applied, because this session was asked to verify only.

1. Add a `## Commands` section to `AGENTS.md`. List only commands that are
   verified here, and mark the OpenShell-only ones.
2. Create `docs/ARCHITECTURE.md`. `docs/` now exists because this plan lives under `docs/plans/`.
3. Add `.github/workflows/harness-verify.yml`. Run it on `ubuntu-latest`, not on
   `macos-15`, so bash is 4 or newer.
4. Defer the PR template, git hooks and `.harness/checkpoints.yml` until Level 2 passes.
5. The verify script checks links only inside `AGENTS.md`. The broken `TASKS.md`
   link in `README.md` (D7) is therefore not caught.

Re-run the script after the remediation in items 1-3 to get a current result.

## 2a. OpenShell re-verification (2026-11-21)

Scope: re-check gateway, sandbox identity, loaded policy, confinement, the verify step,
and the cited repo paths from inside OpenShell. Nothing was created, started, stopped,
or re-policied. No provider was attached. The only write into a sandbox was the
dev-env upload and the staged verify script (both under `/sandbox`).

Gateway and client:

| Item | Observation |
| --- | --- |
| Client | OpenShell 0.1.9 at `/opt/homebrew/bin/openshell` |
| Gateway | `openshell`, `https://127.0.0.1:17670`, type local, auth mTLS. Status: Connected, Authenticated (mTLS transport), version 0.1.9. Bound to IPv4 loopback only; `localhost` resolves to ::1 first, so a browser tab to `https://localhost:17670` gets `ECONNREFUSED`. This port is the mTLS gRPC/HTTP API, not a web UI. |
| Client identity | `openshell-client`, provider mtls, role `openshell-user`, no scopes listed. Not an admin role. |

The desktop Bash sandbox denied the localhost gateway connection (`Operation not
permitted`). The client calls in this section ran with that sandbox disabled, one
permission gate per call. Workload commands ran inside OpenShell. The desktop sandbox
setting is an operator decision (section 9, item 9).

Sandboxes on this gateway:

| Name | Phase | Notes |
| --- | --- | --- |
| `mac-env-bootstrap` | Error | ID `3d74a992-…`. `ConfigurationPending`, `ImagePreparationTimedOut` since 2026-11-20T18:21:33Z. Cannot run a workload. Policy revision 1, hash `a45a8ff3…c6e8`. |
| `mac-env-work` | Ready | ID `034904f1-…`, created 2026-11-20 17:54:48. Supervisor connected, configuration accepted, restart policy `always`. Policy revision 1, same hash `a45a8ff3…c6e8`. No providers. Used for this section. |
| `harness-tools`, `harness-main`, `harness-adapters`, `harness-structure`, `harness-contracts`, `harness-deps`, `harness-sdk-deps` | Stopped | Not referenced by this plan. Not touched. |

Effective policy for `mac-env-work` (`openshell sandbox get`, `openshell policy get`):
filesystem `include_workdir: true`; read-only `/bin /usr /lib /proc /dev/urandom /etc
/var/log`; read-write `/tmp /dev/null`; Landlock `compatibility: best_effort`. No
network section is listed. Policy history shows one entry, revision 1, `Loaded`.

Confinement probes, run inside `mac-env-work`:

| Probe | Result |
| --- | --- |
| Identity | uid 1000 (`ubuntu`), gid 1000 |
| Capabilities | `CapEff` 0, `CapBnd` 0 |
| Privilege and filter | `NoNewPrivs: 1`, `Seccomp: 2` (filter mode) |
| HOME and workdir | `HOME=/sandbox`, `pwd=/sandbox` |
| Host paths | `/Users`, `/var/run/docker.sock`, `/opt/homebrew/var/openshell` absent. `/root` exists but is not readable. |
| Writes | `/usr` denied. `/etc` denied. `/tmp` and `/sandbox` writable. |
| TCP egress | `1.1.1.1:443` denied or unreachable. `example.com:443` denied (DNS and TCP). |
| Gateway from workload | `127.0.0.1:17670` unreachable from inside. The workload cannot reach the control plane. |
| Landlock | Not re-observed. The earlier bootstrap note says ABI 10 with ABI 3 rules applied. |

Image: Ubuntu 24.04.5 LTS, bash 5.2.21. Present: `bash`, `timeout`, `sh`, `ls`,
`cat`, `tar`. Absent: `python3`, `nix`, `darwin-rebuild`, `restic`, `opa`, `uv`,
`sudo`, `launchctl`, `openshell`, `git`. So the controller CLI and its tests cannot
run in this image, and the image has no network egress to fetch them.

Upload and verify inside the sandbox:
- `/Users/glam/Git/guillermolam/dev-env` uploaded to `/sandbox/dev-env` with `.gitignore`
  filtering. The filter removed `.git`, `operations/.cache`, `result` and `.ruff_cache`.
  60 files in the sandbox copy.
- The verify script staged at `/sandbox/tools/verify-harness.sh` from the plugin cache.
  The upload was unfiltered, since the file is outside a Git work tree.
- Verify step inside the sandbox (bash 5.2, no Nix bash needed): Level 1 PARTIAL,
  3 errors, 3 warnings. Same findings as the second host run. The drift check was
  skipped because the image has no git binary.
- Cited path checks inside the sandbox: 70 of 70 matched the expectation for the
  uploaded tree. 59 repo paths present. 11 absent: 5 removed by the upload filter
  (`result`, `operations/.cache` with its two children, `.ruff_cache`), and 6
  expected-absent paths (`docs/ARCHITECTURE.md`, the PR template, `.harness/checkpoints.yml`,
  `Makefile`, `TASKS.md`, `scripts/`).
- The sandbox holds the plan file as it was when the project was uploaded, SHA-256
  `700e105f5c85432119533503c99622dd9d5591ffb2102c6d0155fd4f660b2db4`. Both copies
  matched at that point. This section's own edits were made after the upload, so the
  host copy is now newer and differs from the sandbox copy. Re-upload the file to
  refresh the sandbox copy.

Not verified in this section: Landlock enforcement, any controller or test command,
OPA, nix builds, darwin-rebuild, restic, the bootstrap sandbox's earlier denial checks
(it cannot run a workload now), and any provider or policy change.

## 3. Governance gates (apply to every team and agent)

- **G1 Operator-only.** These belong to the operator and are never delegated to an
  agent: `sudo`, `darwin-rebuild switch` and rollback, `launchctl`, writes under
  `/private/var/lib/mac-environment` and `/private/var/log/mac-environment`, baseline
  approval with `--confirm`, `housekeeping quarantine`, `provision apply`, restore
  into a live path, GitHub secret changes (`DEVENV_USER`), backup destination and
  password-file changes, OpenShell gateway, policy or provider changes, interruption
  windows.
- **G2 Propose, do not self-approve.** An author cannot approve a change to its own
  policy, sandbox, or baseline. Source: `RULES.md` ("a candidate update cannot supply
  the policy that authorizes itself"), `AGENT_SECURITY_PLAN.md` ("an agent can
  propose a change but cannot approve its own increased access").
- **G3 Execution boundary.** Until T17 in `AGENT_SECURITY_PLAN.md` is complete, agents
  do read-only analysis and drafting only. Any agent execution goes through OpenShell.
  A failed sandbox call is a blocker, not a reason to run on the host.
- **G4 Status honesty.** Use the four states from `RULES.md`: implemented, tested,
  installed, operational. When status changes, update `PLAN.md`, `FEATURES.md` and
  `TASKS.csv` in the same change.
- **G5 Complexity.** Every Python function, nested function and test under
  `operations/` stays at cyclomatic and cognitive complexity 3 or lower. No
  per-function suppressions.
- **G6 Secrets.** Nothing secret goes into Git, the Nix store, command arguments,
  logs or reports. Use placeholders such as `<DEVENV_USER>`, `<RESTIC_PASSWORD_FILE>`.

## 4. Teams

| Team | Owns (paths) | Responsibilities | Approves |
| --- | --- | --- | --- |
| **Operator** (human, repo owner) | Host activation, `/private/var/*`, GitHub secrets, backup destination and password file (outside Git), baseline approval, OpenShell gateway and providers, interruption windows | The only actor that runs `sudo`, activates generations, approves baselines and widens access. Final sign-off on every change. | All changes |
| **Platform (Nix-Darwin)** | `flake.nix`, `flake.lock`, `hosts/mac-studio/darwin.nix`, `home/guillermo.nix`, formatter setup. Language toolchains (T19) once accepted. | Keep `darwinConfigurations.mac-studio` building and formatted. Flake input updates. Declare toolchains from locked Nixpkgs after acceptance. | Operator; Architect review for new modules |
| **Homelab & Runtimes** | `homelab/*.nix`, `hosts/mac-studio/{netbird,container-runtimes,homelab-services}.nix`, `home/container-runtimes.nix` | Keep every service disabled by default. Set NetBird management URL and runtime versions with hashes. Enforce resource ceilings and drift refusal. | Operator; Security reviews any exposure |
| **Controller (Python)** | `operations/mac_env/{cli,runtime,workflows,files,config,validation,updates,opa_eval,tools_policy}.py`, `operations/check.py`, `operations/inventory.py`, `operations/policy.py`, `operations/tests/*` | CLI, locks, redaction, state, workflows. Keep complexity at most 3 and keep validation and error handling intact. | Policy team for any change to eligibility; Operator for merges |
| **Policy (OPA/Rego)** | `operations/policy/defaults.toml`, `operations/policy/macenv/decision.rego`, `operations/policy/macenv/decision_test.rego`, tool hold/auto/manual semantics | Rego decisions. Fix the open freshness, threshold and precedence defects (PLAN.md). Hold beats auto. Missing evidence blocks. | Security reviewer and Operator (two-person rule) |
| **Backup & Recovery** | `operations/mac_env/backup.py`, `operations/recovery/RUNBOOK.md` | Restic wrapper, verify, selective restore into new empty directories, restore drills. Partial backup (exit 3) is a failure. | Operator |
| **Security** | `operations/mac_env/{security,inventory_collectors,inventory_ext,housekeeping}.py`, security coverage gaps. Reviewer pool for Policy and Agent Security changes. | Collectors fail closed. Track coverage gaps. Review Rego, backup, collector and sandbox changes. No merge rights on its own changes. | Operator |
| **Agent Security (OpenShell)** | `AGENT_SECURITY_PLAN.md`, `operations/bootstrap-inventory.csv`, the OpenShell policy and provider definitions when they are added to the repo. Host state under `/opt/homebrew/var/openshell` and `~/.config/openshell` is sensitive and stays outside Git. Sandbox inventory: `mac-env-bootstrap` is in Error and `mac-env-work` is Ready (section 2a). | Sandbox policy and provider scoping. Sandbox inventory and health. HOME inventory design (T16). Agent cutovers (T17). Audit streams (T18). | Operator; Security review |
| **CI & Supply Chain** | `.github/workflows/nix.yml`, `pyproject.toml`, `operations/tools/fetch_opa.py`, `operations/tools/check_complexity.py`, action SHA pins | Keep CI matching the README. Own OPA 1.22.4 pin and its SHA-256 values. Own quality tool pins. | Operator; Security for any pin change |
| **Docs & Harness** | `README.md`, `AGENTS.md`, `RULES.md`, `PLAN.md`, `FEATURES.md`, `TASKS.csv`, `operations/README.md`, `operations/mac_env/TASKS.md`, `docs/` (to create), triage of `Untitled-1.md` | Keep status docs honest. Fix broken links and path drift (section 7). Run and fix the harness verify step. | Operator |

Work-streams that cross teams: toolchains (T19) are Platform work, accepted by Agent
Security. The HOME inventory collector (T16) is Agent Security work, reviewed by
Security. Migration recovery (T20) is Backup & Recovery work, run by the Operator.

## 5. Agents

Agents are roles, not standing processes. Each row names the catalogue agent type or
skill to use. "Skill" rows are invoked with the Skill tool. Every agent works under
gate G3: read-only until T17 is complete.

| Agent | Type / skill | Team | Scope | Must not |
| --- | --- | --- | --- | --- |
| A1 Architect | `Plan` | All | Design notes and ADR drafts under `docs/adr/` (create when needed) | Edit code. Run host commands. |
| A2 Repo explorer | `Explore` | All | Fan-out read-only search and inventory | Write files |
| A3 Controller engineer | `python-development:python-pro` | Controller | Edits and tests under `operations/mac_env/` and `operations/tests/`, complexity 3 | Change Rego behaviour (send to A4). Run `darwin-rebuild`. |
| A4 Policy author | `general-purpose`, with OPA focus. The catalogue has no dedicated Rego agent. | Policy | `operations/policy/**`, with `opa test` | Approve its own policy change |
| A5 Nix & CI engineer | `cicd-automation:cicd-automation-deployment-engineer` | Platform, CI & Supply Chain | `flake.nix`, `flake.lock` proposals, `nix.yml` edits | Touch the `DEVENV_USER` secret. Activate anything. |
| A6 Ops troubleshooter | `cicd-automation:cicd-automation-devops-troubleshooter` | All (diagnosis) | Read-only diagnosis of failing build, test, `doctor` or CI output. Proposes the fix. | Run `sudo`. Clear a lock file while a process holds it. |
| A7 Security reviewer | `comprehensive-review:comprehensive-review-security-auditor` | Security | Review of diffs touching Rego, backup, collectors, OpenShell, pins | Merge. Approve its own review. |
| A8 Code reviewer | `comprehensive-review:comprehensive-review-code-reviewer` | All | Diff review for correctness, complexity and tests | Edit |
| A9 Architecture reviewer | `comprehensive-review:comprehensive-review-architect-review` | Platform, Agent Security | Review of the Nix, Darwin and OpenShell boundary | Edit |
| A10 Harness & docs maintainer | `agent-harness:agent-harness` skill, plus `engineering:documentation` skill | Docs & Harness | Run the verify step. Reconcile PLAN, FEATURES and TASKS. Fix links. | Create harness artifacts without operator approval |
| A11 Supply-chain auditor | `supply-chain-risk-auditor:supply-chain-risk-auditor` skill | CI & Supply Chain | Audit the OPA pin, `flake.lock` deltas, action SHAs, restic and OpenShell provenance | Change pins |
| A12 Release-gate reviewer | `agent-teams:team-reviewer` | All, before merge | Parallel security, architecture, test and performance review of one change set | Merge |

Change control by type:

| Change | Author | Reviewer | Approver |
| --- | --- | --- | --- |
| Rego or policy defaults | Policy (A4) | Security (A7) | Operator |
| Controller code | Controller (A3) | Code review (A8). Security (A7) if eligibility is touched. | Operator |
| Nix or host config | Platform or Homelab (A5) | Architect (A9) | Operator, who alone activates |
| CI workflow or pins | CI & Supply Chain (A5) | Supply chain (A11) | Operator |
| Backup or restore | Backup & Recovery | Security (A7) | Operator |
| HOME inventory collector (T16) | Agent Security | Security (A7) | Operator |
| Docs or status | Docs & Harness (A10) | Code review (A8) | Operator |

## 6. Lifecycle

Command labels: `source` = matches repo text; `docs` = confirmed in upstream docs;
`unverified` = not checked; `operator-only` = see G1. None of these commands ran in
this session.

### 6.1 Install

Owner: Platform (build and checks). Operator (activation).

Preconditions: Apple Silicon Mac. Determinate Nix installed. The macOS account name
is supplied through `DEVENV_USER`, which `flake.nix` reads (falling back to
`SUDO_USER`, then `USER`). Evaluation needs `--impure`. Decide the canonical checkout
path first (section 9, item 1).

```bash
# Platform: build and check (source: .github/workflows/nix.yml, README.md)
DEVENV_USER=<DEVENV_USER> nix flake check --impure --all-systems --no-build
DEVENV_USER=<DEVENV_USER> nix fmt -- --check flake.nix hosts/mac-studio/*.nix home/*.nix homelab/*.nix
DEVENV_USER=<DEVENV_USER> nix build --impure --print-build-logs '.#darwinConfigurations.mac-studio.system'
DEVENV_USER=<DEVENV_USER> nix build .#mac-env   # controller package, not activated (source: README.md)

# Operator-only: activate (source: README.md)
sudo nix run nix-darwin/master#darwin-rebuild -- switch --impure --flake <CHECKOUT>#mac-studio   # first bootstrap only
sudo darwin-rebuild switch --impure --flake <CHECKOUT>#mac-studio                                  # after nix-darwin exists

# Controller installer: refuses by design, exit 2 (source: operations/deploy/install.sh)
sh operations/deploy/install.sh
```

Steps:
1. Platform runs the three build and check commands on the host and records the
   output. CI runs the same three commands on `macos-15` (`nix.yml`). Their status is
   unknown until a hosted run is read.
2. Operator reviews the built `result` and the diff of the generation.
3. Operator activates with the `darwin-rebuild` command above.
4. Verify: `sudo darwin-rebuild --list-generations` (docs) shows the new generation.
   Check the firewall (stealth mode), Touch ID for sudo, and Finder extension
   settings against `hosts/mac-studio/darwin.nix` (source).
5. The controller is not installed by activation. `install.sh` must keep refusing
   until the blockers in `PLAN.md` ("Remaining deployment inputs") are cleared.

Risks:
- Lockout. `networking.applicationFirewall` stealth mode, Touch ID for sudo through
  `/etc/pam.d/sudo_local`, and home-manager file ownership all change on activation.
  Keep an open root shell before switching.
- `home-manager.backupFileExtension = "before-home-manager"` (`flake.nix`). Files that
  conflict with home-manager are renamed with that suffix. Check for them after
  activation.
- Floating inputs. `nixpkgs-unstable` and `nix-darwin/master` are locked by
  `flake.lock` but move when updated (section 6.7).
- Homebrew is not declared. `~/Brewfile` exists on this host, outside the repo, and
  was not read. `unverified`.

Rollback and teardown:

```bash
# Operator-only (docs: nix-darwin darwin-rebuild source, Context7)
sudo darwin-rebuild --list-generations
sudo darwin-rebuild --switch-generation <N>    # or -G <N>
sudo darwin-rebuild --rollback                 # previous generation
```

- Do not garbage-collect a generation that a recovery manifest still references
  (`operations/recovery/RUNBOOK.md`).
- Restore any `*.before-home-manager` file by hand, one file at a time.
- Teardown of nix-darwin itself is not documented in the repo. Gap, see R12.

### 6.2 Configure

Owner: Operator (values). Platform (`homelab/config.nix` and host files). Controller
(defaults).

| Surface | Where | Source of truth | Secret handling |
| --- | --- | --- | --- |
| macOS account | env `DEVENV_USER`, then `SUDO_USER`, then `USER` | `flake.nix` | Not committed. CI reads the `DEVENV_USER` repository secret. |
| Homelab | `homelab/config.nix` | `enable = false`, nulls, empty lists | Non-secret values only. 1Password items by name only. |
| Controller state dir | env `MAC_ENV_STATE_DIR`. Default `$HOME/.local/state/mac-environment`. | `operations/mac_env/runtime.py` | Mode 0700 created by `state_dir()` |
| Tool policy | `<state dir>/policy/tools.toml` | `operations/mac_env/tools_policy.py` | Outside Git by design |
| Policy defaults | `operations/policy/defaults.toml` | Versioned | None |
| OPA binary | env `MAC_ENV_OPA`. Default: `opa` on PATH, which is not installed on this host. A cached binary at `operations/.cache/opa` matches the pinned digest. | `operations/mac_env/opa_eval.py`; `command -v opa` | None |
| Policy directory | env `MAC_ENV_POLICY`. Default: `operations/policy`. | `opa_eval.py` | None |
| Restic | env `MAC_ENV_RESTIC_REPOSITORY`, `MAC_ENV_RESTIC_PASSWORD_FILE` (a path, not the password), `MAC_ENV_RESTIC` (default `restic`) | `operations/mac_env/backup.py` | Password file lives outside Git. Not set in this checkout. |

```bash
# Tool policy (source: operations/mac_env/cli.py; README.md uses the same form)
PYTHONPATH=operations python3 -m mac_env policy tools list
PYTHONPATH=operations python3 -m mac_env policy tools set <TOOL_ID> --mode auto|hold|manual --reason "<TEXT>" [--pin <VERSION>]
PYTHONPATH=operations python3 -m mac_env policy tools remove <TOOL_ID>

# Policy validation (source: cli.py)
PYTHONPATH=operations python3 -m mac_env policy validate [--policy <FILE>]
```

Tool IDs are namespaced, for example `brew:formula:git`. Unlisted tools are `manual`.

Risks:
- Tool holds live outside Git. Nothing reviews them in a pull request. Export and
  record them in a reviewed file (R9).
- `MAC_ENV_OPA` unset means `opa` on PATH, which may not be the pinned 1.22.4. The
  `doctor` output records the path. Check it.
- `defaults.toml` values are not yet reconciled with the open Rego threshold defects
  (`PLAN.md`).

Rollback: `policy tools remove <TOOL_ID>` or `set --mode manual`. Unset the env vars.
Delete state files only with operator approval.

### 6.3 Run

Owner: Operator. Diagnosis by A6. Code by Controller.

```bash
# Read-only in intent. It creates the state dir (state_dir() calls mkdir). source
PYTHONPATH=operations python3 -m mac_env doctor
PYTHONPATH=operations python3 -m mac_env status          # same as doctor (source: cli.py)

# Eligibility check against supplied evidence. Exit 0 eligible, 2 blocked. source
PYTHONPATH=operations python3 operations/check.py <EVIDENCE.json> <BASELINE.json>

# Explain one decision. Needs OPA. source
PYTHONPATH=operations MAC_ENV_OPA=operations/.cache/opa python3 -m mac_env policy explain --input <INPUT.json>

# Observations, not forensic evidence (RULES.md). Writes output. source
PYTHONPATH=operations python3 -m mac_env inventory collect --output <DIR> [--git-root <DIR>]
PYTHONPATH=operations python3 -m mac_env inventory diff <OLD_DIR> <NEW_DIR>
PYTHONPATH=operations python3 -m mac_env inventory export <SNAPSHOT_DIR>
PYTHONPATH=operations python3 -m mac_env security collect --output <FILE>

# One daily cycle. Collects security data and writes state/reports/latest.json.
# Does not back up or apply updates (workflows.daily). Manual only. source
PYTHONPATH=operations python3 -m mac_env daily
```

Tests and quality. OPA is already cached and matches the pinned SHA-256, so the fetch
step is needed only if that file is removed. The quality venv does not exist yet
(source: README.md, nix.yml):

```bash
python3 operations/tools/fetch_opa.py                                  # re-fetch and verify SHA-256 if the cache is missing
python3 -m venv operations/.cache/quality
operations/.cache/quality/bin/python -m pip install pip==26.3
operations/.cache/quality/bin/python -m pip install --group quality    # radon, cognitive-complexity, ruff pins
operations/.cache/quality/bin/ruff check operations
operations/.cache/quality/bin/ruff format --check operations
operations/.cache/quality/bin/python operations/tools/check_complexity.py
operations/.cache/opa test operations/policy -v
PYTHONPATH=operations MAC_ENV_OPA="$PWD/operations/.cache/opa" operations/.cache/quality/bin/python -m unittest discover -s operations/tests -v
```

Risks:
- `doctor` and `daily` write under `$HOME` by default (D1, D5).
- `daily` runs security collectors on the host. Run it only when the Operator decides.
- The operation lock (`<state dir>/operation.lock`) prevents overlap. A stale lock needs
  a process check, not a delete (section 6.4).
- Successful local test runs are not proof that restore, activation or migration works
  (`README.md`).

Teardown: remove generated output directories and the state dir only with operator
approval. Quarantined files are restored with `housekeeping undo` (section 6.6).

### 6.4 Troubleshoot

Owner: A6 diagnoses. Operator decides and acts. Controller or Policy fixes the code.

| Symptom | Check | Likely cause | Action |
| --- | --- | --- | --- |
| `doctor` shows `"opa": null` | `echo "$MAC_ENV_OPA"`; `command -v opa`; `ls -l operations/.cache/opa` | `MAC_ENV_OPA` unset and `opa` not on PATH. This is the current state on this host. | Set `MAC_ENV_OPA=operations/.cache/opa`. Run `python3 operations/tools/fetch_opa.py` only if the cached file is missing. |
| `fetch_opa.py` prints `OPA checksum mismatch` | The file is deleted by the script | Upstream asset changed, or a proxy altered the download | Do not edit the hash. Escalate to CI & Supply Chain and Security (A11, A7). |
| Command exits 2, with a JSON `command_failed` line on stderr | Read the `error` field | Validation, lock, OSError, or a Restic failure | Fix the input. Do not retry an activation, deletion or restore blindly (RULES.md). |
| `another environment operation holds the lock` | Find the process that holds `<state dir>/operation.lock` | Concurrent run, or a crashed run | Check the process. Remove the lock only when no process holds it. |
| `set DEVENV_USER and evaluate with --impure` | Environment | Variable unset | Set `DEVENV_USER` and use `--impure`. |
| `nix.enable` conflict on activation | `hosts/mac-studio/darwin.nix` | Determinate Nix owns `/etc/nix` | Keep `nix.enable = false`. Do not enable nix-darwin's Nix management. |
| `check_complexity.py` fails | Its output names the function | A function is above 3 | Split the function. No suppression (G5). |
| `opa test` fails | `-v` output | Rule or test regression | Fix the rule. Do not weaken a security rule to pass. |
| Restic exit 3 | `backup` output | Partial backup | Treated as a failure. No manifest is written (`backup.py`). Find the cause, then rerun. |
| Restic exits 10, 11, 12 | Restic output | Repository missing, locked, wrong password (docs) | Operator checks the destination and password file. |
| `declare: -A: invalid option` from verify | `bash --version` | macOS `/bin/bash` is 3.2 | Run the script with bash 4 or newer (section 2). |
| Git commands blocked by the github-release hook | Hook message | `uv` not on PATH (needs 0.5.31 or later) | Install `uv`. Do not bypass the hook. |
| `openshell` CLI cannot reach gateway | `openshell status`, `openshell whoami`, `openshell gateway list` (verified by help and a live run, section 2a). Gateway `https://127.0.0.1:17670`. | Service stopped, degraded, or mTLS credential issue | Block agent work. No host fallback (G3). |
| `openshell status` fails with `Operation not permitted` from the desktop Bash tool | Same command with the desktop sandbox disabled | The desktop Bash sandbox denies the localhost connect (section 2a) | Operator decides whether to allow the `openshell` CLI to connect to `127.0.0.1:17670` through the desktop sandbox, or run `openshell` with that sandbox disabled (section 9, item 9). Do not disable it for workload commands. |
| Browser tab to `https://localhost:17670` or `https://127.0.0.1:17670` fails | Try the same URL in a normal browser | Expected. The gateway is an mTLS API bound to `127.0.0.1:17670`; a browser has no client certificate, and the plain-HTTP path returns 404 by design | Use the `openshell` CLI. Do not import `~/.config/openshell/gateways/openshell/mtls/tls.key` into the browser. |
| Sandbox phase `Error` (`mac-env-bootstrap`) | `openshell sandbox get <name>` shows `ImagePreparationTimedOut` | Image preparation exceeded its deadline | Operator decides whether to recover or retire the sandbox (section 9, item 7). Do not restart it without approval. |
| Sudo or Touch ID broken after activation | Existing root shell | Bad generation | Roll back (section 6.1). If no root shell remains, macOS Recovery is manual only (RUNBOOK.md). |

### 6.5 Extend

Owner: as listed per item. Every extension goes through change control (section 5).

- **New tool policy entry.** Use `policy tools set` (section 6.2). Owner: Operator.
- **New evidence collector.** Must fail closed and report coverage gaps. Adding it to
  `REQUIRED` in `operations/policy.py` changes what a valid baseline is. Owner:
  Security, with Policy and Operator. Tests in `operations/tests/`.
  `REQUIRED` is currently `{vulnix, firewall, tooling, access, integrity}`.
- **New Rego rule.** Edit `operations/policy/macenv/decision.rego` and add the test
  to `decision_test.rego`. Run `opa test`. Owner: Policy, reviewed by Security.
- **New CLI command.** Add it to the matching `add_*` function in
  `operations/mac_env/cli.py`. Keep every function at complexity 3. Add tests. Owner:
  Controller.
- **New language toolchain (T19).** Declare it in `home/*.nix` from the locked
  Nixpkgs revision. Acceptance: smoke tests from `AGENT_SECURITY_PLAN.md` on Darwin
  ARM64 and Linux ARM64. Owner: Platform, accepted by Agent Security. Julia, Zig, Rust
  and LuaJIT all execute code, so they stay inside G3.
- **New homelab service.** Add it under `homelab/` and reference it from
  `hosts/mac-studio/homelab-services.nix`. Keep it disabled by default. It needs a
  stable LAN address, 1Password item names, OpenBao AppRole inputs and immutable image
  digests. Owner: Homelab & Runtimes. Security reviews exposure. `AGENTS.md` forbids
  public administrative services.

Rollback: revert the change in version control, through the operator's usual tooling.
For Nix changes, roll back the generation (section 6.1).

### 6.6 Operate

Owner: Operator. Backup & Recovery for drills. Security for coverage.

- **Scheduling.** The LaunchDaemon template is disabled. It has `Disabled = true`,
  `RunAtLoad = false`, and runs `daily` at 03:00 from
  `/private/var/lib/mac-environment/bin/mac-env` (source:
  `operations/deploy/com.lamcloud.mac-environment.plist`). Enable it only after
  `doctor` reports complete coverage and a verified backup exists (`PLAN.md`).
  Teardown: unload the job (`launchctl bootout`, `unverified`).
- **Daily report.** `<state dir>/reports/latest.json`, written only by a manual or
  scheduled `daily`.
- **Backup.** `backup create --evidence <F> --baseline <F> --path <P>` and
  `backup verify --snapshot <ID>` (source: `cli.py`). `backup create` refuses unless
  the destination and password-file variables are set, and it refuses an ineligible
  decision.
- **Restore.** `restore plan`, then `restore files --snapshot <ID> --dest <NEW_EMPTY_DIR>`
  (source: `cli.py`). The restic restore form is confirmed by docs:
  `restic restore <ID> --target <DIR>`.
- **Housekeeping.** `housekeeping scan --root <DIR> --output <FILE>`, then review,
  then `housekeeping quarantine --plan <FILE> --dest <DIR>` (reversible), then
  `housekeeping undo --manifest <FILE>` (source: `cli.py`). Owner: Operator. Nothing
  is deleted automatically (RULES.md).
- **Coverage review.** Weekly, from the `coverage_gaps` in `daily` output. Track
  changes in `PLAN.md`.
- **Logs.** Redacted JSON on stderr (`runtime.log_event`). No retention or shipping
  is defined (gap, R10).

Proposed cadence (not yet adopted; operator decides):

```bash
# Monthly once the destination exists. Full data read is expensive.
# `-r` and `check --read-data` confirmed in restic docs. `--password-file` as a long
# flag is unverified (D12).
restic -r <REPO> --password-file <PASSWORD_FILE> check --read-data
```

- Daily: `daily` report reviewed once enabled.
- Quarterly: restore drill into a new empty directory (Backup & Recovery, operator).

### 6.7 Maintain

Owner: CI & Supply Chain (pins). Platform (flake). Docs & Harness (status).

Pins in force:

| Pin | Where | Value |
| --- | --- | --- |
| Quality tools | `pyproject.toml` group `quality`; `nix.yml` | radon 6.0.1, cognitive-complexity 1.3.0, ruff 0.17.6, pip 26.3 |
| OPA | `operations/tools/fetch_opa.py` | 1.22.4, SHA-256 per platform. Not yet compared with the Nixpkgs `opa` (PLAN.md). |
| Nix inputs | `flake.lock` | Locked. `nixpkgs-unstable` and `nix-darwin/master` are floating refs. |
| Actions | `.github/workflows/nix.yml` | Full commit SHAs with version comments |
| OpenShell | Homebrew formula | 0.1.9, SHA-256 recorded in `AGENT_SECURITY_PLAN.md` |
| Runtimes | `hosts/mac-studio/container-runtimes.nix` (per `README.md`); release hashes in `homelab/runtime-packages.nix` | Podman 6.2.0, Podman Desktop 1.30.7, OrbStack 2.2.5, Colima 0.10.3, Incus client 7.6 |

Routine:

```bash
# Platform, monthly review (unverified: standard Nix CLI, not run here)
nix flake update            # then review the flake.lock diff for nixpkgs, nix-darwin and home-manager
```

- Review every `flake.lock` change as a behaviour change. Run the build and check
  commands from section 6.1 first.
- OPA: keep the pinned 1.22.4 binary until the Nixpkgs version is compared.
  Record the comparison in `PLAN.md`.
- Action SHAs: review quarterly. Update only through A11.
- After any status or CI change: re-run the verify step (section 2) and reconcile
  `PLAN.md`, `FEATURES.md` and `TASKS.csv`.
- Clean-up candidates (operator decides, nothing is deleted without approval):
  `result` (gitignored, a symlink into the Nix store to a NetBird package),
  `Untitled-1.md` (not harness content, origin unknown), and `.ruff_cache/`.
  `.ruff_cache/` is not in `.gitignore`, so add it or remove it before the next
  commit (D10).

## 7. Defects and drift found

These come from source reads. Each is open until someone fixes it.

| ID | Finding | Evidence |
| --- | --- | --- |
| D1 | Default state dir is `$HOME/.local/state/mac-environment`. RULES.md, README and the plist expect `/private/var/lib/mac-environment`. Nothing sets `MAC_ENV_STATE_DIR` for the installed path. | `runtime.py:29-33`; `RULES.md`; `com.lamcloud.mac-environment.plist` |
| D2 | The Nix wrapper's PATH is `python3` and `opa` only, so collectors that call other tools may not find them. PLAN.md lists this as an open defect. | `flake.nix:63-76`; `PLAN.md` |
| D3 | `policy approve-baseline` writes to `--output`. `doctor` reads `<state dir>/baseline.json`. Nothing enforces that the two match. | `cli.py` (`cmd_approve`); `workflows.py:100-102` |
| D4 | `deployment_blockers()` always adds "security collectors do not yet have complete coverage", and `doctor()` always returns `ready: False`. By design, but `doctor` cannot pass without a code change. | `workflows.py:122-127`, `:87-97` |
| D5 | `doctor` and `status` call `state_dir()`, which creates the directory. The README calls these read-only commands. | `runtime.py:29-33`; `operations/README.md` |
| D6 | README gives `~/code/dev-env#mac-studio` in the first activation command. The checkout is `~/Git/guillermolam/dev-env`. Line 88 uses the second path. | `README.md:44-45`, `:88` |
| D7 | README links `TASKS.md`, which does not exist. Root has only `TASKS.csv`. `AGENT_SECURITY_PLAN.md` also names `TASKS.md`. A copy exists at `operations/mac_env/TASKS.md`. | `README.md:20`; `AGENT_SECURITY_PLAN.md:192` |
| D8 | RUNBOOK says "new empty directory". `check_restore_destination` also accepts an existing empty directory. | `RUNBOOK.md:3-4, 9`; `backup.py:98-109` |
| D9 | `operations/.cache/quality/` is empty, so the README test commands fail until the venv is created and its pip group is installed. The cached OPA binary is present and hash-verified. | `test -e`; directory check |
| D10 | `.ruff_cache/` exists at the repo root and is not in `.gitignore`. | `.gitignore`; directory listing |
| D11 | `Untitled-1.md` at the repo root is a pasted Context7 setup answer. Its origin is unknown and it is not harness content. | file read |
| D12 | `backup.py` passes `--repo` and `--password-file` as long flags. Docs confirm `restore`, `check` and `-r`. The long spellings are not confirmed. `unverified`. | `backup.py:32-38`; restic docs |
| D13 | Rego freshness, threshold and precedence defects are still open. Production updates stay disabled. | `PLAN.md`, `README.md` |
| D15 | `AGENT_SECURITY_PLAN.md` and `FEATURES.md` describe `mac-env-bootstrap` as verified. On the live gateway it is in phase `Error` (`ImagePreparationTimedOut`, last transition 2026-11-20). Its denial evidence is stale. | `openshell sandbox get mac-env-bootstrap` (section 2a) |
| D16 | `mac-env-work` (Ready, created 2026-11-20 17:54:48, same policy hash) is not documented in `AGENT_SECURITY_PLAN.md` or `FEATURES.md`. Its purpose and creator are unknown. | `openshell sandbox list` (section 2a) |
| D17 | The sandbox image has no `python3`, `nix`, `opa`, `restic`, `uv`, `sudo` or `git`. The controller and its tests, which `AGENT_SECURITY_PLAN.md` requires to run inside OpenShell, cannot run in it as provisioned. | Command presence in the sandbox (section 2a) |
| D18 | The upload filter excludes `.git`, `operations/.cache` and `.ruff_cache`. The sandbox copy therefore skips the drift check (no git binary) and has no OPA binary for `opa test`. | Upload and verify output (section 2a) |

## 8. Risk register

| ID | Risk | Owner | Mitigation | Status |
| --- | --- | --- | --- | --- |
| R1 | Agents run on the host instead of inside OpenShell. The first pass of this session did so, against `AGENTS.md`. The re-verification ran inside OpenShell. The plan file was host-authored. | Operator; Agent Security | G3. Read-only agents until T17. Record host runs as exceptions. | Partly mitigated |
| R2 | Unattended mutation gets enabled by accident | Operator | Plist disabled. `install.sh` refuses. `daily` applies nothing. | Controlled |
| R3 | A baseline is approved from unhealthy evidence, or is written to a path `doctor` does not read (D3) | Operator; Controller | `approve_baseline` checks every collector is `ok`. Operator checks the output path. | Partly controlled |
| R4 | Coverage is incomplete (no firewall, endpoint, access or integrity sources). Every daily report carries gaps. | Security | Track gaps. Do not claim coverage. | Open |
| R5 | State location mismatch (D1) causes an installed daily run to write under the wrong account | Controller; Operator | Set `MAC_ENV_STATE_DIR` at install, after review | Open |
| R6 | Collectors fail because the Nix wrapper PATH is too narrow (D2) | Platform; Controller | Fix the wrapper. Test with a fake tool path. | Open |
| R7 | Rego defects let an ineligible update or backup through | Policy | Fix before any unattended channel. Keep production disabled. | Open (PLAN.md) |
| R8 | The restic password file could be readable by other accounts. The code does not check its mode. | Backup & Recovery; Operator | Check the file mode by hand (`unverified`). Keep it outside Git. | Open |
| R9 | Tool holds live outside Git and cannot be reviewed | Policy; Operator | Export `tools.toml` to a reviewed record | Open |
| R10 | No log retention, shipping or alerting. Failures can go unseen. | Security; Operator | Define retention and an alert destination | Open |
| R11 | Floating flake inputs change behaviour on update | Platform | Review every `flake.lock` diff. Build first. | Controlled |
| R12 | Activation lockout, or no documented nix-darwin teardown | Operator; Platform | Keep an open root shell. Keep the previous generation. Write a teardown note. | Open |
| R13 | Homelab services exposed before review. `AGENTS.md` forbids public admin endpoints. | Homelab; Security | Keep disabled. Require Security review before enabling. | Controlled |
| R14 | Language toolchains add executable code (Julia startup files, Cargo `build.rs`, Lua modules) outside the boundary | Platform; Agent Security | Acceptance per T19. Run only under OpenShell. | Planned |
| R15 | Documentation drift (D6, D7, D8, D11) misleads the next operator | Docs & Harness | Fix links and paths. Remove or justify `Untitled-1.md`. | Open |
| R16 | No local test evidence in this checkout (D9). CI result unknown. | CI & Supply Chain | Read the latest hosted CI run. Run the local tests after fetch and venv setup. | Open |
| R17 | git commands blocked in this environment, so repository state is only partly confirmed | Operator | Install `uv` 0.5.31 or later | Open |
| R18 | Host-level secrets (restic password file, OpenShell client registration, TLS material) | Operator; Agent Security | Keep them outside Git and outside agent mounts. Do not mount HOME. | Controlled by design |
| R19 | Stale sandbox evidence. The bootstrap sandbox is in Error, so its verified claims no longer hold (D15). | Agent Security; Operator | Re-run denial checks on a healthy sandbox. Update `AGENT_SECURITY_PLAN.md` and `FEATURES.md` (section 9, item 7). | Open |
| R20 | The sandbox image cannot run the controller or its tests, and has no network egress to fetch them (D17). Test evidence for OpenShell-run work cannot be produced in it. | Platform; Agent Security | Build or select an image with `python3`, `opa` and `restic`, with pinned artifacts staged through reviewed upload. Operator approval first. | Open |
| R21 | The desktop Bash sandbox blocks the `openshell` CLI’s localhost gateway connection. Browser access to the gateway port is expected to fail because it requires mTLS. | Operator | Decide whether to allow the `openshell` CLI to connect to `127.0.0.1:17670` through the desktop sandbox, or run `openshell` with that sandbox disabled (section 9, item 9). Keep any exception scoped to `openshell` client calls only; do not import gateway client credentials into browsers. | Open |
| R22 | Two sandboxes share one policy hash, and one of them (`mac-env-work`) has unknown provenance (D16). | Operator; Agent Security | Confirm the purpose of `mac-env-work`. Designate the sandbox for T16 to T18 work. | Open |

## 9. Decisions for the operator

1. Canonical checkout path: `~/Git/guillermolam/dev-env` (current) or `~/code/dev-env` (README).
2. Controller state location: keep the `$HOME` default for now, or set `MAC_ENV_STATE_DIR` to `/private/var/lib/mac-environment` at a reviewed install (D1).
3. Backup destination and password-file location. Both stay outside Git.
4. Whether to keep `Untitled-1.md` and the `result` symlink.
5. Whether agent-driven changes pause until T17, or continue as read-only drafts.
6. Harness: add the `## Commands` section, `docs/ARCHITECTURE.md` and the CI verify job now, or defer.
7. `mac-env-bootstrap` is in Error. Recover it, retire it, or leave it as is. Do not restart it without approval.
8. `mac-env-work` is Ready, with unknown provenance. Designate it for T16 to T18 work, or approve a new image with `python3`, `opa` and `restic` (R20, D17).
9. Allow the `openshell` CLI to connect to `127.0.0.1:17670` through the desktop Bash sandbox, or keep disabling that sandbox for `openshell` client calls only (R21). Do not import gateway client credentials into a browser; the gateway port is an mTLS API, not a web UI.

## 10. Verification log

Method: each path cited in sections 1 to 7 was checked with `test -e` (or `-L`) from
the checkout root. Commands were checked against repo text and, for the nix-darwin
rollback flags and the restic restore and check forms, upstream docs through
Context7. The only things executed were the harness verify script and the
`shasum` read of the cached OPA binary. The checks ran after this file was written.

Result: 76 path checks. Of these, 74 matched the expectation written in this file. The
2 that did not were `operations/.cache/opa` and `operations/.cache/quality`, which I
had written as absent. Both are present (D9, section 1, section 6.3). The
expectations below have been corrected to the observed state. The two paths were
confirmed present in a separate check (`test -e`, `-f`, `-d`, `shasum`), and no
other path check was re-run after the correction.

PATH presence, `command -v` only, nothing executed: `nix`, `openshell`, `python3`,
`sudo`, `launchctl` are present. `darwin-rebuild`, `restic`, `opa` and `uv` are not
on PATH on this host. `uv` being absent is why the github-release hook blocks git
commands (R17).

Repo paths expected present, all 62 PASS: every file and directory cited in section 1,
including `operations/.cache`, `.ruff_cache`, `result` and the plan file itself.

Repo paths expected absent, 6 PASS: `docs/ARCHITECTURE.md`,
`.github/pull_request_template.md`, `.harness/checkpoints.yml`, `Makefile`, `TASKS.md`
(root), `scripts/`.

Cached-artifact paths, expected present, 2 corrected: `operations/.cache/opa` (file,
hash-verified) and `operations/.cache/quality/` (empty directory).

Host paths expected absent, 2 PASS: `/private/var/lib/mac-environment`,
`/private/var/log/mac-environment`.

Host paths checked, 4 PASS: `/opt/homebrew/bin/openshell` present. `~/Brewfile` present
(not read). `~/code/dev-env` absent. `~/Git/guillermolam/dev-env` present.

OpenShell re-run (section 2a), inside sandbox `mac-env-work`: 70 path checks, 70 matched
the expectation for the uploaded tree. The verify step matched the host result. The
plan file's SHA-256 matched between host and sandbox at upload time. The host copy has
been edited since, so the sandbox copy is older. Confinement probes were run and are
listed in section 2a.

Not verified in either pass: `nix` build and check results, `darwin-rebuild`
behaviour, OPA and test results, restic behaviour against this repo's exact flags,
OpenShell subcommands, `launchctl` teardown, `nix flake update`, and the hosted CI
result.
