#!/bin/sh
# Fail if a platform-team spec drops the autonomy contract or a paired workflow.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

fail=0
need() {
    if ! grep -R -F -q -- "$1" .agents/teams; then
        echo "missing in .agents/teams: $1" >&2
        fail=1
    fi
}

for name in \
    playbooks/investigation.md \
    playbooks/bug-fix.md \
    playbooks/perf-issue.md \
    playbooks/hillclimb.md \
    playbooks/runtime-forensics.md \
    playbooks/trace-forensics.md \
    playbooks/feature.md \
    playbooks/refactoring.md \
    playbooks/prototype.md \
    playbooks/visual-parity.md \
    playbooks/authoring-a-skill.md \
    playbooks/eval.md \
    playbooks/babysit.md \
    playbooks/shipping.md \
    playbooks/autonomous-run.md \
    playbooks/autopilot-full.md \
    playbooks/autopilot-stack.md \
    playbooks/session-pickup.md \
    playbooks/pause-safely.md \
    playbooks/multi-phase-plan.md \
    playbooks/worktree-cleanup.md \
    playbooks/opening-a-pr.md \
    ponytail/SKILL.md \
    ponytail-review/SKILL.md \
    ponytail-audit/SKILL.md \
    ponytail-debt/SKILL.md \
    ponytail-gain/SKILL.md \
    ponytail-help/SKILL.md \
    figure-it-out/SKILL.md \
    interrogate/SKILL.md \
    technical-writing/SKILL.md \
    unslop/SKILL.md
do
    need "$name"
done

for verb in deploy provision configure maintain secure harden troubleshoot remediate; do
    if ! grep -F -q -- "$verb" .agents/README.md; then
        echo "README missing verb: $verb" >&2
        fail=1
    fi
done

count=0
for file in $(find .agents/teams -name '*.md' | sort); do
    count=$((count + 1))
    for line in \
        '## Goal' \
        '## Done when' \
        'do not ask the operator' \
        'Wake the operator only for a fatal error' \
        'supervisor intercepts the proxied API'
    do
        if ! grep -F -q -- "$line" "$file"; then
            echo "$file missing: $line" >&2
            fail=1
        fi
    done
    if grep -E -q 'Ask the operator|operator review|operator-only' "$file"; then
        echo "$file asks the operator" >&2
        fail=1
    fi
done

if [ "$count" -ne 21 ]; then
    echo "expected 21 team specs, found $count" >&2
    fail=1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for the step hook" >&2
    fail=1
fi

hook_out=$(printf '%s' '{"tool_name":"Shell","tool_input":{"command":"echo SECRET_PLANTED_VALUE"}}' | python3 .cursor/hooks/step-alert.py postToolUse)
printf '%s' "$hook_out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "additional_context" in d; assert "Do not ask the operator" in d["additional_context"]'
if printf '%s' "$hook_out" | grep -F -q SECRET_PLANTED_VALUE; then
    echo "step hook leaked a planted secret into the alert" >&2
    fail=1
fi
if [ -f .agents/runs/steps.jsonl ] && grep -F -q SECRET_PLANTED_VALUE .agents/runs/steps.jsonl; then
    echo "step hook leaked a planted secret into the ledger" >&2
    fail=1
fi
stop_out=$(printf '%s' '{"subagent_type":"platform-deploy"}' | python3 .cursor/hooks/step-alert.py subagentStop)
printf '%s' "$stop_out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "followup_message" in d'

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "check-agents: 21 specs, workflows paired, stop set intact, step hook alerts"
