# Exec plan: census board

Status: active
Opened: 2026-11-22
Goal: print current, operational, and left counts on every agent step and after
every commit. Keep workload A running while its left count is not 0.

## Non-goals

- Marking a checklist step done without its predicate
- Activating the Mac from the counter
- Reading file contents, crontab lines, or secret values

## Change set

| Path | Role |
| --- | --- |
| `census/` | Rust counter `mac-env-census` |
| `scripts/census-board.sh` | Build if needed, print the board |
| `.githooks/post-commit` | Print the board after commit; commit still succeeds |
| `.cursor/hooks/census-board.py` | Board on session start, every tool step, and stop |
| `.cursor/hooks.json` | `stop` follow-up while workload A left is not 0 (`loop_limit` 14) |

## Verification

```bash
cargo test --manifest-path census/Cargo.toml
make check-agents
make census
```

## Status honesty

The counter is implemented and its unit tests passed. The live board is a
measurement, not a claim that workload A is finished. Eight A steps stay open.
