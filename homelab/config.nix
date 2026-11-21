{
  enable = false;
  internalZone = "lab.home.arpa";
  lanAddress = null;
  runtimes = {
    orbstack = true;
    podman = true;
    colima = true;
    netbird = false;
  };
  netbird = {
    managementUrl = null;
    credentialsItem = null;
    # CIDRs of the reverse proxy that is allowed to set forwarded client IPs.
    trustedProxyCIDRs = [ ];
  };
  cloudflare = {
    enable = false;
    zone = null;
    tokenItem = null;
  };
  onePassword = {
    enable = false;
    connectHost = null;
    tokenItem = null;
    certManagerSecretItem = null;
  };
  openbao = {
    certManagerRoleId = null;
    nativeRoleId = null;
  };
  imageDigests = {
    certManagerController = null;
    certManagerWebhook = null;
    certManagerCainjector = null;
    certManagerAcmesolver = null;
    certManagerStartupapicheck = null;
    externalDns = null;
    connectApi = null;
    connectSync = null;
    operator = null;
    # netbirdio/netbird-server:0.83.1 index digest, checked 2026-11-20:
    # sha256:f6acc1a6dcb48d10b867ec7e6916c62ef5c8dc2bb198aec9cc637b2dd26c06c9
    netbirdServer = null;
    netbirdDashboard = null;
  };
  services = [ ];
  nativeCertificates = [ ];
}
