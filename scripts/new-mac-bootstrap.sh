#!/bin/sh
# Non-activating new-Mac bootstrap helper. Never runs darwin-rebuild or sudo.
# Exit 0 when cold-start prerequisites for this repo are present.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
fail=0

ok() { printf 'OK  %s\n' "$1"; }
bad() { printf 'BAD %s\n' "$1"; fail=1; }
step() { printf '\n== %s ==\n' "$1"; }

step "1. Host tools"
command -v nix >/dev/null 2>&1 && ok "nix" || bad "install Determinate Nix first"
command -v python3 >/dev/null 2>&1 && ok "python3" || bad "python3 missing"
uname -m | grep -q arm64 && ok "aarch64 host" || bad "this flake targets Apple Silicon only"

step "2. Flake build (no activation)"
if command -v nix >/dev/null 2>&1; then
	if DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure --no-link '.#restic' >/dev/null 2>&1; then
		ok "nix build .#restic"
	else
		bad "nix build .#restic failed"
	fi
fi

step "3. Controller prerequisites"
sh "$ROOT/scripts/check-recovery-prereqs.sh" || true

step "4. Next operator-only actions (not run here)"
printf '%s\n' \
	"- Review generation: nix build --impure '.#darwinConfigurations.mac-studio.system'" \
	"- Activate only after review: sudo darwin-rebuild switch --impure --flake $ROOT#mac-studio" \
	"- Source private restic env (local bootstrap or 1Password offsite)" \
	"- Fill operations/recovery/CHECKLISTS.md section A with evidence" \
	"- Provision OpenShell gateway: make openshell-provision && make openshell-start" \
	"- Approve OpenShell controller sandbox: docs/openshell/CREATE.md"

step "5. Checklist pointer"
[ -f "$ROOT/operations/recovery/CHECKLISTS.md" ] && ok "CHECKLISTS.md" || bad "CHECKLISTS.md missing"

echo
if [ "$fail" -eq 0 ]; then
	echo "Cold-start tooling looks present. Activation and offsite backup remain operator steps."
	exit 0
fi
echo "Cold-start incomplete."
exit 1
