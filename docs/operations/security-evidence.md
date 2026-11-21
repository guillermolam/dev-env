# Security evidence for `doctor.ready`

Fail-closed: collectors return `status: error` until a configured source
proves coverage. File sources use env vars listed in `operations/README.md`.

## Record schema (JSON)

```json
{
  "status": "ok",
  "observed_at": "2026-11-21T10:00:00+00:00",
  "findings": [],
  "critical": 0,
  "coverage": "human-readable what was checked",
  "database_observed_at": "2026-11-21T09:00:00+00:00"
}
```

`database_observed_at` is required for vulnix policy freshness when using a
file. Live `vulnix --json --system` still fails closed until that field can be
asserted (advisory DB observation time).

`status` must be the string `ok` for a collector to leave `coverage_gaps`.
Do not write `ok` for a probe that only proves a partial property.

## Collector map

| Collector | Env override | Live fallback (when env unset) | Honest path to `ok` |
| --- | --- | --- | --- |
| firewall | `MAC_ENV_FIREWALL_EVIDENCE` | `socketfilterfw --getglobalstate` | Enabled; stealth off is a finding, not auto-fail |
| tooling | `MAC_ENV_TOOLING_EVIDENCE` | `nix` + `python3` + restic present | All three available |
| access | `MAC_ENV_ACCESS_EVIDENCE` | `fdesetup status` | FileVault On |
| integrity | `MAC_ENV_INTEGRITY_EVIDENCE` | `csrutil status` | SIP enabled |
| vulnix | `MAC_ENV_VULNIX_EVIDENCE` | `vulnix --json --system` | Advisories + `MAC_ENV_VULNIX_DB_OBSERVED_AT` or file field |

Live probes do **not** attest alert pipelines or full access reviews. File
overrides still win when set. `doctor.ready` also requires an **offsite** restic
repository (paths under `…/local-restic/` are blockers).

## Scaffold then replace

```sh
PYTHONPATH=operations python3 -m mac_env security scaffold-evidence \
  --output "$HOME/.local/state/mac-environment/evidence"
```

Scaffold writes **current** live results (usually five gaps). Replace each file
only after the corresponding review. Point env vars at those paths (or copies
outside the repo). Never commit evidence with secrets.

## Baseline

After all five collectors report `ok` and backup env is set:

```sh
PYTHONPATH=operations python3 -m mac_env security baseline --confirm
```

Baseline approval is operator-only and non-automatic. Install/LaunchDaemon stay
refused until `mac-env doctor` reports `ready: true`.

## Related

- Scoreboard: `receipts/GOAL-SCOREBOARD.md`
- Policy freshness: `operations/policy/`
- Compromise path: `operations/recovery/CHECKLISTS.md` §B
