# Combined NetBird server for the homelab cluster.
#
# Checked against netbirdio/netbird v0.83.1, not the stuck draft:
# - infrastructure_files/getting-started.sh listens on :80 behind the proxy,
#   exposes STUN on UDP 3478, and points Traefik at dashboard port 80.
# - combined/config.yaml.example is the config schema.
# - Docs updated 2026-11-20 still describe netbirdio/netbird-server and
#   netbirdio/dashboard. They do not publish dashboard:v2.96.0-rootless.
# - Decision D6 (2026-11-22): Traefik is the ingress controller. It is
#   rendered by homelab/kubernetes.nix from chart 42.4.1 (appVersion v3.7.19,
#   digest-pinned), which resolves the v3.7.14/v3.7.18/v3.7.19 discrepancy
#   between the NetBird script and docs.
# - Docker Hub tag netbird-server:0.83.1 has index digest
#   sha256:f6acc1a6dcb48d10b867ec7e6916c62ef5c8dc2bb198aec9cc637b2dd26c06c9.
#   A later 0.83.2 tag exists; it is not used, because the macOS client pin is
#   0.83.1. The operator still supplies that digest in homelab.imageDigests.
{
  homelab,
  lib,
  pkgs,
}:
let
  url = homelab.netbird.managementUrl;
  require =
    name: value:
    if value == null || value == "" then
      throw "dev-env: ${name} is required to render the NetBird server"
    else
      value;
  managementUrl = require "homelab.netbird.managementUrl" url;
  credentialsItem = require "homelab.netbird.credentialsItem" homelab.netbird.credentialsItem;
  serverDigest = require "homelab.imageDigests.netbirdServer" homelab.imageDigests.netbirdServer;
  dashboardDigest = require "homelab.imageDigests.netbirdDashboard" homelab.imageDigests.netbirdDashboard;
  trustedProxyCIDRs = homelab.netbird.trustedProxyCIDRs or [ ];
  hostPort = lib.head (lib.splitString "/" (lib.removePrefix "https://" managementUrl));
  host = lib.head (lib.splitString ":" hostPort);
  exposedAddress = if lib.hasInfix ":" hostPort then managementUrl else "${managementUrl}:443";
  yaml = pkgs.formats.yaml { };
  serverConfig = yaml.generate "netbird-config.yaml" {
    server = {
      listenAddress = ":80";
      exposedAddress = exposedAddress;
      stunPorts = [ 3478 ];
      metricsPort = 9090;
      healthcheckAddress = ":9000";
      logLevel = "info";
      logFile = "console";
      disableAnonymousMetrics = true;
      disableGeoliteUpdate = true;
      dataDir = "/var/lib/netbird";
      auth = {
        issuer = "${managementUrl}/oauth2";
        localAuthDisabled = false;
        signKeyRefreshEnabled = true;
        dashboardRedirectURIs = [
          "${managementUrl}/nb-auth"
          "${managementUrl}/nb-silent-auth"
        ];
        dashboardPostLogoutRedirectURIs = [ "${managementUrl}/" ];
        cliRedirectURIs = [ "http://localhost:53000/" ];
      };
      store.engine = "sqlite";
      reverseProxy.trustedHTTPProxies =
        if trustedProxyCIDRs == [ ] then
          throw "dev-env: homelab.netbird.trustedProxyCIDRs must list the proxy CIDRs; an empty list would trust forwarded client IPs from any source"
        else
          trustedProxyCIDRs;
    };
  };
  secretEnv = name: key: {
    inherit name;
    valueFrom.secretKeyRef = {
      name = "netbird-credentials";
      inherit key;
    };
  };
in
pkgs.writeText "netbird.json" (
  builtins.toJSON {
    apiVersion = "v1";
    kind = "List";
    items = [
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata.name = "netbird";
      }
      {
        apiVersion = "onepassword.com/v1";
        kind = "OnePasswordItem";
        metadata = {
          name = "netbird-credentials";
          namespace = "netbird";
        };
        spec.itemPath = credentialsItem;
      }
      {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "netbird-data";
          namespace = "netbird";
        };
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "1Gi";
        };
      }
      {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "netbird-config";
          namespace = "netbird";
        };
        data."config.yaml" = builtins.readFile serverConfig;
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "netbird-server";
          namespace = "netbird";
        };
        spec = {
          replicas = 1;
          strategy.type = "Recreate";
          selector.matchLabels."app.kubernetes.io/name" = "netbird-server";
          template = {
            metadata.labels."app.kubernetes.io/name" = "netbird-server";
            spec.containers = [
              {
                name = "netbird-server";
                image = "netbirdio/netbird-server@sha256:${serverDigest}";
                imagePullPolicy = "IfNotPresent";
                args = [
                  "--config"
                  "/etc/netbird/config.yaml"
                ];
                ports = [
                  {
                    name = "http";
                    containerPort = 80;
                  }
                  {
                    name = "metrics";
                    containerPort = 9090;
                  }
                  {
                    name = "health";
                    containerPort = 9000;
                  }
                  {
                    name = "stun";
                    containerPort = 3478;
                    protocol = "UDP";
                    hostPort = 3478;
                  }
                ];
                env = [
                  (secretEnv "NB_AUTH_SECRET" "relay-auth-secret")
                  (secretEnv "NB_STORE_ENCRYPTION_KEY" "datastore-encryption-key")
                  (secretEnv "NB_IDP_SESSION_COOKIE_ENCRYPTION_KEY" "idp-session-cookie-encryption-key")
                ];
                # Relay /health dials the advertised URL through ingress.
                # The ingress needs a ready backend before that check can succeed.
                readinessProbe = {
                  httpGet = {
                    path = "/oauth2/.well-known/openid-configuration";
                    port = "http";
                  };
                  initialDelaySeconds = 5;
                  periodSeconds = 5;
                };
                livenessProbe = {
                  httpGet = {
                    path = "/oauth2/.well-known/openid-configuration";
                    port = "http";
                  };
                  initialDelaySeconds = 15;
                  periodSeconds = 10;
                };
                volumeMounts = [
                  {
                    name = "config";
                    mountPath = "/etc/netbird/config.yaml";
                    subPath = "config.yaml";
                    readOnly = true;
                  }
                  {
                    name = "data";
                    mountPath = "/var/lib/netbird";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "config";
                configMap.name = "netbird-config";
              }
              {
                name = "data";
                persistentVolumeClaim.claimName = "netbird-data";
              }
            ];
          };
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "netbird-server";
          namespace = "netbird";
        };
        spec = {
          selector."app.kubernetes.io/name" = "netbird-server";
          ports = [
            {
              name = "http";
              port = 80;
              targetPort = 80;
              appProtocol = "kubernetes.io/h2c";
            }
          ];
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "netbird-stun";
          namespace = "netbird";
        };
        spec = {
          type = "LoadBalancer";
          externalTrafficPolicy = "Local";
          selector."app.kubernetes.io/name" = "netbird-server";
          ports = [
            {
              name = "stun";
              protocol = "UDP";
              port = 3478;
              targetPort = 3478;
            }
          ];
        };
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "netbird-dashboard";
          namespace = "netbird";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "netbird-dashboard";
          template = {
            metadata.labels."app.kubernetes.io/name" = "netbird-dashboard";
            spec.containers = [
              {
                name = "dashboard";
                image = "netbirdio/dashboard@sha256:${dashboardDigest}";
                imagePullPolicy = "IfNotPresent";
                ports = [
                  {
                    name = "http";
                    containerPort = 80;
                  }
                ];
                env = [
                  {
                    name = "NETBIRD_MGMT_API_ENDPOINT";
                    value = managementUrl;
                  }
                  {
                    name = "NETBIRD_MGMT_GRPC_API_ENDPOINT";
                    value = managementUrl;
                  }
                  {
                    name = "AUTH_AUDIENCE";
                    value = "netbird-dashboard";
                  }
                  {
                    name = "AUTH_CLIENT_ID";
                    value = "netbird-dashboard";
                  }
                  {
                    name = "AUTH_CLIENT_SECRET";
                    value = "";
                  }
                  {
                    name = "AUTH_AUTHORITY";
                    value = "${managementUrl}/oauth2";
                  }
                  {
                    name = "USE_AUTH0";
                    value = "false";
                  }
                  {
                    name = "AUTH_SUPPORTED_SCOPES";
                    value = "openid profile email groups";
                  }
                  {
                    name = "AUTH_REDIRECT_URI";
                    value = "/nb-auth";
                  }
                  {
                    name = "AUTH_SILENT_REDIRECT_URI";
                    value = "/nb-silent-auth";
                  }
                  {
                    name = "LETSENCRYPT_DOMAIN";
                    value = "none";
                  }
                ];
                readinessProbe = {
                  httpGet = {
                    path = "/";
                    port = 80;
                  };
                  initialDelaySeconds = 5;
                  periodSeconds = 5;
                };
                livenessProbe = {
                  httpGet = {
                    path = "/";
                    port = 80;
                  };
                  initialDelaySeconds = 10;
                  periodSeconds = 10;
                };
              }
            ];
          };
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "netbird-dashboard";
          namespace = "netbird";
        };
        spec = {
          selector."app.kubernetes.io/name" = "netbird-dashboard";
          ports = [
            {
              name = "http";
              port = 80;
              targetPort = 80;
            }
          ];
        };
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "netbird-grpc";
          namespace = "netbird";
          annotations = {
            # Decision D2: ACME DNS-01 through Cloudflare, not openbao-intermediate.
            "cert-manager.io/cluster-issuer" = "cloudflare-dns01";
            "traefik.ingress.kubernetes.io/service.serversscheme" = "h2c";
          };
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = host;
              http.paths =
                map
                  (path: {
                    inherit path;
                    pathType = "Prefix";
                    backend.service = {
                      name = "netbird-server";
                      port.number = 80;
                    };
                  })
                  [
                    "/signalexchange.SignalExchange/"
                    "/management.ManagementService/"
                    "/management.ProxyService/"
                  ];
            }
          ];
          tls = [
            {
              hosts = [ host ];
              secretName = "netbird-tls";
            }
          ];
        };
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "netbird-http";
          namespace = "netbird";
          annotations."cert-manager.io/cluster-issuer" = "cloudflare-dns01";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = host;
              http.paths =
                map
                  (path: {
                    inherit path;
                    pathType = "Prefix";
                    backend.service = {
                      name = "netbird-server";
                      port.number = 80;
                    };
                  })
                  [
                    "/api"
                    "/oauth2"
                    "/relay"
                    "/ws-proxy/"
                  ];
            }
          ];
          tls = [
            {
              hosts = [ host ];
              secretName = "netbird-tls";
            }
          ];
        };
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "netbird-dashboard";
          namespace = "netbird";
          annotations."cert-manager.io/cluster-issuer" = "cloudflare-dns01";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = host;
              http.paths = [
                {
                  path = "/";
                  pathType = "Prefix";
                  backend.service = {
                    name = "netbird-dashboard";
                    port.number = 80;
                  };
                }
              ];
            }
          ];
          tls = [
            {
              hosts = [ host ];
              secretName = "netbird-tls";
            }
          ];
        };
      }
    ];
  }
)
