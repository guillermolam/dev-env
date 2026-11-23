# Declares OpenShell CLI + user LaunchAgent. Activation is operator-only
# (home-manager / darwin-rebuild). Immediate start uses scripts/openshell-provision.sh.
{
  config,
  homelab,
  lib,
  pkgs,
  ...
}:
let
  openshell = pkgs.openshell;
  stateDir = "${config.home.homeDirectory}/.local/state/mac-environment/openshell";
  configDir = "${config.home.homeDirectory}/.config/mac-environment/openshell";
  label = "sh.mac-environment.openshell-gateway";
in
{
  config = lib.mkIf (homelab.runtimes.openshell or false) {
    home.packages = [ openshell ];

    # Materialize expected dirs; certs and gateway.toml come from provision script.
    home.activation.openshellDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      mkdir -p ${lib.escapeShellArg stateDir}/logs \
        ${lib.escapeShellArg stateDir}/gateway \
        ${lib.escapeShellArg stateDir}/vm-driver \
        ${lib.escapeShellArg configDir}
      chmod 700 ${lib.escapeShellArg stateDir} ${lib.escapeShellArg configDir}
    '';

    launchd.agents.openshell-gateway = {
      enable = true;
      config = {
        Label = label;
        ProgramArguments = [ "${openshell}/libexec/openshell-gateway-service" ];
        EnvironmentVariables = {
          HOME = config.home.homeDirectory;
          MAC_ENV_OPENSHELL_STATE = stateDir;
          MAC_ENV_OPENSHELL_CONFIG = "${configDir}/gateway.toml";
          OPENSHELL_COMPUTE_DRIVER = "docker";
          # Prefer OrbStack when present; docker CLI default still works via /var/run.
          DOCKER_HOST = "unix://${config.home.homeDirectory}/.orbstack/run/docker.sock";
        };
        # Always restart. Explicit docker driver keeps the process up through
        # transient engine flaps (unlike auto-detect exit).
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 10;
        StandardOutPath = "${stateDir}/logs/openshell-gateway.out.log";
        StandardErrorPath = "${stateDir}/logs/openshell-gateway.err.log";
        ProcessType = "Background";
      };
    };
  };
}
