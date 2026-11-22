# Objective-See security tools for aarch64-darwin, pinned to upstream releases.
# Verified 2026-11-21 against objective-see.org/tools.html,
# objective-see.org/products/utilities.html, and each GitHub releases/latest.
# LuLu ships in the pinned nixpkgs (4.5.4); it is overridden here to the latest
# upstream release (4.5.7) while reusing the nixpkgs undmg unpack/install logic.
#
# Two families, matching how macOS accepts each tool:
# - systemApps: zips contain "<Name> Installer.app", which registers the
#   privileged LaunchDaemon / system extension on first launch. macOS refuses
#   system extensions that run from the Nix store, so these must be copied
#   into /Applications (see hosts/mac-studio/objective-see.nix). TaskExplorer
#   3.x ships the app directly but needs the same treatment for its
#   Endpoint Security helper.
# - userApps / cliTools: self-contained, safe in Home Manager home.packages.
#   The monitor CLIs live inside the .app bundle and are wrapped into $out/bin.
{ lib, pkgs }:

let
  mkTool =
    {
      pname,
      version,
      url,
      hash,
      appBundle,
      binName ? null,
      description,
      license ? lib.licenses.gpl3Only,
      homepage ? "https://objective-see.org/tools.html",
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;

      src = pkgs.fetchurl {
        inherit url hash;
      };

      nativeBuildInputs = [ pkgs.unzip ] ++ lib.optionals (binName != null) [ pkgs.makeWrapper ];
      sourceRoot = ".";

      installPhase = ''
        runHook preInstall
        test -d "./${appBundle}"
        mkdir -p "$out/Applications"
        cp -R "./${appBundle}" "$out/Applications/${appBundle}"
        # Some upstream zips carry AppleDouble files inside the bundle; they
        # break the code-signature seal. Archive Utility drops them too.
        find "$out/Applications/${appBundle}" \( -name '._*' -o -name '.DS_Store' \) -delete
      ''
      + lib.optionalString (binName != null) ''
        mkdir -p "$out/bin"
        makeWrapper "$out/Applications/${appBundle}/Contents/MacOS/${binName}" "$out/bin/${pname}"
      ''
      + ''
        runHook postInstall
      '';

      # Preserve upstream's notarized bundle and system-extension signatures.
      dontFixup = true;

      meta = {
        inherit description homepage license;
        platforms = lib.platforms.darwin;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      }
      // lib.optionalAttrs (binName != null) {
        mainProgram = pname;
      };
    };

  # --- System-extension / privileged-daemon tools (need /Applications) -------

  # Newer than the pinned nixpkgs (4.5.4); keep the nixpkgs derivation logic
  # and only swap version and src, like the orbstack pin in runtime-packages.nix.
  lulu = pkgs.lulu.overrideAttrs (_: {
    version = "4.5.7";
    src = pkgs.fetchurl {
      url = "https://github.com/objective-see/LuLu/releases/download/v4.5.7/LuLu_4.5.7.dmg";
      hash = "sha256-jWDzK2lyZIqrkgPy9ovTqATi4Fwj1gIA1eCT1r2wbow=";
    };
  });

  blockblock = mkTool {
    pname = "blockblock";
    version = "2.5.2";
    url = "https://github.com/objective-see/BlockBlock/releases/download/v2.5.2/BlockBlock_2.5.2.zip";
    hash = "sha256-flozKk2moi6LSUQYw8rCQdJLQxdsi/xLsu+L3GQL1Mc=";
    appBundle = "BlockBlock Installer.app";
    description = "Detects and alerts on persistent malware (LaunchDaemons/LaunchAgents)";
  };

  oversight = mkTool {
    pname = "oversight";
    version = "2.4.0";
    url = "https://github.com/objective-see/OverSight/releases/download/v2.4.0/OverSight_2.4.0.zip";
    hash = "sha256-I1IhSDDQxsgnuOAQ2N6lk1HcuhUBloOm5GhhGRdLmbk=";
    appBundle = "OverSight Installer.app";
    description = "Monitors and alerts on camera and microphone access";
  };

  ransomwhere = mkTool {
    pname = "ransomwhere";
    version = "2.2.0";
    url = "https://github.com/objective-see/RansomWhere/releases/download/v2.2.0/RansomWhere_2.2.0.zip";
    hash = "sha256-mCsLnDAnlH4KrKFteTb+PmY53avo+v6XnFDH2MQwKvE=";
    appBundle = "RansomWhere Installer.app";
    description = "Generic ransomware detection and response";
  };

  reikey = mkTool {
    pname = "reikey";
    version = "1.4.2";
    url = "https://bitbucket.org/objective-see/deploy/downloads/ReiKey_1.4.2.zip";
    hash = "sha256-zu4uzo3eHh2NSYql2Xgtv1pisySQNzLgipfeCGgRRGs=";
    appBundle = "ReiKey Installer.app";
    description = "Detects and monitors keyboard event taps (keyloggers)";
  };

  donotdisturb = mkTool {
    pname = "donotdisturb";
    version = "2.1.0";
    url = "https://github.com/objective-see/DoNotDisturb/releases/download/v2.1.0/DoNotDisturb_2.1.0.zip";
    hash = "sha256-r0oOVdIP9aKLXJGpUX9wvbp3wYIXTCSpPSNDR+KIXaE=";
    appBundle = "DoNotDisturb Installer.app";
    description = "Detects physical-access attacks that unlock a sleeping Mac";
  };

  whatsyoursign = mkTool {
    pname = "whatsyoursign";
    version = "3.2.2";
    url = "https://github.com/objective-see/WhatsYourSign/releases/download/v3.2.2/WhatsYourSign_3.2.2.zip";
    hash = "sha256-vs0pEX9Kto2JD1E+qg0/vet91mvToiaLNlGAQ1hS0xk=";
    appBundle = "WhatsYourSign Installer.app";
    description = "Finder extension showing the code signature of any file";
  };

  taskexplorer = mkTool {
    pname = "taskexplorer";
    version = "3.1.1";
    url = "https://github.com/objective-see/TaskExplorer/releases/download/v3.1.1/TaskExplorer_3.1.1.zip";
    hash = "sha256-WnME6xldp8k19PX8Acd+h8ct46PEmf540MpyiiJifK4=";
    appBundle = "TaskExplorer.app";
    description = "Explores running processes, code signatures, and open files";
  };

  # --- Self-contained GUI scanners (Home Manager safe) -----------------------

  knockknock = mkTool {
    pname = "knockknock";
    version = "4.1.0";
    url = "https://github.com/objective-see/KnockKnock/releases/download/v4.1.0/KnockKnock_4.1.0.zip";
    hash = "sha256-mOrmzaWn4SLmx+aGImF8ANZTOpCfUF8ALJPdkJQaP54=";
    appBundle = "KnockKnock.app";
    description = "Shows what is persistently installed on the system";
  };

  netiquette = mkTool {
    pname = "netiquette";
    version = "2.3.0";
    url = "https://github.com/objective-see/Netiquette/releases/download/v2.3.0/Netiquette_2.3.0.zip";
    hash = "sha256-4gSsDCaJQrkAX08Xvni5enstOxmAMzDUMsGWAhoOjUo=";
    appBundle = "Netiquette.app";
    description = "Displays per-process network connections";
  };

  dhs = mkTool {
    pname = "dhs";
    version = "1.6.0";
    url = "https://github.com/objective-see/DylibHijackScanner/releases/download/v1.6.0/DHS_1.6.0.zip";
    hash = "sha256-PnL/pVkzKvtlqDv7w7WXMGSqyaQk3unMi8V+Y/htco8=";
    appBundle = "DHS.app";
    description = "Dylib Hijack Scanner: detects dylib insertion and hijacking";
  };

  kextviewr = mkTool {
    pname = "kextviewr";
    version = "2.0.0";
    url = "https://github.com/objective-see/KextViewr/releases/download/v2.0.0/KextViewr_2.0.0.zip";
    hash = "sha256-zZIUF1CBJ5fP/WJvaXwTP6yEthW11M1drlaoFgMglo4=";
    appBundle = "KextViewr.app";
    description = "Lists and inspects loaded kernel extensions";
    # Upstream repo publishes no license file; distributed as freeware.
    license = lib.licenses.free;
  };

  # --- GUI + CLI monitors (CLI wrapped into $out/bin) ------------------------

  filemonitor = mkTool {
    pname = "filemonitor";
    version = "1.3.0";
    url = "https://bitbucket.org/objective-see/deploy/downloads/FileMonitor_1.3.0.zip";
    hash = "sha256-DCMXuhkux/dopReH50hvYKBN3uQgcekWivm4RU/nYrc=";
    appBundle = "FileMonitor.app";
    binName = "FileMonitor";
    description = "Monitors and reports filesystem events (GUI and CLI)";
  };

  processmonitor = mkTool {
    pname = "processmonitor";
    version = "1.5.0";
    url = "https://bitbucket.org/objective-see/deploy/downloads/ProcessMonitor_1.5.0.zip";
    hash = "sha256-bFch3vQm3ne/9h1nLQdjFNiftrrSiWnzsVufjIfL1ZE=";
    appBundle = "ProcessMonitor.app";
    binName = "ProcessMonitor";
    description = "Monitors process executions and exits (GUI and CLI)";
  };

  dnsmonitor = mkTool {
    pname = "dnsmonitor";
    version = "1.3.0";
    url = "https://github.com/objective-see/DNSMonitor/releases/download/v1.3.0/DNSMonitor_1.3.0.zip";
    hash = "sha256-LXDEX1XmfU5xgjrNcjLnrRqkHKeiIj+NAmOhR0xkfo0=";
    appBundle = "DNSMonitor.app";
    binName = "DNSMonitor";
    description = "Monitors DNS queries (GUI and CLI)";
  };

  systemApps = {
    inherit
      lulu
      blockblock
      oversight
      ransomwhere
      reikey
      donotdisturb
      whatsyoursign
      taskexplorer
      ;
  };
  userApps = {
    inherit
      knockknock
      netiquette
      dhs
      kextviewr
      ;
  };
  cliTools = {
    inherit filemonitor processmonitor dnsmonitor;
  };
in
{
  inherit systemApps userApps cliTools;
  # Flat set, used by the flake packages output.
  tools = systemApps // userApps // cliTools;
}
