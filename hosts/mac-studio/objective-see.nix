# Objective-See tools that need a real /Applications path: macOS refuses
# system extensions and some privileged LaunchDaemons from the Nix store or
# symlinked ~/Applications. All of them are packaged in
# homelab/objective-see-package.nix (LuLu pinned to the latest upstream
# release via overrideAttrs of pkgs.lulu).
#
# Activation copies the bundles into /Applications when missing or outdated.
# Each Installer.app still registers its daemon via a GUI prompt on first
# launch; that remains a manual operator step.
# User-level scanners and CLIs install via Home Manager (home/objective-see.nix).
{
  pkgs,
  lib,
  homelab,
  ...
}:
let
  objectiveSee = import ../../homelab/objective-see-package.nix { inherit pkgs lib; };
  systemApps = builtins.attrValues objectiveSee.systemApps;
in
{
  system.activationScripts.postActivation.text = lib.mkIf homelab.objectiveSee.enable ''
    ${lib.concatMapStringsSep "\n" (app: ''
      for bundle in "${app}/Applications/"*.app; do
        name=$(/usr/bin/basename "$bundle")
        want=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist" 2>/dev/null)
        have=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "/Applications/$name/Contents/Info.plist" 2>/dev/null)
        if [ "$have" != "$want" ]; then
          echo "objective-see: installing $name $want into /Applications"
          /bin/rm -rf "/Applications/$name"
          /bin/cp -R "$bundle" "/Applications/$name"
          /bin/chmod -R u+w "/Applications/$name"
        fi
      done
    '') systemApps}
  '';
}
