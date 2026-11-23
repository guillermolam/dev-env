# OpenShell, HOME agents and language toolchains

Status: reviewed plan plus a verified bootstrap; fleet enforcement is pending.
Updated: 2026-11-19.

## Priority and scope

Secure existing agents before expanding their permissions or enabling scheduled
updates. HOME means /Users/glam; ~/.. is its parent /Users and is not the audit
scope. Inspect hidden configuration and user application state as well as visible
project files. The plan does not grant agents a blanket HOME mount.

Keep controller state at /private/var/lib/mac-environment and durable reports at
/private/var/log/mac-environment after reviewed installation. /nix remains owned
by Nix. The official OpenShell bootstrap currently uses Homebrew paths below;
moving its state requires a separately tested migration.

## What was actually verified

OpenShell 0.1.9 was installed from NVIDIA's release formula after reviewing it
and matching its published SHA-256:
4864f608963a64b1ec94771f3bd93eec64a2371891ff443ad633a0cb6448015f.

| Item | Observation |
| --- | --- |
| Installation | Local Homebrew tap nvidia/openshell; CLI, gateway, prover and bundled VM driver |
| Executables | /opt/homebrew/Cellar/openshell/0.1.9; public links in /opt/homebrew/bin |
| Service | sh.brew.openshell; enabled as the user's Homebrew service |
| Gateway | https://127.0.0.1:17670; bound to 127.0.0.1 only; version 0.1.9; mTLS authenticated. Not a browser UI: `localhost` resolves to ::1 first, and a browser tab lacks the client certificate. |
| Gateway config/state | /opt/homebrew/var/openshell |
| Service logs | /opt/homebrew/var/log/openshell |
| CLI registration | $HOME/.config/openshell; sensitive operator state |
| Runtime TLS material | $HOME/.local/state/openshell/homebrew/tls; not agent input |
| Credential permissions | Gateway TLS directories 0700; runtime client key 0600; owned by the user |
| Engine | Existing OrbStack Docker API; Docker 29.8.2, Linux ARM64 |
| Sandbox | mac-env-bootstrap; ID 3d74a992-6f5a-4511-ac33-d5f08c887864 |
| Workload image ID | sha256:fef8f2708dbb85fbfcba6503d805397d89d9210f375362ff3b9f7888eb297ca5 |
| Policy | Loaded revision 1; a45a8ff3564f00ae26cbd66f1131f37eedd8b54a66fbfec103d65a204c19c6e8 |
| Identity/process | UID/GID 1000; all capability sets zero; NoNewPrivs=1; seccomp filtering enabled |
| Network | Workload network mode none; no outbound policy rules; no providers |
| Filesystem | No HOME or Docker socket mount; only OpenShell control/channel volumes |
| Landlock | ABI 10 available; ABI 3 rules applied; 13 applied, 0 skipped |
| Negative probes | Protected OpenShell directory denied; TCP 1.1.1.1:443 denied immediately |
| Project access | Only dev-env uploaded into /sandbox/dev-env; edits executed there |

These are point-in-time checks, not a complete escape audit or a signed
attestation. NVIDIA explicitly lists Docker Desktop for supported macOS hosts;
OrbStack passed these local checks but is not thereby vendor-qualified. The
bootstrap uses the default best_effort user filesystem policy. Require and
test hard_requirement in the production policy, including an unavailable-path
failure test. Preserve mandatory baseline protection.

No existing agent was migrated, disabled or restarted. No HOME inventory or
secret-content scan was performed. No provider credentials were imported.
Installing OpenShell does not automatically contain existing desktop apps,
their extensions, MCP servers or host shell sessions.

## Target boundary

An operator owns the gateway, policy and credential providers. Each agent runs
as a non-root process in a separate OpenShell workspace/sandbox with a private
home and only the selected repository or staged data. An external desktop UI
must route all execution and tool access through that boundary. If an agent's
integration cannot do that, record it as unsupported and block its automated
launch after a reviewed cutover. Do not claim shell aliases enforce this.

Use OpenShell's OPA-backed network enforcement and endpoint-bound credential
providers. Prefer short-lived, narrowly scoped grants where the upstream
service supports them; placeholders do not turn static upstream keys into
ephemeral identities. Retain separate application-level authorization and
approval for consequential SaaS operations. No additional identity vendor is
selected in this plan.

Agent identity, human initiator, session, sandbox, image digest, loaded policy
hash, tool request and decision must be correlated in audit records. Keep
policy administration and credential issuance outside the agent boundary.
An agent can propose a change but cannot approve its own increased access.

## HOME inventory and migration

A deterministic, operator-installed collector reads explicitly scoped host
metadata and exports a private, redacted manifest for sandbox analysis. It is
not a general shell endpoint. Host mutation uses separately reviewed fixed
operations; never provide an agent-controlled root command channel.

Prioritize these surfaces, discovering actual paths instead of assuming every
tool uses the same layout:

| Surface | Record and review |
| --- | --- |
| Agent homes | .codex, .claude, .config, .cursor, .continue, OpenCode and other discovered tool homes |
| macOS application state | Agent-owned Library/Application Support directories and application signatures |
| Startup | LaunchAgents, agent-related LaunchDaemons, login items, shell startup files, PATH shims |
| Extensions | Skills, plugins, hooks, executable templates, trust/approval settings, auto-updaters |
| MCP/tools | Local subprocess command, remote endpoint, transport, permissions, identity and credential references |
| Credential exposure | Presence, permissions, references and scope; no raw secrets, vault exports or full auth-file copies |
| Projects | Agent settings, .env metadata, direnv trust, build hooks and local execution overrides |
| Files and photos | Report-only misplaced/sensitive-file candidates; local OCR and quarantine remain separate reviewed tasks |

Capture skipped paths, TCC/permission failures, symlink destinations and unreadable
items as unknown coverage. Do not follow symlinks outside the approved scope.
Do not evaluate shell startup files, load plugins or run an agent just to inspect
its version. Hash configuration locally; never log values. Configuration hashes
and filenames can also be sensitive, so full reports stay outside Git with
restricted permissions.

Use CSV plus a Markdown summary initially; no Parquet dependency is needed.
Use stable IDs and separate observations from desired state. For each asset:
name/type, version, executable/config paths, resolved path, owner/mode,
installation method, source/revision/signature, artifact/config hash, updater,
autorun source, sandbox compatibility and migration status. For each permission:
agent ID, provider/MCP ID, transport, endpoint with secrets removed, credential
reference and scope, approved filesystem/network access, expiry and approver.
For each run: observed_at, collector version, coverage/errors, human/session ID,
sandbox/image/policy IDs, decision, test evidence and change/recovery references.
Unknown values stay unknown; timestamps alone must not count as configuration drift.

Do not copy entire agent homes into a sandbox. Recreate reviewed config, attach
scoped providers, and migrate only selected nonsecret state. Back up old config
before cutover, test the new launcher, then explicitly retire the host launcher.
The user must choose an interruption window before stopping active sessions.

## Parameterized policies

Extend the existing versioned configuration and OPA schema together. Do not add
these as executable settings until validation, merging and Rego tests exist.

| Criterion | Intended default |
| --- | --- |
| Runtime | OpenShell required for every agent; no host fallback |
| Admission | Authenticated gateway, accepted configuration and loaded expected policy |
| Failure | Missing/stale/error evidence, degraded isolation or incomplete inventory blocks promotion and updates |
| Filesystem | Selected workspace writable; host credentials and administration state inaccessible |
| Network | Deny by default; explicit binary/service/method/path permissions |
| Policy approval | Manual, outside the workload; no self-approval or automatic widening |
| Tool updates | Existing auto/hold/manual and pins; unlisted manual; hold includes indirect changes |
| Agent-specific update scope | Harness, plugins, skills, hooks, MCP servers, language package managers, images and runtime |
| Freshness/retention | Explicit max evidence age, log-gap limit and retention values per environment |
| Exceptions | Explicit scope, rationale, reviewer and expiry; never silently waive OpenShell |

OpenShell's internal OPA policy is distinct from the controller's update/backup
eligibility policy. Both must pass. Existing Rego freshness/threshold defects
remain blockers. Store approved policy outside writable candidate content;
invalidate approval when its candidate, image, provider or effective-policy
fingerprint changes.

Collect gateway, supervisor and workload audit streams into durable storage.
NVIDIA documents bounded queues, dropped events under pressure and ephemeral
supervisor files. Measure loss and missing coverage; absence of alerts is not
proof of health. Treat code scans (Vulnix/SBOM tooling) and host alert evidence
as separate inputs. Image and transitive runtime dependencies also need scanning.

## Language toolchains

These are planned additions, not installed packages or a rewritten controller.
Use the repository's locked Nixpkgs revision; select compatible Apple Silicon
and sandbox Linux ARM64 derivations by evaluation and real smoke tests.

| Language | Proposed toolchain | Acceptance |
| --- | --- | --- |
| Julia | Julia from locked Nixpkgs; evaluate julia-bin for Darwin | Start without user startup files; run a small assertion; preserve Project.toml/Manifest.toml |
| Zig | zig; matching zls if editor integration is needed | Compile and run a tiny executable; record target and compiler version |
| Rust | rustc, cargo, rustfmt, clippy; rust-analyzer for editors | Offline compile/test and format/lint fixture; preserve Cargo.lock |
| LuaJIT | luajit; matching LuaRocks only when needed | Check jit.version and execute a small Lua assertion on both target systems |

Keep existing Python orchestration. Do not introduce four new implementations.
Inventory existing rustup, juliaup, Homebrew, Nix and manually installed tools
before selecting ownership to avoid PATH conflicts. Package build scripts,
Julia startup files, Cargo build.rs and Lua modules are executable code and must
remain inside the agent boundary. No global language updater bypasses OPA holds.
Darwin builds and activation require a separately governed native builder or
operator workflow; a Linux sandbox check does not prove macOS activation.

## Ordered tasks and acceptance

| ID | Task | Depends on | Completion evidence |
| --- | --- | --- | --- |
| T15 | Bootstrap OpenShell | User exception | Installed pinned release; authenticated gateway; isolated sandbox and denial probes passed |
| T16 | Inventory HOME agent metadata | T15; scoped collector approval | Private CSV/Markdown plus explicit coverage; no credential values; symlink and unreadable-path tests |
| T17 | Migrate agent launchers and tools | T16; reviewed per-agent cutover | Agent harness and every local tool inside OpenShell; host fallback denied; incompatible apps reported |
| T18 | Integrate identity, audit and OPA gates | T17; existing Rego fixes | Scoped/expired credentials tested; policy changes cannot self-authorize; missing telemetry blocks eligibility |
| T19 | Declare Julia, Zig, Rust and LuaJIT | T16; approved package ownership | Pinned derivations, provenance and smoke tests on Darwin and Linux ARM64 |
| T20 | Migration and recovery drill | T17-T19; backup destination | New-machine rebuild, data restore and agent policy/identity verification; stale credentials not restored blindly |

Keep daily mutation disabled throughout this work. Full filesystem erase and
1Password recovery retain the existing manual boundaries.

## Prompt for the faster execution model

> Work on /Users/glam/Git/guillermolam/dev-env, staged into an operator-verified
> NVIDIA OpenShell sandbox. Read AGENTS.md, RULES.md, README.md,
> AGENT_SECURITY_PLAN.md, PLAN.md, FEATURES.md and TASKS.md.
>
> First prove gateway authentication, sandbox identity, expected loaded policy
> and actual deny behavior. All code, edits and tests run inside OpenShell.
> No direct host shell/editor/connector fallback; no HOME, Docker socket,
> gateway credential or vault mount. A prior bootstrap approval is not a blanket
> host exception. Report unavailable execution integration honestly.
>
> Preserve all existing changes and CLI compatibility. Execute only the approved
> task IDs from T16-T20. Start with a metadata-only HOME/agent inventory design
> and fixtures. Produce a concrete collector and access scope for operator
> review before any host deployment. Do not execute discovered hooks or plugins.
> Export private CSV/Markdown with provenance, paths, installation method,
> permissions, credential references, sandbox coverage and unknowns.
>
> Use OpenShell providers and OPA; do not add a second Python eligibility engine
> or another identity service without a demonstrated requirement. Keep policy
> administration outside the workload. Fix the documented freshness/status,
> threshold/precedence and Nix executable-path defects before enabling updates.
> Add the four language toolchains using the locked Nixpkgs after resolving
> existing package ownership. Keep Python orchestration.
>
> Every Python function, nested function and test must have cyclomatic and
> cognitive complexity <=3 under the pinned analyzers. Prefer existing helpers,
> typed data and injected effects. Preserve validation; add focused negative
> tests at security boundaries. Run the relevant Python, Rego and quality
> checks inside OpenShell, and native Darwin validation through the approved
> builder only. Do not claim unrun tests or activation succeeded.
>
> Update root documentation and both task tables with actual evidence.
> Do not enable unattended mutation, stop existing sessions, export vaults,
> quarantine/delete files, reboot or erase disks without the specific reviewed
> operation being approved. Finish with changes, tests, blockers and exact
> installed versus planned status.

## Primary references

- [NVIDIA CLI skill](https://github.com/NVIDIA/OpenShell/blob/main/skills/openshell-cli/SKILL.md)
- [Pinned release](https://github.com/NVIDIA/OpenShell/releases/tag/v0.1.9)
- [Installation](https://docs.nvidia.com/openshell/v0.1.9/about/installation)
- [Support and kernel requirements](https://docs.nvidia.com/openshell/v0.1.9/about/support-matrix)
- [Default policy](https://docs.nvidia.com/openshell/v0.1.9/how-it-works/policies/default-policy)
- [Provider profiles](https://docs.nvidia.com/openshell/v0.1.9/how-it-works/providers/profiles)
- [Audit export limits](https://docs.nvidia.com/openshell/v0.1.9/observability/ocsf-json-export)
