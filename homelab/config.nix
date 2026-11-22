{
  enable = false;
  internalZone = "lab.home.arpa";
  # I3 (2026-11-22): LAN reach, operator-chosen. Current DHCP lease; reserve a
  # static lease on the router so ExternalDNS records do not drift.
  lanAddress = "10.0.0.5";
  # Staged flags (exec plan platform-prereqs-netbird P1): independent of
  # homelab.enable so the cluster and GitOps tooling land in dependency order.
  stages = {
    # L1: OrbStack Kubernetes cluster (decision D1).
    kubernetes = false;
    # L3: Argo CD GitOps CLIs (argocd, oras, tofu). Requires the kubernetes stage.
    gitops = false;
  };
  kubernetes = {
    # Bring-up default: ClusterIP, per the operator finding recorded in
    # personal-platform/ztna/netbird/README.md (2026-11-22): OrbStack's
    # LoadBalancer opened listeners on all Mac interfaces even with
    # k8s.expose_services disabled. Flip to "LoadBalancer" after P7 verifies
    # exposure behavior. ClusterIP services ignore externalTrafficPolicy.
    traefikServiceType = "ClusterIP";
    # I3 (2026-11-22): operator chose LAN reach for the NetBird A record, but
    # the finding above shows the OrbStack toggle does not confine listeners
    # as documented. Keep off until P7; LAN reach is then re-decided (LAN
    # listener vs. the macos-cloudflare tunnel work in personal-platform).
    exposeServicesToLan = false;
  };
  runtimes = {
    orbstack = true;
    podman = true;
    colima = true;
    openshell = true;
    netbird = false;
  };
  objectiveSee = {
    enable = true;
  };
  netbird = {
    # I2 (2026-11-22): public hostname in the lamcloud.net zone (decision D2/D5).
    managementUrl = "https://netbird.lamcloud.net";
    credentialsItem = null;
    # CIDRs of the reverse proxy that is allowed to set forwarded client IPs.
    # Traefik pods reach netbird-server from the cluster pod CIDR. Placeholder
    # is the k3s/OrbStack default; verify at P2 (`kubectl cluster-info dump |
    # grep cluster-cidr`) before enabling runtimes.netbird.
    trustedProxyCIDRs = [ "10.42.0.0/16" ];
  };
  cloudflare = {
    enable = false;
    zone = "lamcloud.net";
    tokenItem = null;
    # ACME DNS-01 account for the cloudflare-dns01 ClusterIssuer (decision D2).
    acme = {
      email = null;
      server = "https://acme-v02.api.letsencrypt.org/directory";
    };
  };
  onePassword = {
    enable = false;
    # Bare hostname, not a URL: the connect chart renders http://<host>:8080.
    connectHost = null;
    tokenItem = null;
    certManagerSecretItem = null;
  };
  openbao = {
    certManagerRoleId = null;
    nativeRoleId = null;
  };
  imageDigests = {
    # OCI index digests, checked 2026-11-22 with `docker buildx imagetools inspect`.
    certManagerController = "9f4f96a33c7774cef24466fcd85031997531a03a8d117f151126baa8d1290dcc";
    certManagerWebhook = "055ac8e9de6a0ba6763794838fe38944acc650f68ebe1b01dd8be079e580f458";
    certManagerCainjector = "083d0e906f8eb44e255fe4ff817ae54e49f9ed82e22f1011bb4e9e4f4b8a641f";
    certManagerAcmesolver = "c8c1225bb2fe8ab37a330b77f0d8c2ee6a41210fcb54fc07ca606ab9a022b8b7";
    certManagerStartupapicheck = "1c519d4afca1413d1e4ccd78bdc756184418ab55a34569a3b3de39d32f9974e1";
    externalDns = "a80a146d2540fa138565e404f0625157271071a06093021f27ae19d8316d10f9";
    # docker.io/1password/onepassword-operator:1.12.1 (chart default; rendered
    # as tag@sha256 by the connect chart's operator-deployment template).
    operator = "99329ca86f28c3e79ac88766910433bb732bb50be506863c532c16bb29ff93c9";
    # Unused while onePassword Connect itself is not rendered (connect.create=false).
    connectApi = null;
    connectSync = null;
    # netbirdio/netbird-server:0.83.1 index digest, re-checked 2026-11-22 and
    # equal to the value recorded 2026-11-20.
    netbirdServer = "f6acc1a6dcb48d10b867ec7e6916c62ef5c8dc2bb198aec9cc637b2dd26c06c9";
    # netbirdio/dashboard:v2.96.0 — the version the NetBird docs pair with
    # server 0.83.1; the docs' `-rootless` variant does not exist on the hub.
    netbirdDashboard = "340b13c00b84349572a2acc5605e907cb09250a9e6461c757097eabdb8e02f2c";
    # docker.io/library/traefik:v3.7.19 index digest (chart 42.4.1 appVersion),
    # checked 2026-11-22 with `docker buildx imagetools inspect`:
    traefik = "a6c0194dda77bcb804824580f36fa7edc56e315b1acfe933366c8b52844a78a4";
  };
  services = [
    {
      name = "netbird";
      internalName = "netbird.lab.home.arpa";
      internalTargets = [ "10.0.0.5" ];
      # D5: ExternalDNS owns this record (annotation dev-env/visibility=public).
      publicName = "netbird.lamcloud.net";
      publicTargets = [ "10.0.0.5" ];
    }
  ];
  nativeCertificates = [ ];
}
