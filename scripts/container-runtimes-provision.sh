#!/bin/sh
# Provision / start / stop OrbStack, Podman machine, Podman Desktop, Colima.
# Desired state matches home/container-runtimes.nix. Flake packages; no Homebrew.
# Operator-owned. Mutating verbs require --confirm.
#
# Usage:
#   sh scripts/container-runtimes-provision.sh status
#   sh scripts/container-runtimes-provision.sh provision --confirm
#   sh scripts/container-runtimes-provision.sh start [--only orbstack|podman|colima] --confirm
#   sh scripts/container-runtimes-provision.sh stop [--only ...] --confirm
#   sh scripts/container-runtimes-provision.sh restart --confirm
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MACHINE="podman-machine-default"
PROJECT_MOUNT="${MAC_ENV_PROJECT_MOUNT:-$HOME/Git}"
COLIMA_PROFILE="incus"
COLIMA_DIR="$HOME/.colima/${COLIMA_PROFILE}"
COLIMA_CFG="$COLIMA_DIR/colima.yaml"
CONTAINERS_CONF="$HOME/.config/containers/containers.conf"
STATE="${MAC_ENV_RUNTIMES_STATE:-$HOME/.local/state/mac-environment/container-runtimes}"

# Declared ceilings (must match home/container-runtimes.nix).
ORB_CPU=4
ORB_MEM_MIB=8192
PODMAN_CPUS=2
PODMAN_MEM=4096
PODMAN_DISK=60
COLIMA_CPU=2
COLIMA_MEM=4
COLIMA_DISK=60

usage() {
	printf '%s\n' \
		"Usage: $0 <status|provision|start|stop|restart> [--only NAME] [--confirm]" \
		"  status      Read-only probes (Nix paths only)" \
		"  provision   nix build flake packages + write configs (needs --confirm)" \
		"  start       Headless CLI: orb / podman machine / colima (needs --confirm)" \
		"  stop        Stop/kill those runtimes (needs --confirm)" \
		"  restart     stop then start (needs --confirm)" \
		"  --only      orbstack | podman | colima" \
		"" \
		"Nix only. Homebrew Cellar/Caskroom binaries are refused." \
		"Podman Desktop is a GUI and is not started by this script." \
		"" \
		"Headless (upstream):" \
		"  OrbStack:  orb start; setup.use_admin=false (never open .app)" \
		"  Podman:    --update-connection=false (no TTY prompt)" \
		"  Colima:    flags only; never --edit"
}

require_confirm() {
	case " $* " in
	*" --confirm "*) return 0 ;;
	*)
		echo "refusing: pass --confirm for mutating action" >&2
		exit 2
		;;
	esac
}

only_filter() {
	ONLY=""
	prev=""
	for a in "$@"; do
		if [ "$prev" = "--only" ]; then
			ONLY=$a
		fi
		prev=$a
	done
	printf '%s' "$ONLY"
}

want() {
	name=$1
	only=$2
	if [ -z "$only" ] || [ "$only" = "$name" ]; then
		return 0
	fi
	return 1
}

have_nix() {
	command -v nix >/dev/null 2>&1
}

is_nix_path() {
	path=$1
	case "$path" in
	/nix/store/* | "$HOME/.nix-profile/"* | /run/current-system/sw/* | "$ROOT"/result-*)
		return 0
		;;
	esac
	# Symlinks OrbStack drops in /usr/local/bin often point into the Nix store.
	if [ -L "$path" ]; then
		real=$(readlink "$path" 2>/dev/null || true)
		case "$real" in
		/nix/store/*) return 0 ;;
		esac
	fi
	return 1
}

resolve_bin() {
	# resolve_bin <flake-attr-or-empty> <binary-name> — Nix only.
	attr=$1
	name=$2
	if [ -n "$attr" ] && [ -x "$ROOT/result-${attr}/bin/${name}" ]; then
		printf '%s' "$ROOT/result-${attr}/bin/${name}"
		return 0
	fi
	if [ -x "$HOME/.nix-profile/bin/$name" ]; then
		printf '%s' "$HOME/.nix-profile/bin/$name"
		return 0
	fi
	if command -v "$name" >/dev/null 2>&1; then
		bin=$(command -v "$name")
		case "$bin" in
		/opt/homebrew/* | /usr/local/Cellar/* | /home/linuxbrew/*)
			echo "refusing Homebrew binary: $bin (use nix build .#$attr)" >&2
			return 1
			;;
		esac
		if is_nix_path "$bin"; then
			printf '%s' "$bin"
			return 0
		fi
		echo "refusing non-Nix binary: $bin" >&2
		return 1
	fi
	return 1
}

build_packages() {
	echo "== nix build container runtime packages =="
	if ! have_nix; then
		echo "nix missing" >&2
		exit 1
	fi
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-orbstack" "$ROOT#orbstack"
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-podman" "$ROOT#podman"
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-podman-desktop" "$ROOT#podman-desktop"
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-colima" "$ROOT#colima"
	DEVENV_USER="${DEVENV_USER:-$USER}" nix build --impure \
		--out-link "$ROOT/result-incus-client" "$ROOT#incus-client"
}

write_containers_conf() {
	podman_bin=$(resolve_bin podman podman) || {
		echo "podman binary missing; run provision after nix build" >&2
		exit 1
	}
	prefix=$(CDPATH= cd -- "$(dirname "$podman_bin")/.." && pwd)
	helper="$prefix/libexec/podman"
	mkdir -p "$(dirname "$CONTAINERS_CONF")"
	cat >"$CONTAINERS_CONF" <<EOF
[machine]
cpus=${PODMAN_CPUS}
memory=${PODMAN_MEM}
disk_size=${PODMAN_DISK}
volumes=["${PROJECT_MOUNT}:${PROJECT_MOUNT}"]

[engine]
helper_binaries_dir=["${helper}"]
EOF
	chmod 0644 "$CONTAINERS_CONF"
	echo "wrote $CONTAINERS_CONF"
}

write_colima_yaml() {
	mkdir -p "$COLIMA_DIR"
	if [ -e "$COLIMA_CFG" ]; then
		echo "colima config exists (not overwritten): $COLIMA_CFG"
		return 0
	fi
	cat >"$COLIMA_CFG" <<EOF
cpu: ${COLIMA_CPU}
memory: ${COLIMA_MEM}
disk: ${COLIMA_DISK}
arch: host
runtime: incus
kubernetes:
  enabled: false
autoActivate: true
network:
  address: false
  mode: shared
forwardAgent: false
vmType: vz
mountType: virtiofs
sshConfig: false
mounts:
  - location: ${PROJECT_MOUNT}
    writable: true
EOF
	chmod 0644 "$COLIMA_CFG"
	echo "wrote $COLIMA_CFG"
}

check_colima_value() {
	yq_bin=$1
	path=$2
	expected=$3
	actual=$("$yq_bin" -r "$path" "$COLIMA_CFG")
	if [ "$actual" != "$expected" ]; then
		echo "Colima $path differs: $actual != $expected" >&2
		return 1
	fi
	return 0
}

verify_colima_cfg() {
	yq_bin=$(resolve_bin "" yq) || yq_bin=$(resolve_bin "" yq-go) || {
		echo "yq missing; skip colima config verify" >&2
		return 0
	}
	check_colima_value "$yq_bin" .cpu "$COLIMA_CPU"
	check_colima_value "$yq_bin" .memory "$COLIMA_MEM"
	check_colima_value "$yq_bin" .disk "$COLIMA_DISK"
	check_colima_value "$yq_bin" .runtime incus
	check_colima_value "$yq_bin" .kubernetes.enabled false
	check_colima_value "$yq_bin" .network.address false
	check_colima_value "$yq_bin" .forwardAgent false
	check_colima_value "$yq_bin" .vmType vz
	check_colima_value "$yq_bin" .mountType virtiofs
	check_colima_value "$yq_bin" .sshConfig false
	check_colima_value "$yq_bin" ".mounts | length" 1
	check_colima_value "$yq_bin" ".mounts[0].location" "$PROJECT_MOUNT"
	check_colima_value "$yq_bin" ".mounts[0].writable" true
}

reconcile_orb() {
	orb_bin=$1
	key=$2
	desired=$3
	current=$("$orb_bin" config get "$key")
	if [ "$current" != "$desired" ]; then
		echo "orb config set $key=$desired (was $current)"
		"$orb_bin" config set "$key" "$desired"
	fi
}

provision_orb_config() {
	orb_bin=$(resolve_bin orbstack orb) || orb_bin=$(resolve_bin "" orbctl) || {
		echo "orb/orbctl missing" >&2
		exit 1
	}
	# orb and orbctl share subcommands for config.
	# docs.orbstack.dev/headless: disable admin permission prompts for CI/CLI.
	reconcile_orb "$orb_bin" setup.use_admin false
	reconcile_orb "$orb_bin" app.start_at_login false
	reconcile_orb "$orb_bin" docker.expose_ports_to_lan false
	reconcile_orb "$orb_bin" machines.expose_ports_to_lan false
	reconcile_orb "$orb_bin" cpu "$ORB_CPU"
	reconcile_orb "$orb_bin" memory_mib "$ORB_MEM_MIB"
	reconcile_orb "$orb_bin" ssh.expose_port false
	reconcile_orb "$orb_bin" k8s.expose_services false
	reconcile_orb "$orb_bin" docker.set_context true
}

ensure_podman_machine() {
	podman_bin=$(resolve_bin podman podman) || {
		echo "podman missing" >&2
		exit 1
	}
	jq_bin=$(resolve_bin "" jq) || {
		echo "jq missing" >&2
		exit 1
	}
	if ! "$podman_bin" machine inspect "$MACHINE" >/dev/null 2>&1; then
		echo "== podman machine init $MACHINE =="
		"$podman_bin" machine init \
			--cpus "$PODMAN_CPUS" \
			--memory "$PODMAN_MEM" \
			--disk-size "$PODMAN_DISK" \
			--provider libkrun \
			--volume "${PROJECT_MOUNT}:${PROJECT_MOUNT}" \
			"$MACHINE"
	fi
	resources=$("$podman_bin" machine inspect --format '{{json .Resources}}' "$MACHINE")
	if ! printf '%s' "$resources" | "$jq_bin" -e \
		".CPUs == ${PODMAN_CPUS} and .Memory == ${PODMAN_MEM} and .DiskSize == ${PODMAN_DISK}" >/dev/null; then
		echo "Podman machine $MACHINE differs from declared resources; refusing to recreate" >&2
		echo "$resources" >&2
		exit 1
	fi
	if [ "$("$podman_bin" machine inspect --format '{{.Rootful}}' "$MACHINE")" != "false" ]; then
		echo "Podman machine $MACHINE must remain rootless" >&2
		exit 1
	fi
}

cmd_status() {
	mkdir -p "$STATE"
	echo "== nix binaries =="
	for pair in "orbstack:orbctl" "orbstack:orb" "podman:podman" "colima:colima"; do
		attr=${pair%%:*}
		name=${pair#*:}
		if bin=$(resolve_bin "$attr" "$name" 2>/dev/null); then
			echo "$name=$bin"
		else
			echo "$name=missing-nix"
		fi
	done
	echo "== PATH conflicts (informational) =="
	for n in orb orbctl podman colima; do
		if command -v "$n" >/dev/null 2>&1; then
			p=$(command -v "$n")
			if is_nix_path "$p"; then
				echo "ok  $n -> $p"
			else
				echo "BAD $n -> $p (not Nix; refused by start/provision)"
			fi
		fi
	done
	echo "== orbstack =="
	if orb_bin=$(resolve_orbctl 2>/dev/null); then
		"$orb_bin" status 2>&1 || true
		if [ -S "$HOME/.orbstack/run/docker.sock" ]; then
			echo "docker.sock=ok $HOME/.orbstack/run/docker.sock"
		else
			echo "docker.sock=missing"
		fi
	else
		echo "orbctl missing (nix)"
	fi
	echo "== podman machine =="
	if podman_bin=$(resolve_bin podman podman 2>/dev/null); then
		"$podman_bin" machine list 2>&1 || true
	else
		echo "podman missing (nix)"
	fi
	echo "== colima =="
	if colima_bin=$(resolve_bin colima colima 2>/dev/null); then
		"$colima_bin" list 2>&1 || true
	else
		echo "colima missing (nix)"
	fi
	echo "== configs =="
	[ -f "$CONTAINERS_CONF" ] && echo "present $CONTAINERS_CONF" || echo "absent $CONTAINERS_CONF"
	[ -f "$COLIMA_CFG" ] && echo "present $COLIMA_CFG" || echo "absent $COLIMA_CFG"
}

cmd_provision() {
	require_confirm "$@"
	mkdir -p "$STATE" "$PROJECT_MOUNT"
	build_packages
	write_containers_conf
	write_colima_yaml
	verify_colima_cfg
	# Orb config needs OrbStack app present; start briefly if needed.
	if ! orbctl status >/dev/null 2>&1; then
		echo "== starting OrbStack to apply config =="
		start_orbstack
		sleep 2
	fi
	provision_orb_config
	ensure_podman_machine
	echo "provisioned. next: $0 start --confirm"
}

resolve_orbctl() {
	resolve_bin orbstack orbctl || resolve_bin "" orbctl || resolve_bin "" orb
}

start_orbstack() {
	# https://docs.orbstack.dev/headless — CLI only; do not open OrbStack.app.
	orb_bin=$(resolve_orbctl) || {
		echo "orb/orbctl missing; run provision first" >&2
		return 1
	}
	# Apply headless config before start when already reachable.
	if "$orb_bin" status >/dev/null 2>&1; then
		provision_orb_config 2>/dev/null || true
	fi
	echo "== orb start (headless) =="
	# Bare `orb` / `orb start` starts the engine without requiring the GUI.
	case "$(basename "$orb_bin")" in
	orb) "$orb_bin" start || "$orb_bin" ;;
	*) "$orb_bin" start ;;
	esac
	i=0
	while [ "$i" -lt 60 ]; do
		if "$orb_bin" status 2>/dev/null | grep -qi running; then
			provision_orb_config
			echo "OrbStack running (CLI)"
			return 0
		fi
		if [ -S "$HOME/.orbstack/run/docker.sock" ]; then
			provision_orb_config
			echo "OrbStack docker.sock present"
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	echo "OrbStack did not become ready in 60s (CLI)" >&2
	return 1
}

start_podman() {
	podman_bin=$(resolve_bin podman podman) || {
		echo "podman missing" >&2
		return 1
	}
	ensure_podman_machine
	state=$("$podman_bin" machine inspect --format '{{.State}}' "$MACHINE")
	if [ "$state" != "running" ]; then
		echo "== podman machine start $MACHINE (no prompt) =="
		# docs.podman.io: --update-connection=false disables the TTY prompt.
		"$podman_bin" machine start \
			--update-connection=false \
			--quiet \
			"$MACHINE"
	else
		echo "podman machine already running"
	fi
}

start_colima() {
	colima_bin=$(resolve_bin colima colima) || {
		echo "colima missing" >&2
		return 1
	}
	export PATH="${PATH}:$ROOT/result-incus-client/bin:$HOME/.nix-profile/bin:/usr/bin:/bin"
	if "$colima_bin" status "$COLIMA_PROFILE" >/dev/null 2>&1; then
		echo "colima $COLIMA_PROFILE already running"
		return 0
	fi
	# github.com/abiosoft/colima automation.md: lifecycle is non-interactive
	# except destructive ops. Never pass --edit.
	echo "== colima start $COLIMA_PROFILE (CLI flags) =="
	if [ -f "$COLIMA_CFG" ]; then
		verify_colima_cfg
		"$colima_bin" start "$COLIMA_PROFILE" --runtime incus
	else
		"$colima_bin" start "$COLIMA_PROFILE" \
			--runtime incus \
			--cpu "$COLIMA_CPU" \
			--memory "$COLIMA_MEM" \
			--disk "$COLIMA_DISK" \
			--vm-type vz \
			--mount-type virtiofs \
			--ssh-config=false \
			--network-address=false \
			--mount "${PROJECT_MOUNT}:w"
	fi
}

cmd_start() {
	require_confirm "$@"
	only=$(only_filter "$@")
	case "$only" in
	podman-desktop)
		echo "refusing: Podman Desktop is GUI-only (EPIPE if launched headless)" >&2
		exit 2
		;;
	esac
	want orbstack "$only" && start_orbstack
	want podman "$only" && start_podman
	want colima "$only" && start_colima
	cmd_status
}

stop_orbstack() {
	echo "== stop OrbStack =="
	if command -v orbctl >/dev/null 2>&1; then
		orbctl stop -f 2>/dev/null || orbctl stop 2>/dev/null || true
	fi
	# Quit app bundle if still alive.
	osascript -e 'tell application "OrbStack" to quit' >/dev/null 2>&1 || true
	pkill -f '/Applications/OrbStack.app' 2>/dev/null || true
	pkill -f 'OrbStack Helper' 2>/dev/null || true
}

stop_podman() {
	echo "== stop podman machine =="
	if command -v podman >/dev/null 2>&1; then
		podman machine stop "$MACHINE" 2>/dev/null || true
	fi
	pkill -f "podman machine" 2>/dev/null || true
	pkill -f 'gvproxy' 2>/dev/null || true
	pkill -f 'krunkit' 2>/dev/null || true
}

stop_colima() {
	echo "== stop colima =="
	if command -v colima >/dev/null 2>&1; then
		colima stop "$COLIMA_PROFILE" 2>/dev/null || colima stop 2>/dev/null || true
	fi
	pkill -f 'colima' 2>/dev/null || true
}

stop_podman_desktop() {
	echo "== stop Podman Desktop =="
	osascript -e 'tell application "Podman Desktop" to quit' >/dev/null 2>&1 || true
	pkill -f 'Podman Desktop' 2>/dev/null || true
}

cmd_stop() {
	require_confirm "$@"
	only=$(only_filter "$@")
	# Always reap any stray Desktop process left from earlier mistakes.
	stop_podman_desktop
	want colima "$only" && stop_colima
	want podman "$only" && stop_podman
	want orbstack "$only" && stop_orbstack
	cmd_status
}

cmd_restart() {
	require_confirm "$@"
	cmd_stop --confirm "$@"
	cmd_start --confirm "$@"
}

main() {
	cmd=${1:-}
	[ -n "$cmd" ] && shift || true
	case "$cmd" in
	status) cmd_status ;;
	provision) cmd_provision "$@" ;;
	start) cmd_start "$@" ;;
	stop) cmd_stop "$@" ;;
	restart) cmd_restart "$@" ;;
	brew-purge)
		echo "removed: this script is Nix-only. Do not call brew from here." >&2
		exit 2
		;;
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
