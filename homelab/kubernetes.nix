{
  homelab,
  lib,
  pkgs,
}:
let
  certManagerVersion = "1.21.3";
  externalDnsVersion = "1.24.0";
  externalDnsAppVersion = "0.24.0";
  connectVersion = "2.4.3";
  traefikChartVersion = "42.4.1";
  traefikAppVersion = "3.7.19";

  certManagerSource = pkgs.fetchurl {
    url = "https://github.com/cert-manager/cert-manager/releases/download/v${certManagerVersion}/cert-manager.yaml";
    sha256 = "c04a51295adda2b1a775146751f973e787190778c7f35180861d9678876e5c74";
  };

  externalDnsChart = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-${externalDnsVersion}/external-dns-${externalDnsVersion}.tgz";
    sha256 = "ebd3e13e32fca4aabf9d07090cca8c4bf4f73bcc89e5254e5650388bdac2e34a";
  };

  connectChart = pkgs.fetchurl {
    url = "https://github.com/1Password/connect-helm-charts/releases/download/connect-${connectVersion}/connect-${connectVersion}.tgz";
    sha256 = "f3984636039b0e7087373f28fbae840a7e7842747df1fd175068e4fc52a9a93b";
  };

  # Decision D6: Traefik terminates TLS for the NetBird host. Chart 42.4.1
  # ships appVersion v3.7.19 (verified 2026-11-22 against the repo index.yaml).
  traefikChart = pkgs.fetchurl {
    url = "https://traefik.github.io/charts/traefik/traefik-${traefikChartVersion}.tgz";
    sha256 = "sha256-gOpyRrdNW80fhqxZj+ymulFqEQ3ArZ6V39oo2TO0rNs=";
  };

  certManagerImages = [
    "cert-manager-controller"
    "cert-manager-webhook"
    "cert-manager-cainjector"
    "cert-manager-acmesolver"
    "cert-manager-startupapicheck"
  ];
  certManagerDigests = with homelab.imageDigests; [
    certManagerController
    certManagerWebhook
    certManagerCainjector
    certManagerAcmesolver
    certManagerStartupapicheck
  ];
  # I1 finding (personal-platform bootstrap/orbstack/opentofu/cert-manager.tf):
  # OrbStack's internal resolver times out on _acme-challenge SOA lookups,
  # breaking the DNS-01 self-check. Force public recursive resolvers.
  dns01Resolvers = "1.1.1.1:53,8.8.8.8:53";
  solverArgLine = "          - --acme-http01-solver-image=quay.io/jetstack/cert-manager-acmesolver:v${certManagerVersion}";
  certManagerSourcePatched =
    let
      patched =
        builtins.replaceStrings
          [ solverArgLine ]
          [
            (
              solverArgLine
              + "\n          - --dns01-recursive-nameservers-only"
              + "\n          - --dns01-recursive-nameservers=${dns01Resolvers}"
            )
          ]
          (builtins.readFile certManagerSource);
    in
    if patched == builtins.readFile certManagerSource then
      throw "dev-env: cert-manager DNS-01 resolver patch anchor not found; the upstream manifest changed"
    else
      patched;
  certManager = pkgs.writeText "cert-manager.yaml" (
    builtins.replaceStrings
      (map (image: "quay.io/jetstack/${image}:v${certManagerVersion}") certManagerImages)
      (lib.zipListsWith (
        image: digest: "quay.io/jetstack/${image}@sha256:${digest}"
      ) certManagerImages certManagerDigests)
      certManagerSourcePatched
  );

  externalDnsValues = {
    image = {
      repository = "registry.k8s.io/external-dns/external-dns";
      tag = "v${externalDnsAppVersion}@sha256:${homelab.imageDigests.externalDns}";
      pullPolicy = "IfNotPresent";
    };
    replicaCount = 1;
    service.enabled = false;
    logLevel = "info";
    logFormat = "json";
    interval = "1m";
    managedRecordTypes = [
      "A"
      "AAAA"
      "CNAME"
    ];
    sources = [
      "crd"
      "service"
      "ingress"
    ];
    resources = {
      requests = {
        cpu = "50m";
        memory = "64Mi";
      };
      limits = {
        cpu = "250m";
        memory = "256Mi";
      };
    };
  };

  internalExternalDns =
    pkgs.runCommand "external-dns-internal.yaml"
      {
        nativeBuildInputs = [ pkgs.kubernetes-helm ];
      }
      ''
        helm template external-dns-internal ${externalDnsChart} \
          --namespace homelab \
          --include-crds \
          -f ${
            pkgs.writeText "external-dns-internal-values.json" (
              builtins.toJSON (
                externalDnsValues
                // {
                  provider.name = "coredns";
                  env = [
                    {
                      name = "ETCD_URLS";
                      value = "https://${homelab.lanAddress}:2379";
                    }
                  ];
                  extraArgs = [
                    "--coredns-strictly-owned"
                    "--tls-ca=/etc/external-dns/etcd/ca.crt"
                    "--tls-client-cert=/etc/external-dns/etcd/tls.crt"
                    "--tls-client-cert-key=/etc/external-dns/etcd/tls.key"
                  ];
                  txtOwnerId = "orbstack-internal";
                  annotationFilter = "dev-env/visibility=internal";
                  domainFilters = [ homelab.internalZone ];
                  policy = "sync";
                  extraVolumes = [
                    {
                      name = "etcd-tls";
                      secret.secretName = "external-dns-etcd";
                    }
                  ];
                  extraVolumeMounts = [
                    {
                      name = "etcd-tls";
                      mountPath = "/etc/external-dns/etcd";
                      readOnly = true;
                    }
                  ];
                }
              )
            )
          } > "$out"
      '';

  publicExternalDns =
    pkgs.runCommand "external-dns-cloudflare.yaml"
      {
        nativeBuildInputs = [ pkgs.kubernetes-helm ];
      }
      ''
        helm template external-dns-cloudflare ${externalDnsChart} \
          --namespace homelab \
          -f ${
            pkgs.writeText "external-dns-cloudflare-values.json" (
              builtins.toJSON (
                externalDnsValues
                // {
                  provider.name = "cloudflare";
                  env = [
                    {
                      name = "CF_API_TOKEN";
                      valueFrom.secretKeyRef = {
                        name = "cloudflare-external-dns";
                        key = "token";
                      };
                    }
                  ];
                  txtOwnerId = "orbstack-cloudflare";
                  annotationFilter = "dev-env/visibility=public";
                  domainFilters = [ homelab.cloudflare.zone ];
                  policy = "upsert-only";
                }
              )
            )
          } > "$out"
      '';

  traefik =
    pkgs.runCommand "traefik.yaml"
      {
        nativeBuildInputs = [ pkgs.kubernetes-helm ];
      }
      ''
        helm template traefik ${traefikChart} \
          --namespace traefik \
          -f ${
            pkgs.writeText "traefik-values.json" (
              builtins.toJSON {
                image = {
                  registry = "docker.io";
                  repository = "traefik";
                  tag = "v${traefikAppVersion}";
                  # The chart renders registry/repository@digest and ignores
                  # the tag when digest is set (verified 2026-11-22).
                  digest = "sha256:${homelab.imageDigests.traefik}";
                  pullPolicy = "IfNotPresent";
                };
                deployment.replicas = 1;
                updateStrategy.type = "Recreate";
                service = {
                  enabled = true;
                  single = true;
                  # Chart 42.x: the Kubernetes Service spec lives under
                  # service.spec (validated against values.schema.json).
                  # ClusterIP during bring-up per the OrbStack LoadBalancer
                  # finding in personal-platform/ztna/netbird/README.md.
                  spec = {
                    type = homelab.kubernetes.traefikServiceType;
                  }
                  // lib.optionalAttrs (homelab.kubernetes.traefikServiceType == "LoadBalancer") {
                    # Single node; preserves LAN client source IPs (I3).
                    externalTrafficPolicy = "Local";
                  };
                };
                providers.kubernetesIngress = {
                  enabled = true;
                  publishedService.enabled = true;
                };
                log.level = "INFO";
                resources = {
                  requests = {
                    cpu = "100m";
                    memory = "128Mi";
                  };
                  limits = {
                    cpu = "500m";
                    memory = "512Mi";
                  };
                };
              }
            )
          } > "$out"
        # Supply-chain gate: every rendered image must be digest-pinned.
        if grep 'image:' "$out" | grep -qv '@sha256:'; then
          echo "traefik render produced a tag-only image" >&2
          exit 1
        fi
      '';

  onePassword =
    pkgs.runCommand "onepassword-operator.yaml"
      {
        nativeBuildInputs = [ pkgs.kubernetes-helm ];
      }
      ''
        helm template onepassword ${connectChart} \
          --namespace onepassword \
          -f ${
            pkgs.writeText "onepassword-values.json" (
              builtins.toJSON {
                connect = {
                  create = false;
                  host = homelab.onePassword.connectHost;
                };
                operator = {
                  create = true;
                  authMethod = "connect";
                  autoRestart = false;
                  logLevel = "info";
                  pollingInterval = 600;
                  version = "1.12.1@sha256:${homelab.imageDigests.operator}";
                  watchNamespace = [
                    "homelab"
                    "cert-manager"
                  ]
                  ++ lib.optional homelab.runtimes.netbird "netbird";
                };
                acceptanceTests.enabled = false;
              }
            )
          } > "$out"
      '';

  pki = pkgs.writeText "openbao-issuer.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata.name = "openbao-intermediate";
          spec.vault = {
            server = "https://bao.${homelab.internalZone}:8200";
            path = "pki_int/sign/cert-manager";
            caBundleSecretRef = {
              name = "openbao-ca";
              key = "ca.crt";
            };
            auth.appRole = {
              path = "approle";
              roleId = homelab.openbao.certManagerRoleId;
              secretRef = {
                name = "openbao-cert-manager-approle";
                key = "secretId";
              };
            };
          };
        }
        {
          apiVersion = "onepassword.com/v1";
          kind = "OnePasswordItem";
          metadata = {
            name = "openbao-cert-manager-approle";
            namespace = "cert-manager";
          };
          spec.itemPath = homelab.onePassword.certManagerSecretItem;
        }
      ];
    }
  );

  cloudflareSecret = pkgs.writeText "cloudflare-secret.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "onepassword.com/v1";
          kind = "OnePasswordItem";
          metadata = {
            name = "cloudflare-external-dns";
            namespace = "homelab";
          };
          spec.itemPath = homelab.cloudflare.tokenItem;
        }
      ];
    }
  );

  # Decision D2: publicly trusted certificate for the NetBird host via ACME
  # DNS-01 through Cloudflare. The token stays a 1Password item reference; the
  # 1Password Connect operator projects it into cert-manager's namespace.
  acmeDns01Issuer = pkgs.writeText "cloudflare-dns01-issuer.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "cert-manager.io/v1";
          kind = "ClusterIssuer";
          metadata.name = "cloudflare-dns01";
          spec.acme = {
            server = homelab.cloudflare.acme.server;
            email = homelab.cloudflare.acme.email;
            privateKeySecretRef.name = "cloudflare-dns01-account-key";
            solvers = [
              {
                selector.dnsZones = [ homelab.cloudflare.zone ];
                dns01.cloudflare.apiTokenSecretRef = {
                  name = "cloudflare-acme-dns01";
                  key = "token";
                };
              }
            ];
          };
        }
        {
          apiVersion = "onepassword.com/v1";
          kind = "OnePasswordItem";
          metadata = {
            name = "cloudflare-acme-dns01";
            namespace = "cert-manager";
          };
          spec.itemPath = homelab.cloudflare.tokenItem;
        }
      ];
    }
  );

  serviceEndpoints = homelab.services ++ [
    {
      name = "openbao";
      internalName = "bao.${homelab.internalZone}";
      internalTargets = [ homelab.lanAddress ];
      publicName = null;
      publicTargets = [ ];
    }
  ];
  endpointFor =
    visibility: service:
    let
      internal = visibility == "internal";
    in
    {
      apiVersion = "externaldns.k8s.io/v1alpha1";
      kind = "DNSEndpoint";
      metadata = {
        name = "${service.name}-${visibility}";
        namespace = "homelab";
        annotations."dev-env/visibility" = visibility;
      };
      spec.endpoints = [
        {
          dnsName = if internal then service.internalName else service.publicName;
          recordType = service.recordType or "A";
          recordTTL = service.recordTTL or 60;
          targets = if internal then service.internalTargets else service.publicTargets;
        }
      ];
    };
  internalEndpoints = map (endpointFor "internal") serviceEndpoints;
  publicEndpoints = lib.filter (service: service.publicName != null) serviceEndpoints;
  endpoints = pkgs.writeText "dns-endpoints.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = internalEndpoints ++ map (endpointFor "public") publicEndpoints;
    }
  );

  netbirdServer =
    if homelab.runtimes.netbird then
      import ./netbird-server.nix { inherit homelab lib pkgs; }
    else
      null;

  namespaces = pkgs.writeText "namespaces.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items =
        map
          (name: {
            apiVersion = "v1";
            kind = "Namespace";
            metadata.name = name;
          })
          [
            "homelab"
            "onepassword"
            "traefik"
          ];
    }
  );
in
pkgs.runCommand "homelab-kubernetes" { } ''
  mkdir -p "$out"
  cp ${namespaces} "$out/00-namespaces.json"
  cp ${certManager} "$out/10-cert-manager.yaml"
  cp ${onePassword} "$out/20-onepassword-operator.yaml"
  cp ${pki} "$out/30-openbao-issuer.json"
  cp ${traefik} "$out/35-traefik.yaml"
  cp ${internalExternalDns} "$out/40-external-dns-internal.yaml"
  cp ${endpoints} "$out/50-dns-endpoints.json"
  ${lib.optionalString homelab.cloudflare.enable ''
    cp ${cloudflareSecret} "$out/25-cloudflare-secret.json"
    cp ${acmeDns01Issuer} "$out/26-cloudflare-dns01-issuer.json"
    cp ${publicExternalDns} "$out/41-external-dns-cloudflare.yaml"
  ''}
  ${lib.optionalString homelab.runtimes.netbird ''
    cp ${netbirdServer} "$out/60-netbird.json"
  ''}
''
