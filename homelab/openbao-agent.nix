{
  config,
  homelab,
  lib,
  pkgs,
  ...
}:
let
  agentState = "${config.home.homeDirectory}/.local/state/openbao-agent";
  agentLogs = "${config.home.homeDirectory}/Library/Logs/openbao-agent";
  transportCa = "/private/var/lib/mac-environment/transport-tls/ca.crt";
  templateFor =
    kind: certificate:
    pkgs.writeText "${certificate.name}-${kind}.ctmpl" ''
      {{ with secret "pki_int/issue/${certificate.role}" "common_name=${certificate.commonName}" }}{{ if eq "${kind}" "certificate" }}{{ .Data.certificate }}{{ else }}{{ .Data.private_key }}{{ end }}{{ end }}
    '';
  certificateFiles = lib.listToAttrs (
    lib.concatMap (certificate: [
      {
        name = "openbao-agent/${certificate.name}-certificate.ctmpl";
        value.source = templateFor "certificate" certificate;
      }
      {
        name = "openbao-agent/${certificate.name}-key.ctmpl";
        value.source = templateFor "private_key" certificate;
      }
    ]) homelab.nativeCertificates
  );
  templateBlocks = lib.concatMapStrings (certificate: ''
    template {
      source = "${config.home.homeDirectory}/.config/openbao-agent/${certificate.name}-certificate.ctmpl"
      destination = "${certificate.destination}.crt"
      perms = "0644"
    }
    template {
      source = "${config.home.homeDirectory}/.config/openbao-agent/${certificate.name}-key.ctmpl"
      destination = "${certificate.destination}.key"
      perms = "0600"
    }
  '') homelab.nativeCertificates;
  agentConfig = pkgs.writeText "openbao-agent.hcl" ''
    vault {
      address = "https://bao.${homelab.internalZone}:8200"
      ca_cert = "${transportCa}"
    }

    auto_auth {
      method "approle" {
        config = {
          role_id_file_path = "${agentState}/role-id"
          secret_id_file_path = "${agentState}/secret-id"
        }
      }
      sink "file" {
        config = {
          path = "${agentState}/token"
          mode = 0600
        }
      }
    }

    ${templateBlocks}
  '';
in
{
  config = lib.mkIf (homelab.nativeCertificates != [ ]) {
    assertions = [
      {
        assertion = homelab.enable && homelab.openbao.nativeRoleId != null;
        message = "Native OpenBao certificates require homelab.enable and openbao.nativeRoleId.";
      }
      {
        assertion = lib.all (
          certificate: lib.hasPrefix "${config.home.homeDirectory}/Git/" certificate.destination
        ) homelab.nativeCertificates;
        message = "Native certificate destinations must stay under ~/Git.";
      }
    ];

    home.file = certificateFiles // {
      "openbao-agent/agent.hcl".source = agentConfig;
    };

    home.activation.openbaoAgentState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${agentState} ${agentLogs}
      chmod 0700 ${agentState}
    '';

    launchd.agents.openbao-agent.serviceConfig = {
      Label = "dev-env.openbao-agent";
      ProgramArguments = [
        "${pkgs.openbao}/bin/bao"
        "agent"
        "-config=${config.home.homeDirectory}/.config/openbao-agent/agent.hcl"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "${agentLogs}/stdout.log";
      StandardErrorPath = "${agentLogs}/stderr.log";
    };
  };
}
