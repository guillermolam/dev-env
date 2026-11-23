# 1Password Environments for mac-env secrets

Status: operator guide. No secrets are stored in Git.

## Purpose

Keep `MAC_ENV_RESTIC_PASSWORD_FILE` contents and related env vars in 1Password
Environments, then mount a local `.env` outside the repo.

Docs: https://www.1password.dev/environments/

## Environment (created 2026-11-21)

| Field | Value |
| --- | --- |
| Name | `mac-env-offsite` |
| Environment ID | `5jqdtvndl7342gn7u6nhfaqz7q` |

Seeded placeholders may exist in this Environment; **replace them** before use:

| Name | Notes |
| --- | --- |
| `MAC_ENV_RESTIC_REPOSITORY` | Real offsite URL after `rclone config` (not `…/local-restic/…`, not `REPLACE_*`) |
| `MAC_ENV_RESTIC_PASSWORD` | Strong password; materialize to a 0600 file for restic |
| `MAC_ENV_OPA` | Optional path to pinned opa binary |
| `MAC_ENV_RESTIC` | Optional path to restic binary |

`rclone` is on the host via Homebrew and declared in `home/guillermo.nix`. No remotes are configured yet (`rclone listremotes` empty).

Alternate offsite schemes once credentials exist: `sftp:…`, `rest:…`, `s3:…`.
SSH config lists `10.0.0.13` / `100.87.184.9` — usable only after you confirm
the host, path, and key; agents do not init restic there unsolicited.

Then:

```sh
PYTHONPATH=operations python3 -m mac_env backup bootstrap-offsite --confirm \
  --repository "$MAC_ENV_RESTIC_REPOSITORY" \
  --password-file "$MAC_ENV_RESTIC_PASSWORD_FILE" \
  --path "$HOME/Documents" \
  --restic ./result/bin/restic
```

Restic's `--password-file` needs a file. After mounting the Environment, write
the password to `~/.local/state/mac-environment/restic-password` with mode 0600
(or use a small wrapper that materializes it for one run).

## Local bootstrap vs offsite

1. `mac-env backup bootstrap-local --confirm --path …` creates an on-box recovery
   point under the state dir (`local-restic/`). Use immediately for crash/theft
   of working tree only. Proven 2026-11-21 with restore round-trip
   (`receipts/local-restore-roundtrip-2026-11-21.json`).
2. Create a 1Password Environment for **offsite** repository credentials
   (MCP: `plugin-1password-1password` after `aikido`/operator auth — agents do
   not call authenticate without explicit approval).
3. Init offsite restic with the Environment-backed password-file (0600).
4. Run a verified snapshot + empty-dir restore; store snapshot ID in a recovery
   manifest outside Git.
5. Point `MAC_ENV_RESTIC_REPOSITORY` at the offsite URL; keep local bootstrap as
   a secondary, not the only copy.

## Minimal offsite checklist (operator)

| Step | Evidence |
| --- | --- |
| Environment created (no secret in Git) | Environment name |
| Password file mode 0600 | `ls -l` mode only |
| `restic snapshots` lists ≥1 ID | snapshot ID |
| Restore into new empty dir + content match | path + match note |
| Scoreboard row updated | `receipts/GOAL-SCOREBOARD.md` |

## Agent boundary

Do not mount 1Password Environment files or the password file into OpenShell
sandboxes. Agents propose; operators materialize secrets on the host.
