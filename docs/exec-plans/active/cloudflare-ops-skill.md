# Exec plan: Cloudflare ops skill

Status: active
Opened: 2026-11-22
Goal: encode the two-path Cloudflare workflow so agents show privileged
commands before applying them.

## Non-goals

- Bootstrapping the Determinate Nix daemon
- Installing a sudoers rule
- Activating nix-darwin
- Removing Homebrew Wrangler or cloudflared
- Reading `~/.cloudflared/sunshine-tunnel.token`

## Change set

| Path | Role |
| --- | --- |
| `.cursor/skills/cloudflare-ops/SKILL.md` | Procedure |
| `.cursor/skills/cloudflare-ops/reference.md` | Inspected host facts and unapplied commands |
| `.cursor/skills/openshell-harness/SKILL.md` | Route Cloudflare work to the skill |

## Verification

```bash
sh scripts/check-agents.sh
wc -l AGENTS.md
```

## Status honesty

The skill is written. The daemon command, the sudoers rule, and the
nix-darwin activation were not run.
