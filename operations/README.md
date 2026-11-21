# Machine environment operations

The controller is implemented and tested. It is not installed, and daily
mutation is not enabled.

Run read-only commands from the repository:

```sh
PYTHONPATH=operations python3 -m mac_env doctor
PYTHONPATH=operations python3 operations/check.py evidence.json approved-baseline.json
```

`check.py` is a compatibility wrapper. Exit 0 means the supplied evidence meets
the OPA policy; exit 2 blocks eligibility. A missing or malformed OPA result is
a block, not permission to continue. Set `MAC_ENV_OPA` to the pinned OPA 1.22.4
binary, or use the Nix package once it has been built and its version checked.

Policy data lives in `operations/policy`. Per-tool update choices are added with
`python3 -m mac_env policy tools set brew:formula:git --mode auto|hold|manual`.
Unlisted tools are manual. A hold in any layer wins over `auto`. Adding a tool
to `auto` does not bypass security checks. The user tool file is stored under
the state directory, not committed.

The deployment target remains `/private/var/lib/mac-environment`.
`operations/deploy/install.sh` refuses to install or bootstrap launchd, and
prints live `mac-env doctor` blockers when OPA is available.
The plist template is disabled.

Security file evidence (JSON with `status`, `findings`, `critical`,
`observed_at`) can be pointed at with:

- `MAC_ENV_FIREWALL_EVIDENCE`
- `MAC_ENV_TOOLING_EVIDENCE`
- `MAC_ENV_ACCESS_EVIDENCE`
- `MAC_ENV_INTEGRITY_EVIDENCE`
- `MAC_ENV_VULNIX_EVIDENCE` (optional file instead of live vulnix binary)

`doctor.ready` is true only when backup env, baseline, and coverage gaps are
clear. Operator guide for honest file evidence:
[docs/operations/security-evidence.md](../docs/operations/security-evidence.md).

Disposable restore proof:

```sh
PYTHONPATH=operations python3 -m mac_env recovery-drill --workspace /tmp/mac-env-drill
```

## Tests

Install the pinned quality group using the root README instructions first.
The quality environment supplies the analyzers used by checker regression tests.


```sh
operations/.cache/opa test operations/policy -v
PYTHONPATH=operations MAC_ENV_OPA=operations/.cache/opa operations/.cache/quality/bin/python -m unittest discover -s operations/tests -v
```

Tests use synthetic evidence and disposable directories. They do not change the
host, approve a baseline, or create a production backup.
