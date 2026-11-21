# --- Agent Harness Targets ---
# See AGENTS.md for available commands.

.PHONY: verify-harness harness-status check-recovery new-mac-bootstrap checklist-evidence prepare-controller-uploads goal-progress doctor offsite-preflight rclone-r2 r2-token-rclone openshell-status openshell-provision openshell-start openshell-stop openshell-restart runtimes-status runtimes-provision runtimes-start runtimes-stop runtimes-restart

## Verify harness consistency (docs, references, commands)
verify-harness:
	@sh scripts/with-bash4.sh scripts/verify-harness.sh --format=text

## Show current harness maturity level
harness-status:
	@sh scripts/with-bash4.sh scripts/verify-harness.sh --format=text --status

## Recovery prerequisites (non-mutating)
check-recovery:
	@sh scripts/check-recovery-prereqs.sh

## New-Mac cold-start checks (never activates)
new-mac-bootstrap:
	@sh scripts/new-mac-bootstrap.sh

## Capture auto-fillable CHECKLISTS evidence (never activates / never claims B)
checklist-evidence:
	@sh scripts/checklist-evidence.sh

## Stage opa+restic digests for OpenShell upload (no sandbox create)
prepare-controller-uploads:
	@sh scripts/prepare-controller-uploads.sh

## Evidence-only recover-ready progress (no activation)
goal-progress:
	@sh scripts/goal-progress.sh

## Doctor with evidence + local-restic env when present (no activation)
doctor:
	@sh scripts/doctor.sh

## Offsite compromise-ready preflight (rclone/netbird/repo scheme)
offsite-preflight:
	@sh scripts/offsite-preflight.sh

## Configure rclone remote r2 for mac-env-restic (needs R2_* env secrets)
rclone-r2:
	@sh scripts/rclone-r2-configure.sh

## Create bucket-scoped R2 API token from wrangler OAuth → rclone (operator --confirm)
r2-token-rclone:
	@sh scripts/r2-token-to-rclone.sh --confirm

## OpenShell gateway status (read-only)
openshell-status:
	@sh scripts/openshell-provision.sh status

## Build pinned OpenShell + write certs/config/plist (operator --confirm)
openshell-provision:
	@sh scripts/openshell-provision.sh provision --confirm

## Start OpenShell LaunchAgent and wait for status (operator --confirm)
openshell-start:
	@sh scripts/openshell-provision.sh start --confirm

## Stop OpenShell LaunchAgent (operator --confirm)
openshell-stop:
	@sh scripts/openshell-provision.sh stop --confirm

## Restart OpenShell LaunchAgent (operator --confirm)
openshell-restart:
	@sh scripts/openshell-provision.sh restart --confirm

## Container runtimes status (OrbStack/Podman/Colima; read-only)
runtimes-status:
	@sh scripts/container-runtimes-provision.sh status

## Build flake runtimes + write configs (operator --confirm)
runtimes-provision:
	@sh scripts/container-runtimes-provision.sh provision --confirm

## Start OrbStack, Podman machine, Colima, Podman Desktop (operator --confirm)
runtimes-start:
	@sh scripts/container-runtimes-provision.sh start --confirm

## Stop/kill container runtimes (operator --confirm)
runtimes-stop:
	@sh scripts/container-runtimes-provision.sh stop --confirm

## Restart container runtimes (operator --confirm)
runtimes-restart:
	@sh scripts/container-runtimes-provision.sh restart --confirm
