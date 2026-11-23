# Exec plan: personal platform teams

Status: active
Opened: 2026-11-21
Goal: `.agents/` teams that deploy, provision, configure, maintain, secure,
harden, troubleshoot, and remediate this mac-studio platform without asking,
and that stop for a fatal error, a panic, a cyberattack, a data-integrity
failure, or an OpenShell fence drop.

## Non-goals

- Activating this Mac from the session that wrote the specs
- Implementing `darwin-rebuild` inside the spec commit
- Vendoring Ponytail or Poteto

## Change set

| Path | Role |
| --- | --- |
| `.agents/README.md` | Team index and pairing |
| `.agents/shared/boundary.md` | Fence and stop set |
| `.agents/teams/` | One spec per agent |
| `.cursor/skills/openshell-harness/SKILL.md` | Router skill |
| `scripts/check-agents.sh` | Fails if a spec drops the contract |
| `.cursor/hooks.json` | Alerts the agent on every tool step and subagent stop |
| `.cursor/hooks/step-alert.py` | Secret-free receipt plus the one-adjustment rule |

## Verification

```bash
make check-agents
```

Record that the check passed and that no generation was activated.

## Status honesty

Specs written. Not an admitted workload. Not operational.
