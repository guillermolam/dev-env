#!/usr/bin/python3
"""Block Homebrew package installs. Nix is the install path."""

import json
import re
import sys

INSTALL = re.compile(
    r"(?:^|&&|\|\||[;&|`\n])\s*"
    r"(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*"
    r"(?:sudo(?:\s+-\S+)*\s+)?"
    r"(?:\S*/)?brew\s+(install|reinstall|upgrade|bundle)\b"
)

DENY = {
    "permission": "deny",
    "user_message": (
        "Homebrew install is blocked. Use nix-darwin, pkgs, Home Manager, and the flake."
    ),
    "agent_message": (
        "Do not install with Homebrew. Add the package as pkgs in "
        "home/guillermo.nix home.packages and in flake.nix packages.aarch64-darwin. "
        "The configuration is darwinConfigurations.mac-studio. "
        "Show sudo darwin-rebuild switch --impure --flake .#mac-studio before activation."
    ),
}


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        data = {}
    command = str(data.get("command") or "")
    decision = DENY if INSTALL.search(command) else {"permission": "allow"}
    json.dump(decision, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
