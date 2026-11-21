# Offsite restic (operator)

Doctor refuses `…/local-restic/…`. You need a destination that survives host
compromise or theft.

Current blocker inventory: `receipts/offsite-blocker-2026-11-21.json`.
Preflight: `make offsite-preflight`.

Likely unlock on this machine: Cloudflare R2 Path C (bucket ready), or
`netbird up` for homelab SFTP, or any other rclone remote.

Do **not** reuse `platform-tofu-state`. Dedicated empty bucket:
`mac-env-restic` (WEUR). Receipt: `receipts/r2-bucket-2026-11-21.json`.

## Path A — rclone (generic)

```sh
rclone config          # create a remote
sh scripts/rclone-offsite-check.sh
```

Set in 1Password Environment `mac-env-offsite` (replace placeholders):

- `MAC_ENV_RESTIC_REPOSITORY=rclone:<remote>:<path>`
- `MAC_ENV_RESTIC_PASSWORD` → materialize to a 0600 password file

```sh
PYTHONPATH=operations python3 -m mac_env backup bootstrap-offsite --confirm \
  --repository "$MAC_ENV_RESTIC_REPOSITORY" \
  --password-file "$MAC_ENV_RESTIC_PASSWORD_FILE" \
  --path "$HOME/Documents" \
  --restic ./result/bin/restic
```

## Path C — Cloudflare R2 (preferred on this account)

Bucket `mac-env-restic` exists and is empty. Operator creates an R2 API token
(Object Read & Write, scoped to that bucket) in the Cloudflare dashboard, then:

```sh
# Create token in dashboard (Object Read & Write → bucket mac-env-restic only):
# https://dash.cloudflare.com/?to=/:account/r2/api-tokens
# secrets only in env / rclone.conf / 1P — never in Git
export CLOUDFLARE_ACCOUNT_ID='<account_id>'
export R2_ACCESS_KEY_ID='...'
export R2_SECRET_ACCESS_KEY='...'
sh scripts/rclone-r2-configure.sh
sh scripts/rclone-offsite-check.sh
export MAC_ENV_RESTIC_REPOSITORY='rclone:r2:mac-env-restic/mac-studio'
```

Then run Path A bootstrap-offsite with that repository.

## Path B — SFTP (homelab)

Only after you confirm host identity and a dedicated empty directory:

```sh
export MAC_ENV_RESTIC_REPOSITORY='sftp:user@host:/path/to/restic-repo'
```

SSH config currently mentions `10.0.0.13` / `100.87.184.9`. Agents do not init
restic on those hosts without your explicit path + key confirmation.

## Verify

```sh
PYTHONPATH=operations python3 -m mac_env backup status
# offsite_ready: true
```
