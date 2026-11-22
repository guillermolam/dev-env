# One vault hook

## Goal

`.cursor/hooks/onepassword-vault.py` denies 1Password vaults other than
`fsekn2smjmqh3jz3yien6pjifq`.

## Done when

`beforeShellExecution` and `beforeMCPExecution` call the script.
A command that names another vault, or lists items without this vault, is deny.
`op whoami` and `op item list --vault fsekn2smjmqh3jz3yien6pjifq` are allow.
