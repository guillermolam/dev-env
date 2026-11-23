# OpenShell fence and stop set

This file is the contract for every team under `.agents/teams/`. It is not
enforcement. OpenShell and OPA are.

## Platform

This personal platform is one Apple Silicon Mac, profile `mac-studio`, declared
in this repo. The teams deploy, provision, configure, maintain, secure, harden,
troubleshoot, and remediate that machine.

## Autonomy

Do not ask the operator. Proceed. A red test, a missing pin, a denied egress,
or a hold is the owning team's repair.

Wake the operator only for:

- a fatal error the team cannot recover, including a kernel panic
- a panic loop that survives one restart
- a cyberattack, including suspected compromise, an unexpected policy hash,
  a secret in git, or credential use from the wrong binary
- a data-integrity failure: restic exit 3, an unverified snapshot, a non-empty
  restore destination, a checksum mismatch, or evidence that would authorize a
  bad activation
- a change that drops the OpenShell fence

A missing cloud token is a recorded gap. Do not claim the missing piece is done.
Do not wake the operator to ask for the token.

Disk erase, macOS Recovery, and credential rotation off a suspect machine stay
stopped. Those are the cyberattack case. After the operator returns an erased
machine, full recovery continues without further questions.

## Fence

The host CLI, SDK, and TUI are transport. The workload runs in the sandbox.
The supervisor intercepts the proxied API after allow and before credential
injection. A failed sandbox call stops the task. No host shell, host Python,
Docker exec, or unrestricted connector as a fallback.

Record gateway auth, sandbox id, image digest, policy revision, and
enforcement before a mutation. `audit` is not `enforce`. Unknown or degraded
enforcement is a fence failure. Wake the operator.

Do not mount HOME, `/Users`, `/`, the Docker socket, the SSH agent, Keychain,
vault storage, or gateway admin credentials.

A network allow does not attach a credential. Human OAuth keeps the refresh
token at the gateway. A SPIFFE grant uses the sandbox JWT-SVID as the client.
A SPIFFE exchange keeps the user subject token at the gateway and injects only
the final bearer. `policy set` replaces the whole base policy. Keep filesystem,
Landlock, and process.

The workload does not widen its own policy, attach a provider, or switch
`enforce` back to `audit`. Those drop the fence. A narrower rule proceeds.

Host activation of this platform is normal work for the deploy team when the
stop set is clear. It is not a fallback for a failed sandbox call.

## Each step

A project hook alerts the agent after every tool step and when a subagent stops. The receipt stores the event name, the tool name, and whether it failed. It does not store arguments, file contents, or secrets. Change a spec, skill, command, or example only when the receipt contradicts a Done when in `.agents/teams/`. A step that matches the spec changes nothing.

## Status

These specs are written. They are not an admitted OpenShell workload, and they
have not activated this Mac. Production apply stays fail-closed until evidence,
baseline, and backup destination are real. Closing those gaps is the team's
job. Forging them is a data-integrity failure.
