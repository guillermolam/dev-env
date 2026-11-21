{
  config,
  homelab,
  lib,
  pkgs,
  ...
}:
let
  orb = lib.getExe' pkgs.orbstack "orb";
  podman = lib.getExe pkgs.podman;
  colima = lib.getExe pkgs.colima;
  jq = lib.getExe pkgs.jq;
  yq = lib.getExe pkgs.yq-go;
  machine = "podman-machine-default";
  projectMount = "${config.home.homeDirectory}/Git";
  colimaConfig = pkgs.writeText "colima-incus.yaml" ''
    cpu: 2
    memory: 4
    disk: 60
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
      - location: ${projectMount}
        writable: true
  '';
in
{
  home.packages =
    lib.optionals homelab.runtimes.orbstack [ pkgs.orbstack ]
    ++ lib.optionals homelab.runtimes.podman [
      pkgs.podman
      pkgs.podman-desktop
    ]
    ++ lib.optionals homelab.runtimes.colima [
      pkgs.colima
      pkgs.incus.client
    ];

  assertions = [
    {
      assertion =
        homelab.netbird.managementUrl == null || lib.hasPrefix "https://" homelab.netbird.managementUrl;
      message = "NetBird self-hosted managementUrl must use HTTPS.";
    }
  ];

  home.file = lib.mkIf homelab.runtimes.podman {
    ".config/containers/containers.conf".text = ''
      [machine]
      cpus=2
      memory=4096
      disk_size=60
      volumes=["${projectMount}:${projectMount}"]

      [engine]
      helper_binaries_dir=["${pkgs.podman}/libexec/podman"]
    '';
  };

  home.activation.orbstackRuntime = lib.mkIf homelab.runtimes.orbstack (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      reconcile_orb() {
        key=$1
        desired=$2
        current=$(${orb} config get "$key")
        if [ "$current" != "$desired" ]; then
          ${orb} config set "$key" "$desired"
        fi
      }
      reconcile_orb docker.expose_ports_to_lan false
      reconcile_orb machines.expose_ports_to_lan false
      reconcile_orb cpu 4
      reconcile_orb memory_mib 8192
      reconcile_orb ssh.expose_port false
      reconcile_orb k8s.expose_services false
      reconcile_orb docker.set_context true
    ''
  );

  home.activation.podmanRuntime = lib.mkIf homelab.runtimes.podman (
    lib.hm.dag.entryAfter [ "orbstackRuntime" ] ''
      set -eu
      if ! ${podman} machine inspect ${machine} >/dev/null 2>&1; then
        ${podman} machine init \
          --cpus 2 \
          --memory 4096 \
          --disk-size 60 \
          --provider libkrun \
          --volume ${projectMount}:${projectMount} \
          ${machine}
      fi
      resources=$(${podman} machine inspect --format '{{json .Resources}}' ${machine})
      if ! printf '%s' "$resources" | ${jq} -e '.CPUs == 2 and .Memory == 4096 and .DiskSize == 60' >/dev/null; then
        echo "Podman machine ${machine} differs from declared resources; refusing to recreate it" >&2
        exit 1
      fi
      if [ "$(${podman} machine inspect --format '{{.Rootful}}' ${machine})" != "false" ]; then
        echo "Podman machine ${machine} must remain rootless" >&2
        exit 1
      fi
      if [ "$(${podman} machine inspect --format '{{.State}}' ${machine})" != "running" ]; then
        ${podman} machine start --update-connection=true ${machine}
      fi
    ''
  );

  home.activation.colimaRuntime = lib.mkIf homelab.runtimes.colima (
    lib.hm.dag.entryAfter [ "podmanRuntime" ] ''
      set -eu
      export PATH="$PATH:${pkgs.incus.client}/bin:/usr/bin:/bin"
      config="$HOME/.colima/incus/colima.yaml"
      mkdir -p "$HOME/.colima/incus"
      if [ ! -e "$config" ]; then
        install -m 0644 ${colimaConfig} "$config"
      fi
      check_colima_value() {
        path=$1
        expected=$2
        actual=$(${yq} -r "$path" "$config")
        if [ "$actual" != "$expected" ]; then
          echo "Colima $path differs: $actual != $expected" >&2
          exit 1
        fi
      }
      check_colima_value .cpu 2
      check_colima_value .memory 4
      check_colima_value .disk 60
      check_colima_value .runtime incus
      check_colima_value .kubernetes.enabled false
      check_colima_value .network.address false
      check_colima_value .forwardAgent false
      check_colima_value .vmType vz
      check_colima_value .mountType virtiofs
      check_colima_value .sshConfig false
      check_colima_value ".mounts | length" 1
      check_colima_value ".mounts[0].location" ${projectMount}
      check_colima_value ".mounts[0].writable" true
      if ! ${colima} status incus >/dev/null 2>&1; then
        ${colima} start incus --runtime incus
      fi
    ''
  );

  home.activation.netbirdSelfHosted =
    lib.mkIf (homelab.runtimes.netbird && homelab.netbird.managementUrl != null)
      (
        lib.hm.dag.entryAfter [ "colimaRuntime" ] ''
          if [ -x /usr/local/bin/netbird ]; then
            /usr/local/bin/netbird up --management-url ${lib.escapeShellArg homelab.netbird.managementUrl}
          else
            echo "NetBird is installed by system activation; open NetBird.app and sign in after this switch" >&2
          fi
        ''
      );
}
