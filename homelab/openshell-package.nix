# NVIDIA OpenShell 0.1.9 for aarch64-darwin. Pinned release tarballs; no Homebrew.
{ lib, pkgs }:
let
  version = "0.1.9";
  base = "https://github.com/NVIDIA/OpenShell/releases/download/v${version}";
  # Hashes from nvidia/homebrew-openshell Formula/openshell.rb @ v0.1.9.
  cliSrc = pkgs.fetchurl {
    url = "${base}/openshell-aarch64-apple-darwin.tar.gz";
    sha256 = "355bf612159eaa0c5375facd8f27536d9cb54e5af030328ea839a927a7901da5";
  };
  gatewaySrc = pkgs.fetchurl {
    url = "${base}/openshell-gateway-aarch64-apple-darwin.tar.gz";
    sha256 = "b348a57b97dc755d6a668631d328dd03fa88dc1b3565f16a094c9c59a420c51a";
  };
  vmSrc = pkgs.fetchurl {
    url = "${base}/openshell-driver-vm-aarch64-apple-darwin.tar.gz";
    sha256 = "92b90edd2f1795bf99bf708203a1b7fa13026486426a65435049f068e0393df7";
  };
  proverSrc = pkgs.fetchurl {
    url = "${base}/openshell-prover-aarch64-apple-darwin.tar.gz";
    sha256 = "fb5af6346ff77d5d4508c4b8c4895d4363da834ab7fe5e6be2528c0820c71b4b";
  };
  entitlements = pkgs.writeText "openshell-driver-vm.entitlements.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>com.apple.security.hypervisor</key>
        <true/>
    </dict>
    </plist>
  '';
  # Shell wrapper body. ''${...} escapes Nix interpolation so bash sees ${...}.
  gatewayService = pkgs.writeShellScript "openshell-gateway-service" ''
    set -eu
    if [ -z "''${HOME:-}" ]; then
      echo "HOME must be set" >&2
      exit 1
    fi
    STATE="''${MAC_ENV_OPENSHELL_STATE:-''${XDG_STATE_HOME:-$HOME/.local/state}/mac-environment/openshell}"
    CONFIG="''${MAC_ENV_OPENSHELL_CONFIG:-''${XDG_CONFIG_HOME:-$HOME/.config}/mac-environment/openshell/gateway.toml}"
    TLS_DIR="$STATE/runtime-tls"
    mkdir -p "$TLS_DIR/server" "$TLS_DIR/client" "$TLS_DIR/jwt"
    chmod 700 "$STATE" "$TLS_DIR" "$TLS_DIR/server" "$TLS_DIR/client" "$TLS_DIR/jwt"
    if [ ! -f "$STATE/tls/ca.crt" ]; then
      echo "missing $STATE/tls; run scripts/openshell-provision.sh provision --confirm" >&2
      exit 1
    fi
    /usr/bin/install -m 0644 "$STATE/tls/ca.crt" "$TLS_DIR/ca.crt"
    /usr/bin/install -m 0644 "$STATE/tls/server/tls.crt" "$TLS_DIR/server/tls.crt"
    /usr/bin/install -m 0600 "$STATE/tls/server/tls.key" "$TLS_DIR/server/tls.key"
    /usr/bin/install -m 0644 "$STATE/tls/client/tls.crt" "$TLS_DIR/client/tls.crt"
    /usr/bin/install -m 0600 "$STATE/tls/client/tls.key" "$TLS_DIR/client/tls.key"
    /usr/bin/install -m 0600 "$STATE/tls/jwt/signing.pem" "$TLS_DIR/jwt/signing.pem"
    /usr/bin/install -m 0644 "$STATE/tls/jwt/public.pem" "$TLS_DIR/jwt/public.pem"
    /usr/bin/install -m 0644 "$STATE/tls/jwt/kid" "$TLS_DIR/jwt/kid"
    export OPENSHELL_LOCAL_TLS_DIR="''${OPENSHELL_LOCAL_TLS_DIR:-$TLS_DIR}"
    export OPENSHELL_COMPUTE_DRIVER="''${OPENSHELL_COMPUTE_DRIVER:-docker}"
    export OPENSHELL_GATEWAY_CONFIG="''${OPENSHELL_GATEWAY_CONFIG:-$CONFIG}"
    exec @gateway@ --config "$OPENSHELL_GATEWAY_CONFIG"
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "openshell";
  inherit version;

  srcs = [
    cliSrc
    gatewaySrc
    vmSrc
    proverSrc
  ];
  sourceRoot = ".";

  nativeBuildInputs = [
    pkgs.gnutar
    pkgs.gzip
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p cli gateway vm prover
    tar -xzf ${cliSrc} -C cli
    tar -xzf ${gatewaySrc} -C gateway
    tar -xzf ${vmSrc} -C vm
    tar -xzf ${proverSrc} -C prover
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/libexec" "$out/share/openshell"
    install -m 0755 cli/openshell "$out/bin/openshell"
    install -m 0755 gateway/openshell-gateway "$out/bin/openshell-gateway"
    install -m 0755 prover/openshell-prover "$out/bin/openshell-prover"
    install -m 0755 vm/openshell-driver-vm "$out/libexec/openshell-driver-vm"
    cp ${entitlements} "$out/share/openshell/openshell-driver-vm.entitlements.plist"
    /usr/bin/codesign --entitlements "$out/share/openshell/openshell-driver-vm.entitlements.plist" \
      --force -s - "$out/libexec/openshell-driver-vm" || true
    # Bake absolute gateway path into the service wrapper.
    substitute ${gatewayService} "$out/libexec/openshell-gateway-service" \
      --replace-fail '@gateway@' "$out/bin/openshell-gateway"
    chmod 0755 "$out/libexec/openshell-gateway-service"
    runHook postInstall
  '';

  meta = {
    description = "NVIDIA OpenShell CLI, gateway, prover, and VM driver";
    homepage = "https://github.com/NVIDIA/OpenShell";
    license = lib.licenses.asl20;
    mainProgram = "openshell";
    platforms = [ "aarch64-darwin" ];
  };
}
