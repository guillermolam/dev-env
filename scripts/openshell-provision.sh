#!/bin/sh
# Provision and start NVIDIA OpenShell from the flake (no Homebrew).
# Operator-owned. Mutating verbs require --confirm.
#
# Usage:
#   sh scripts/openshell-provision.sh status
#   sh scripts/openshell-provision.sh provision --confirm
#   sh scripts/openshell-provision.sh start --confirm
#   sh scripts/openshell-provision.sh stop --confirm
#   sh scripts/openshell-provision.sh restart --confirm
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
LABEL="sh.mac-environment.openshell-gateway"
BREW_LABEL="sh.brew.openshell"
STATE="${MAC_ENV_OPENSHELL_STATE:-$HOME/.local/state/mac-environment/openshell}"
CONFIG_DIR="${MAC_ENV_OPENSHELL_CONFIG_DIR:-$HOME/.config/mac-environment/openshell}"
CONFIG="$CONFIG_DIR/gateway.toml"
CLI_MTLS="$HOME/.config/openshell/gateways/openshell/mtls"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
UID_NUM=$(id -u)
DOMAIN="gui/${UID_NUM}"

usage() {
	printf '%s\n' \
		"Usage: $0 <status|provision|start|stop|restart> [--confirm]" \
		"  status     Read-only probes (gateway, docker, plist)" \
		"  provision  Build flake package, write certs/config/plist (needs --confirm)" \
		"  start      launchctl bootstrap + wait for openshell status (needs --confirm)" \
		"  stop       launchctl bootout (needs --confirm)" \
		"  restart    stop then start (needs --confirm)"
}

require_confirm() {
	case " ${*:-} " in
	*" --confirm "*) return 0 ;;
	*)
		echo "refusing: pass --confirm for mutating action" >&2
		exit 2
		;;
	esac
}

have_docker() {
	if [ -S "$HOME/.orbstack/run/docker.sock" ]; then
		return 0
	fi
	if [ -S /var/run/docker.sock ]; then
		return 0
	fi
	return 1
}

docker_host() {
	if [ -S "$HOME/.orbstack/run/docker.sock" ]; then
		printf 'unix://%s/.orbstack/run/docker.sock' "$HOME"
		return 0
	fi
	printf 'unix:///var/run/docker.sock'
}

resolve_prefix() {
	if [ -n "${MAC_ENV_OPENSHELL_PREFIX:-}" ] && [ -x "$MAC_ENV_OPENSHELL_PREFIX/bin/openshell" ]; then
		printf '%s' "$MAC_ENV_OPENSHELL_PREFIX"
		return 0
	fi
	if [ -x "$ROOT/result-openshell/bin/openshell" ]; then
		printf '%s' "$ROOT/result-openshell"
		return 0
	fi
	if command -v openshell >/dev/null 2>&1; then
		# Prefer flake-built binary over Homebrew Cellar.
		bin=$(command -v openshell)
		case "$bin" in
		/opt/homebrew/* | /usr/local/Cellar/*)
			;;
		*)
			printf '%s' "$(CDPATH= cd -- "$(dirname "$bin")/.." && pwd)"
			return 0
			;;
		esac
	fi
	return 1
}

build_package() {
	echo "== nix build .#openshell =="
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-openshell" \
		"$ROOT#openshell"
}

ensure_dirs() {
	mkdir -p "$STATE/logs" "$STATE/gateway" "$STATE/vm-driver" "$CONFIG_DIR" \
		"$HOME/.config/openshell/gateways/openshell" \
		"$HOME/Library/LaunchAgents"
	chmod 700 "$STATE" "$CONFIG_DIR" "$HOME/.config/openshell" \
		"$HOME/.config/openshell/gateways" \
		"$HOME/.config/openshell/gateways/openshell"
}

write_gateway_toml() {
	cat >"$CONFIG" <<'EOF'
[openshell]
version = 2

[openshell.gateway]
compute_driver = "docker"
EOF
	chmod 0644 "$CONFIG"
}

ensure_certs() {
	prefix=$1
	if [ -f "$STATE/tls/ca.crt" ] && [ -f "$STATE/tls/server/tls.key" ]; then
		echo "certs present: $STATE/tls"
		return 0
	fi
	echo "== generate-certs =="
	mkdir -p "$STATE/tls"
	"$prefix/bin/openshell-gateway" generate-certs \
		--output-dir "$STATE/tls" \
		--server-san host.openshell.internal \
		--server-san localhost \
		--server-san 127.0.0.1
	chmod 700 "$STATE/tls"
}

install_cli_mtls() {
	mkdir -p "$CLI_MTLS"
	chmod 700 "$CLI_MTLS"
	/usr/bin/install -m 0644 "$STATE/tls/ca.crt" "$CLI_MTLS/ca.crt"
	/usr/bin/install -m 0644 "$STATE/tls/client/tls.crt" "$CLI_MTLS/tls.crt"
	/usr/bin/install -m 0600 "$STATE/tls/client/tls.key" "$CLI_MTLS/tls.key"
}

resign_vm_driver() {
	prefix=$1
	ent="$prefix/share/openshell/openshell-driver-vm.entitlements.plist"
	drv="$prefix/libexec/openshell-driver-vm"
	if [ ! -f "$ent" ] || [ ! -x "$drv" ]; then
		return 0
	fi
	# Store may be read-only; copy into state and codesign there.
	cp -f "$drv" "$STATE/vm-driver/openshell-driver-vm"
	cp -f "$ent" "$STATE/vm-driver/openshell-driver-vm.entitlements.plist"
	chmod 0755 "$STATE/vm-driver/openshell-driver-vm"
	/usr/bin/codesign --entitlements "$STATE/vm-driver/openshell-driver-vm.entitlements.plist" \
		--force -s - "$STATE/vm-driver/openshell-driver-vm" || true
}

write_plist() {
	prefix=$1
	dh=$(docker_host)
	svc="$prefix/libexec/openshell-gateway-service"
	if [ ! -x "$svc" ]; then
		echo "missing service wrapper: $svc" >&2
		exit 1
	fi
	cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>${svc}</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>HOME</key>
		<string>${HOME}</string>
		<key>MAC_ENV_OPENSHELL_STATE</key>
		<string>${STATE}</string>
		<key>MAC_ENV_OPENSHELL_CONFIG</key>
		<string>${CONFIG}</string>
		<key>OPENSHELL_COMPUTE_DRIVER</key>
		<string>docker</string>
		<key>DOCKER_HOST</key>
		<string>${dh}</string>
		<key>PATH</key>
		<string>/usr/bin:/bin:/usr/sbin:/sbin:${prefix}/bin</string>
	</dict>
	<key>KeepAlive</key>
	<true/>
	<key>RunAtLoad</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>StandardOutPath</key>
	<string>${STATE}/logs/openshell-gateway.out.log</string>
	<key>StandardErrorPath</key>
	<string>${STATE}/logs/openshell-gateway.err.log</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
	chmod 0644 "$PLIST"
}

unload_brew_conflict() {
	if launchctl print "${DOMAIN}/${BREW_LABEL}" >/dev/null 2>&1; then
		echo "== bootout Homebrew ${BREW_LABEL} (port conflict) =="
		launchctl bootout "${DOMAIN}/${BREW_LABEL}" 2>/dev/null || true
	fi
}

bootout_ours() {
	if launchctl print "${DOMAIN}/${LABEL}" >/dev/null 2>&1; then
		launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
	fi
}

bootstrap_ours() {
	unload_brew_conflict
	bootout_ours
	launchctl bootstrap "$DOMAIN" "$PLIST"
	launchctl enable "${DOMAIN}/${LABEL}" 2>/dev/null || true
	launchctl kickstart -k "${DOMAIN}/${LABEL}" 2>/dev/null || true
}

register_cli() {
	prefix=$1
	openshell="$prefix/bin/openshell"
	# Idempotent: remove then add local mTLS registration.
	"$openshell" gateway remove openshell >/dev/null 2>&1 || true
	"$openshell" gateway add https://127.0.0.1:17670 --local --name openshell
	"$openshell" gateway select openshell >/dev/null 2>&1 || true
}

wait_ready() {
	prefix=$1
	openshell="$prefix/bin/openshell"
	i=0
	while [ "$i" -lt 30 ]; do
		if "$openshell" status >/dev/null 2>&1; then
			"$openshell" status
			"$openshell" whoami
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	echo "gateway did not become ready in 30s; see $STATE/logs/" >&2
	tail -n 40 "$STATE/logs/openshell-gateway.err.log" 2>/dev/null || true
	tail -n 40 "$STATE/logs/openshell-gateway.out.log" 2>/dev/null || true
	return 1
}

cmd_status() {
	echo "== docker =="
	if have_docker; then
		echo "ok DOCKER_HOST=$(docker_host)"
	else
		echo "missing docker/orbstack socket"
	fi
	echo "== package =="
	if prefix=$(resolve_prefix); then
		echo "prefix=$prefix"
		"$prefix/bin/openshell" --version 2>&1 || true
	else
		echo "not built; run: $0 provision --confirm"
	fi
	echo "== plist =="
	if [ -f "$PLIST" ]; then
		echo "present $PLIST"
	else
		echo "absent $PLIST"
	fi
	echo "== launchd =="
	if launchctl print "${DOMAIN}/${LABEL}" >/dev/null 2>&1; then
		echo "loaded ${DOMAIN}/${LABEL}"
	else
		echo "not loaded ${DOMAIN}/${LABEL}"
	fi
	if launchctl print "${DOMAIN}/${BREW_LABEL}" >/dev/null 2>&1; then
		echo "WARNING: Homebrew ${BREW_LABEL} still loaded (will conflict on :17670)"
	fi
	echo "== listener :17670 =="
	if nc -z -G 1 127.0.0.1 17670 2>/dev/null; then
		echo "listening"
	else
		echo "not listening"
	fi
	echo "== openshell status =="
	if prefix=$(resolve_prefix) 2>/dev/null; then
		"$prefix/bin/openshell" status 2>&1 || true
		"$prefix/bin/openshell" whoami 2>&1 || true
	fi
}

cmd_provision() {
	require_confirm "$@"
	if ! have_docker; then
		echo "refusing: start OrbStack (or Docker) so the docker socket exists" >&2
		exit 1
	fi
	build_package
	prefix=$(resolve_prefix) || {
		echo "build succeeded but prefix unresolved" >&2
		exit 1
	}
	ensure_dirs
	write_gateway_toml
	ensure_certs "$prefix"
	install_cli_mtls
	resign_vm_driver "$prefix"
	write_plist "$prefix"
	register_cli "$prefix"
	echo "provisioned. next: $0 start --confirm"
	echo "prefix=$prefix"
	echo "config=$CONFIG"
	echo "state=$STATE"
	echo "plist=$PLIST"
}

cmd_start() {
	require_confirm "$@"
	if ! have_docker; then
		echo "refusing: docker/orbstack socket missing" >&2
		exit 1
	fi
	prefix=$(resolve_prefix) || {
		echo "missing package; run: $0 provision --confirm" >&2
		exit 1
	}
	if [ ! -f "$PLIST" ] || [ ! -f "$CONFIG" ] || [ ! -f "$STATE/tls/ca.crt" ]; then
		echo "incomplete provision; run: $0 provision --confirm" >&2
		exit 1
	fi
	# Refresh plist in case the nix out-link moved.
	write_plist "$prefix"
	install_cli_mtls
	bootstrap_ours
	wait_ready "$prefix"
}

cmd_stop() {
	require_confirm "$@"
	bootout_ours
	echo "stopped ${LABEL}"
}

cmd_restart() {
	require_confirm "$@"
	cmd_stop --confirm
	cmd_start --confirm
}

main() {
	cmd=${1:-}
	shift || true
	case "$cmd" in
	status) cmd_status ;;
	provision) cmd_provision "$@" ;;
	start) cmd_start "$@" ;;
	stop) cmd_stop "$@" ;;
	restart) cmd_restart "$@" ;;
	-h | --help | "")
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 1
		;;
	esac
}

main "$@"
