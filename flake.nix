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
    in
    {
      darwinConfigurations.mac-studio = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs self user; };
        modules = [
          ./hosts/mac-studio/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit inputs user; };
            home-manager.users.${user} = ./home/guillermo.nix;
          }
        ];
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
