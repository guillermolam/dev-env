{ pkgs }:
rec {
  version = "0.83.1";
  installer = pkgs.fetchurl {
    url = "https://github.com/netbirdio/netbird/releases/download/v${version}/netbird_${version}_darwin_arm64.pkg";
    hash = "sha256-qW5AK6Mf9IBKiK0E+sLj+eaV8OgEQPOaaMLLP2YaDSo=";
  };
}
