# Block Homebrew installs

## Goal

`.cursor/hooks/block-homebrew.py` denies `brew install`, `reinstall`, `upgrade`, and `bundle`. The `beforeShellExecution` entry is not in `hooks.json`.

## Done when

The hook returns deny for those commands and allow for `brew list`. Activation is unchanged.
