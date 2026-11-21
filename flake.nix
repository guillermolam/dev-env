{
  description = "dev-env: Nix-first workstation config (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      # The macOS username is not committed. It is read at evaluation time (requires --impure):
      #   DEVENV_USER  -> set explicitly (CI uses the DEVENV_USER repository secret)
      #   SUDO_USER    -> fallback for `sudo darwin-rebuild switch` on the machine itself
      #   USER         -> last resort
      env = builtins.getEnv;
      firstSet =
        vals:
        let
          set = builtins.filter (v: v != "" && v != "root") vals;
        in
        if set == [ ] then
          throw "dev-env: set DEVENV_USER and evaluate with --impure"
        else
          builtins.head set;
      user = firstSet [
        (env "DEVENV_USER")
        (env "SUDO_USER")
        (env "USER")
      ];
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      homelab = import ./homelab/config.nix;
      runtimePkgs = import nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "orbstack";
      };
      runtimePackages = import ./homelab/runtime-packages.nix {
        pkgs = runtimePkgs;
        inherit (nixpkgs) lib;
      };
      openshell = import ./homelab/openshell-package.nix {
        pkgs = runtimePkgs;
        inherit (nixpkgs) lib;
      };
      operationsSrc = builtins.path {
        name = "mac-env-operations";
        path = ./operations;
        filter =
          path: type:
          let
            base = baseNameOf path;
          in
          base != "__pycache__"
          && base != ".cache"
          && base != ".DS_Store"
          && !(nixpkgs.lib.hasSuffix ".pyc" base);
      };
      # Host Homebrew stays reachable for collectors; installed LaunchDaemon must
      # set MAC_ENV_STATE_DIR=/private/var/lib/mac-environment explicitly.
      mac-env = pkgs.writeScriptBin "mac-env" ''
        #!${pkgs.runtimeShell}
        set -eu
        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.python3
            pkgs.open-policy-agent
            pkgs.nix
            pkgs.restic
          ]
        }:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
        export PYTHONPATH=${operationsSrc}
        export MAC_ENV_OPA=${pkgs.open-policy-agent}/bin/opa
        export MAC_ENV_POLICY=${operationsSrc}/policy
        export MAC_ENV_RESTIC=''${MAC_ENV_RESTIC:-${pkgs.restic}/bin/restic}
        exec ${pkgs.python3}/bin/python3 -m mac_env "$@"
      '';
    in
    {
      # Packaging does not activate the controller. darwin-rebuild switch is a separate step.
      packages.aarch64-darwin = {
        inherit mac-env;
        default = mac-env;
        opa = pkgs.open-policy-agent;
        restic = pkgs.restic;
        vulnix = pkgs.vulnix;
        colima = pkgs.colima;
        incus-client = pkgs.incus.client;
        inherit (runtimePackages) podman podman-desktop orbstack;
        inherit openshell;
        netbird-installer = (import ./homelab/netbird-package.nix { pkgs = runtimePkgs; }).installer;
      };

      darwinConfigurations.mac-studio = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit
            inputs
            self
            user
            homelab
            ;
        };
        modules = [
          ./hosts/mac-studio/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = {
              inherit inputs user homelab;
            };
            home-manager.users.${user} = ./home/guillermo.nix;
          }
        ];
      };

      formatter.aarch64-darwin = pkgs.nixfmt;
      provisionPlan = import ./homelab/provision-plan.nix { inherit (nixpkgs) lib; };
    };
}
