# --- Agent Harness Targets ---
# See AGENTS.md for available commands.

.PHONY: verify-harness harness-status check-recovery new-mac-bootstrap prepare-controller-uploads goal-progress offsite-preflight rclone-r2 openshell-status openshell-provision openshell-start openshell-stop openshell-restart

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

## Stage opa+restic digests for OpenShell upload (no sandbox create)
prepare-controller-uploads:
	@sh scripts/prepare-controller-uploads.sh

## Evidence-only recover-ready progress (no activation)
goal-progress:
	@sh scripts/goal-progress.sh

## Offsite compromise-ready preflight (rclone/netbird/repo scheme)
offsite-preflight:
	@sh scripts/offsite-preflight.sh

## Configure rclone remote r2 for mac-env-restic (needs R2_* env secrets)
rclone-r2:
	@sh scripts/rclone-r2-configure.sh

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
