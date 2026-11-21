{
  config,
  homelab,
  lib,
  pkgs,
  ...
}:
let
  stateRoot = "/private/var/lib/mac-environment";
  logRoot = "/private/var/log/mac-environment";
  tlsRoot = "${stateRoot}/transport-tls";
  etcdState = "${stateRoot}/etcd";
  openbaoState = "${stateRoot}/openbao";
  yaml = pkgs.formats.yaml { };
  kubernetesManifests = import ../../homelab/kubernetes.nix {
    inherit homelab lib pkgs;
  };

  homelabState = pkgs.writeShellApplication {
    name = "homelab-state";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssl
    ];
    text = ''
      ca_key=${tlsRoot}/ca.key
      ca_crt=${tlsRoot}/ca.crt

      mkdir -p ${tlsRoot} ${etcdState} ${openbaoState} \
        ${logRoot}/etcd ${logRoot}/openbao ${logRoot}/coredns
      chmod 0755 ${tlsRoot}
      chmod 0700 ${etcdState} ${openbaoState}
      chmod 0750 ${logRoot}/etcd ${logRoot}/openbao ${logRoot}/coredns

      if [ ! -s "$ca_crt" ]; then
        test ! -e "$ca_key"
        openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
          -keyout "$ca_key" -out "$ca_crt" \
          -subj '/CN=dev-env transport bootstrap CA' \
          -addext 'basicConstraints=critical,CA:TRUE' \
          -addext 'keyUsage=critical,keyCertSign,cRLSign'
      fi
      chmod 0600 "$ca_key"
      chmod 0644 "$ca_crt"

      issue_cert() {
        name=$1
        common_name=$2
        usage=$3
        san=$4
        key=${tlsRoot}/"$name".key
        csr=${tlsRoot}/"$name".csr
        cert=${tlsRoot}/"$name".crt
        extensions=${tlsRoot}/"$name".ext

        if [ -e "$key" ] || [ -e "$cert" ]; then
          test -s "$key" && test -s "$cert"
          return
        fi

        openssl req -new -newkey rsa:3072 -nodes \
          -keyout "$key" -out "$csr" -subj "/CN=$common_name"
        printf '%s\n' \
          'basicConstraints=critical,CA:FALSE' \
          'keyUsage=critical,digitalSignature,keyEncipherment' \
          "extendedKeyUsage=$usage" \
          "subjectAltName=$san" > "$extensions"
        openssl x509 -req -days 365 \
          -in "$csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial \
          -out "$cert" -extfile "$extensions"
        chmod 0600 "$key"
        chmod 0644 "$cert"
      }

      issue_cert openbao bao.${homelab.internalZone} serverAuth \
        DNS:bao.${homelab.internalZone},IP:127.0.0.1,IP:${homelab.lanAddress}
      issue_cert etcd etcd.${homelab.internalZone} serverAuth \
        DNS:etcd.${homelab.internalZone},IP:127.0.0.1,IP:${homelab.lanAddress}
      issue_cert coredns-client coredns clientAuth DNS:coredns
      issue_cert externaldns-client externaldns clientAuth DNS:externaldns

      chown -R _etcd:_etcd ${etcdState} ${logRoot}/etcd
      chown _etcd:_etcd ${tlsRoot}/etcd.key
      chown -R _openbao:_openbao ${openbaoState} ${logRoot}/openbao
      chown _openbao:_openbao ${tlsRoot}/openbao.key
    '';
  };

  etcdConfig = yaml.generate "etcd.yaml" {
    name = "dev-env";
    data-dir = etcdState;
    listen-client-urls = "https://127.0.0.1:2379,https://${homelab.lanAddress}:2379";
    advertise-client-urls = "https://${homelab.lanAddress}:2379";
    listen-peer-urls = "http://127.0.0.1:2380";
    initial-advertise-peer-urls = "http://127.0.0.1:2380";
    initial-cluster = "dev-env=http://127.0.0.1:2380";
    initial-cluster-state = "new";
    cert-file = "${tlsRoot}/etcd.crt";
    key-file = "${tlsRoot}/etcd.key";
    trusted-ca-file = "${tlsRoot}/ca.crt";
    client-cert-auth = true;
    tls-min-version = "TLS1.2";
    log-level = "info";
  };

  openbaoConfig = pkgs.writeText "openbao.hcl" ''
    ui = true
    disable_mlock = true
    api_addr = "https://bao.${homelab.internalZone}:8200"
    log_format = "json"
    log_level = "info"

    storage "file" {
      path = "${openbaoState}/data"
    }

    listener "tcp" {
      address = "127.0.0.1:8200"
      tls_cert_file = "${tlsRoot}/openbao.crt"
      tls_key_file = "${tlsRoot}/openbao.key"
      tls_min_version = "TLS1.3"
    }

    listener "tcp" {
      address = "${homelab.lanAddress}:8200"
      tls_cert_file = "${tlsRoot}/openbao.crt"
      tls_key_file = "${tlsRoot}/openbao.key"
      tls_min_version = "TLS1.3"
    }
  '';

  corednsConfig = pkgs.writeText "Corefile" ''
    ${homelab.internalZone} {
      bind 127.0.0.1 ${homelab.lanAddress}
      errors
      etcd {
        path /skydns
        endpoint https://127.0.0.1:2379
        tls ${tlsRoot}/coredns-client.crt ${tlsRoot}/coredns-client.key ${tlsRoot}/ca.crt
      }
      cache 30
      loadbalance
    }

    . {
      bind 127.0.0.1 ${homelab.lanAddress}
      errors
      forward . 127.0.0.2 127.0.0.3
      cache 30
    }
  '';

  serviceDefaults = {
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    ProcessType = "Background";
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = homelab.enable -> homelab.lanAddress != null;
          message = "homelab.lanAddress is required when homelab.enable is true.";
        }
        {
          assertion = homelab.enable -> homelab.onePassword.enable;
          message = "The homelab integrations require the reviewed 1Password configuration.";
        }
        {
          assertion = homelab.cloudflare.enable -> homelab.cloudflare.zone != null;
          message = "Cloudflare ExternalDNS requires a public zone.";
        }
        {
          assertion = homelab.cloudflare.enable -> homelab.cloudflare.tokenItem != null;
          message = "Cloudflare ExternalDNS requires a 1Password item reference, not a token.";
        }
        {
          assertion = homelab.enable -> homelab.onePassword.connectHost != null;
          message = "A 1Password Connect host is required for the homelab.";
        }
        {
          assertion = homelab.enable -> homelab.onePassword.certManagerSecretItem != null;
          message = "The cert-manager AppRole SecretID needs a 1Password item reference.";
        }
        {
          assertion = homelab.enable -> homelab.openbao.certManagerRoleId != null;
          message = "The cert-manager OpenBao AppRole RoleID is required.";
        }
        {
          assertion =
            homelab.enable
            -> lib.all (value: value != null) [
              homelab.imageDigests.certManagerController
              homelab.imageDigests.certManagerWebhook
              homelab.imageDigests.certManagerCainjector
              homelab.imageDigests.certManagerAcmesolver
              homelab.imageDigests.certManagerStartupapicheck
              homelab.imageDigests.externalDns
              homelab.imageDigests.operator
            ];
          message = "All Kubernetes image digests must be pinned before enabling the homelab.";
        }
        {
          assertion = homelab.runtimes.netbird -> homelab.netbird.credentialsItem != null;
          message = "The NetBird server needs a 1Password item reference, not inline secrets.";
        }
        {
          assertion = homelab.runtimes.netbird -> homelab.netbird.trustedProxyCIDRs != [ ];
          message = "NetBird trustedProxyCIDRs must name the reverse-proxy CIDRs before the server is rendered.";
        }
        {
          assertion =
            homelab.runtimes.netbird
            -> homelab.imageDigests.netbirdServer != null && homelab.imageDigests.netbirdDashboard != null;
          message = "Pin netbirdServer and netbirdDashboard image digests before enabling the NetBird runtime.";
        }
      ];

      environment.systemPackages = lib.optionals homelab.enable [
        pkgs.coredns
        pkgs.etcd
        pkgs.kubectl
        pkgs.kubernetes-helm
        pkgs.openbao
      ];

    }
    (lib.mkIf homelab.enable {
      environment.etc."mac-environment/kubernetes".source = kubernetesManifests;
      users.knownGroups = [
        "_etcd"
        "_openbao"
      ];
      users.groups._etcd.gid = 790;
      users.groups._openbao.gid = 791;
      users.knownUsers = [
        "_etcd"
        "_openbao"
      ];
      users.users._etcd = {
        uid = 790;
        gid = 790;
        home = etcdState;
        description = "dev-env etcd service";
      };
      users.users._openbao = {
        uid = 791;
        gid = 791;
        home = openbaoState;
        description = "dev-env OpenBao service";
      };

      system.activationScripts.users.text = lib.mkAfter ''
        ${homelabState}/bin/homelab-state
      '';

      environment.etc."resolver/${homelab.internalZone}".text = ''
        nameserver 127.0.0.1
        nameserver ${homelab.lanAddress}
      '';

      launchd.daemons.etcd.serviceConfig = serviceDefaults // {
        Label = "dev-env.etcd";
        UserName = "_etcd";
        GroupName = "_etcd";
        ProgramArguments = [
          "${pkgs.etcd}/bin/etcd"
          "--config-file=${etcdConfig}"
        ];
        WorkingDirectory = etcdState;
        StandardOutPath = "${logRoot}/etcd/stdout.log";
        StandardErrorPath = "${logRoot}/etcd/stderr.log";
      };

      launchd.daemons.openbao.serviceConfig = serviceDefaults // {
        Label = "dev-env.openbao";
        UserName = "_openbao";
        GroupName = "_openbao";
        ProgramArguments = [
          "${pkgs.openbao}/bin/bao"
          "server"
          "-config=${openbaoConfig}"
        ];
        WorkingDirectory = openbaoState;
        StandardOutPath = "${logRoot}/openbao/stdout.log";
        StandardErrorPath = "${logRoot}/openbao/stderr.log";
      };

      launchd.daemons.coredns.serviceConfig = serviceDefaults // {
        Label = "dev-env.coredns";
        UserName = "root";
        ProgramArguments = [
          "${pkgs.coredns}/bin/coredns"
          "-conf=${corednsConfig}"
        ];
        WorkingDirectory = stateRoot;
        StandardOutPath = "${logRoot}/coredns/stdout.log";
        StandardErrorPath = "${logRoot}/coredns/stderr.log";
      };
    })
  ];
}
