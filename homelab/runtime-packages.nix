{ lib, pkgs }:
let
  podman = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "podman";
    version = "6.2.0";

    src = pkgs.fetchurl {
      url = "https://github.com/podman-container-tools/podman/releases/download/v${finalAttrs.version}/podman-remote-release-darwin_arm64.zip";
      sha256 = "34b4a24e2a749d1ad5e2edacaf01efcf2c2cc89175e5db8c953fd46ba663d17e";
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.unzip
    ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      for candidate in podman */podman podman-*/usr/bin/podman; do
        if [ -f "$candidate" ]; then
          install -m 0755 "$candidate" "$out/bin/podman"
          break
        fi
      done
      test -x "$out/bin/podman"
      mkdir -p "$out/libexec/podman"
      ln -s ${pkgs.gvproxy}/bin/gvproxy "$out/libexec/podman/gvproxy"
      makeWrapper ${pkgs.krunkit}/bin/krunkit "$out/libexec/podman/krunkit" --add-flags "--firmware-path ${pkgs.krunkit}/share/krunkit/KRUN_EFI.silent.fd"
      ln -s ${pkgs.vfkit}/bin/vfkit "$out/libexec/podman/vfkit"
      makeWrapper ${pkgs.openssh}/bin/ssh "$out/bin/ssh" --add-flags "-F /dev/null"
      wrapProgram "$out/bin/podman" \
        --prefix PATH : "$out/bin:${
          lib.makeBinPath [
            pkgs.gvproxy
            pkgs.krunkit
            pkgs.openssh
            pkgs.vfkit
          ]
        }"
      runHook postInstall
    '';

    meta = {
      description = "Podman remote client for macOS";
      homepage = "https://podman.io";
      license = lib.licenses.asl20;
      mainProgram = "podman";
      platforms = lib.platforms.darwin;
    };
  });

  podman-desktop = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "podman-desktop";
    version = "1.30.7";

    src = pkgs.fetchurl {
      url = "https://github.com/podman-desktop/podman-desktop/releases/download/v${finalAttrs.version}/podman-desktop-${finalAttrs.version}-arm64.dmg";
      sha256 = "99689844fc594ffbc8722483b2c3be5f3d27d6fa5c3678837e961ce031feae95";
    };

    nativeBuildInputs = [
      pkgs._7zz
      pkgs.makeWrapper
    ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      app_path=$(find . -type d -name 'Podman Desktop.app' -print -quit)
      test -n "$app_path"
      mkdir -p "$out/Applications" "$out/bin"
      cp -R "$app_path" "$out/Applications/Podman Desktop.app"
      makeWrapper \
        "$out/Applications/Podman Desktop.app/Contents/MacOS/Podman Desktop" \
        "$out/bin/podman-desktop" \
        --prefix PATH : ${
          lib.makeBinPath [
            podman
            pkgs.krunkit
          ]
        }
      runHook postInstall
    '';

    meta = {
      description = "Graphical tool for Podman containers";
      homepage = "https://podman-desktop.io";
      license = lib.licenses.asl20;
      mainProgram = "podman-desktop";
      platforms = lib.platforms.darwin;
    };
  });

  orbstack = pkgs.orbstack.overrideAttrs (_: {
    version = "2.2.5-21124";
    src = pkgs.fetchurl {
      url = "https://cdn-updates.orbstack.dev/arm64/OrbStack_v2.2.5_21124_arm64.dmg";
      hash = "sha256-8riH0moh4KEhR+sAUpd4J5Syb0Yfd8a5zftX9XatXm0=";
    };
  });
in
{
  inherit podman podman-desktop orbstack;
}
