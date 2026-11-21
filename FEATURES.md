# Feature status

Implemented means code exists. Tested means the listed local checks passed.
Neither means installed or operational.

| Capability | Status | Evidence and limit |
| --- | --- | --- |
| Apple Silicon nix-darwin configuration | Existing | One `mac-studio` profile; not changed by the controller |
| Controller CLI | Implemented, tested | Command modules import and representative commands are covered |
| OPA/Rego decisions | Implemented, tested | 6 Rego tests; missing or malformed OPA blocks |
| Per-tool update policy | Implemented, tested | `auto`, `hold`, `manual`; unlisted defaults to manual |
| Hold over indirect Nix changes | Implemented, tested | Unconstrained Nix adapter cannot bypass a hold |
| Configurable update criteria | Implemented, locally tested | Rego uses `max_new_findings` / `max_critical`; layer precedence tool>channel>host>shared>defaults; candidate security status/freshness gated; 10/10 Rego tests |
| Python complexity/style gate | Implemented, locally tested | 300 functions; max cyclomatic/cognitive 3/3; Ruff passes; CI gate added |
| Backup eligibility compatibility | Implemented, tested | Prior 9 cases pass through OPA |
| Inventory export | Implemented, tested | CSV, Markdown, and JSON; formula injection neutralized |
| Inventory diff and provenance parsers | Implemented, tested | Incomplete collection cannot confirm removal |
| Nix profile and Homebrew receipt parsers | Implemented, tested | Live profile listing is attempted; receipt collection is not the default |
| Application signatures | Not implemented | Presence data does not include signature verification |
| Vulnix parser | Implemented, tested | Live scan not run; missing database time cannot be `ok` |
| Firewall, endpoint, access, integrity collectors | Implemented, fail closed | File evidence via `MAC_ENV_*_EVIDENCE`; unset env → coverage gap |
| sbomnix/vulnxscan | Not provisioned | Absence is reported, not treated as success |
| Restic backup and selective restore | Implemented, tested with a fake | Password mode 0600 enforced; destination unset for production |
| Recovery drill | Implemented, live + fake tested | Live: restic 0.19.1 via `nix build .#restic`; receipt `receipts/recovery-drill-2026-11-21.json` |
| Local backup bootstrap | Implemented, live + tested | `backup bootstrap-local --confirm`; receipt `receipts/local-bootstrap-2026-11-21.json`; offsite still required |
| Offsite R2 destination | Bucket ready, not wired | Cloudflare `mac-env-restic` (WEUR); Path C in `docs/operations/offsite-restic.md`; rclone remotes empty until operator token |
| Evidence scaffold | Implemented, live | `security scaffold-evidence` writes honest error/ok JSON; does not fake coverage |
| Agent HOME inventory (T16) | Implemented, fixture-tested | `mac-env agents inventory`; hashes only; no secret values; LaunchAgents listed |
| Update planning | Implemented, tested | Real adapters report rollback and candidate scan as unavailable |
| Production update apply | Disabled | Returns disabled even when a fixture decision would allow it |
| Housekeeping | Implemented, tested | Local patterns, redacted report, reversible quarantine; no OCR |
| Provisioning apply | Implemented, tested | Creates missing folders only; does not overwrite or delete |
| Scheduling | Template only | Plist is disabled; installer refuses to bootstrap it |
| 1Password recovery | Documented boundary | Native history only; no export |
| Full filesystem recovery | Runbook only | No automatic erase and no spare-machine drill |
| System installation | Not installed | `/private/var/lib/mac-environment` was not created; state-dir resolution and plist env wired for install |
| New-Mac / compromise checklists | Documented | `operations/recovery/CHECKLISTS.md` evidence tables; no live drill yet |
| Nix runtime and homelab modules | Implemented, unbuilt | Runtime packages and service manifests declared; central DNS/PKI disabled; no activation or smoke tests |
| Agent harness (docs/CI) | Level 3 COMPLETE (local) | `make verify-harness`: 0 errors/warnings; hooks via `.envrc`; checkpoints CI declared |
| Doctor readiness path | Fixture-proven | All evidence env + baseline + restic env → `doctor.ready` true (unit test) |
| OpenShell controller sandbox | Proposed | `docs/openshell/work-sandbox.md`; not created/applied |

The last validation run was 10/10 Rego tests and 67/67 Python tests. Coverage
percentage was not measured. `doctor.ready` is true only when blockers is empty
(fixture E2E proves the path). Live recovery-drill and local bootstrap succeeded
2026-11-21 (local/disposable repos only). Harness Level 3 COMPLETE locally.
Evidence scaffold honestly reports all collectors as incomplete on this host.

## Agent security and languages

| Capability | Status | Evidence and limit |
| --- | --- | --- |
| OpenShell 0.1.9 bootstrap | Installed, locally verified | Reviewed release formula and SHA-256; gateway authenticated; isolated sandbox ready |
| OpenShell Nix provision | Implemented in tree | `homelab/openshell-package.nix` + `scripts/openshell-provision.sh`; start not yet live-verified |
| Container runtimes provision | Tested live | Script + brew --zap purge; Nix OrbStack/Podman/Colima/Desktop running; mirrors `home/container-runtimes.nix` |
| Sandbox denial checks | Passed locally | Protected directory and external TCP denied; no HOME/socket mounts; seccomp and Landlock observed |
| All-agent OpenShell enforcement | Required, not implemented fleet-wide | Existing desktop agents and separate tool connectors have not been migrated |
| HOME hidden-agent inventory | Planned, first priority | Metadata/provenance schema and scoped collector design in AGENT_SECURITY_PLAN.md |
| Agent identity and durable audit | Planned | OpenShell provider/OPA integration; loss and coverage must be measured |
| Julia, Zig, Rust and LuaJIT | Planned | Locked Nixpkgs ownership and native/sandbox smoke tests still required |
| Bootstrap provenance table | Recorded | operations/bootstrap-inventory.csv; archive hashes, not executable hashes |

This work changed documentation and recorded bootstrap evidence. It did not
rerun the controller tests or change the Python implementation.
