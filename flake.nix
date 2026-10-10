{
  description = "PFM NUR Repository";

  inputs = {
    ## --- Nixpkgs ---
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-unstable-small/nixexprs.tar.zst";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable-small/nixexprs.tar.zst";
    ## --- Flake ---
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-stable";
    };
    ## --- Base ---
    preservation.url = "github:nix-community/preservation";
    home-manager = {
      # 临时切主线
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    ## --- Nur ---
    nur.url = "github:nix-community/NUR";
    ## --- Applications ---
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.flake-parts.follows = "flake-parts";
    };

    ## --- Tools ---
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    colmena = {
      url = "github:nix-community/colmena";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        stable.follows = "nixpkgs-stable";
      };
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    nix-editor = {
      url = "github:snowfallorg/nix-editor";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";

    ## --- Framework consumers ---
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs = {
        nixpkgs.follows = "nixpkgs-stable";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    let
      projectRoot = ./.;
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }: {
        imports = [ inputs.treefmt-nix.flakeModule ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];

        perSystem =
          { system, ... }:
          let
            lib = inputs.nixpkgs-stable.lib;
            pkgs = import inputs.nixpkgs-stable {
              inherit system;
              config.allowUnfree = true;
              overlays = [
                (_final: prev: {
                  lib = prev.lib.extend (
                    _p: prevAttrs: { licenses = prevAttrs.licenses // (import (projectRoot + /lib/licenses.nix) { }); }
                  );
                })
                self.overlays.default
              ];
            };

            autoCall = import (projectRoot + /lib/auto-call.nix);
            packagesDir = autoCall {
              inherit lib;
              dir = projectRoot + /packages;
            };
            callPkg = lib.callPackageWith (pkgs // { inherit inputs; });
          in
          {
            _module.args.pkgs = pkgs;
            packages = packagesDir.callAll callPkg;

            treefmt = import (projectRoot + /framework/lib/treefmt-default.nix) { inherit pkgs; };
          };

        flake = {
          lib.mkFleet = import (projectRoot + /lib/mk-fleet.nix) { inherit inputs; };
          overlays.default = import (projectRoot + /overlays/default.nix) { inherit self; };
          nixosModules = {
            colmena = inputs.colmena.nixosModules.deploymentOptions;
            default = {
              nixpkgs.overlays = [ self.overlays.default ];
            };
          };
        };
      }
    );
}
