## Summary

<!-- Brief description of changes -->

## Checklist

- [ ] AGENTS.md updated (if commands or repo structure changed)
- [ ] docs/ updated (if architecture or design changed)
- [ ] New subsystems/directories documented
- [ ] Exec plan created in `docs/exec-plans/active/` (if multi-file change)
- [ ] PLAN.md / FEATURES.md / TASKS.csv updated when status changes
- [ ] No secrets, password files, or vault exports included

## Retro

<!-- Did this change reveal a reusable pattern, missing rule, or skill instruction gap? -->

- [ ] Reusable pattern detected? (N/A if purely local fix)

## Test Plan

<!-- Commands and actual results for this revision; distinguish static review
     from execution and name missing evidence or skipped checks. -->

- [ ] `make verify-harness`
- [ ] Controller/OPA tests if `operations/` changed
- [ ] Nix check/build if flake or Darwin modules changed

## Risk and Rollback

<!-- What can fail, who owns the change, and how to undo it. Scale detail to the
     change; new commits require affected evidence/approvals to be rechecked. -->

- Activation / backup / OpenShell policy changes need operator approval (G1).
