{
  description = "PFM NUR Repository";

  inputs = {
    ## --- Nixpkgs ---
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-26.05-small/nixexprs.tar.zst";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable-small/nixexprs.tar.zst";
    ## --- Flake ---
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-stable";
    };
    ## --- Tools ---
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    let
      projectRoot = ./.;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
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

          packages = import (projectRoot + /lib/packages.nix) {
            inherit lib;
            dir = projectRoot + /packages;
          };
        in
        {
          _module.args.pkgs = pkgs;
          packages = packages.callAll pkgs.callPackage;

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.nixfmt.package = pkgs.nixfmt;
            programs.nixfmt.strict = true;
            programs.nixfmt.width = 120;
            programs.shfmt.enable = true;
            programs.shfmt.indent_size = 2;
            programs.shellcheck.enable = true;
            settings.formatter.shellcheck.options = [
              "-s"
              "bash"
            ];
            programs.taplo.enable = true;
            programs.prettier.enable = true;
            programs.prettier.package = pkgs.prettier;
            programs.prettier.settings = {
              tabWidth = 2;
              useTabs = false;
              printWidth = 120;
            };
            programs.just.enable = true;
            programs.fish_indent.enable = true;
          };
        };

      flake = {
        overlays.default = import (projectRoot + /overlays/default.nix) { inherit self; };
        nixosModules = {
          default = {
            nixpkgs.overlays = [ self.overlays.default ];
          };
        };
      };
    };
}
