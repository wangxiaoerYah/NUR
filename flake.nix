{
  description = "PFM NUR Repository";

  inputs = {
    ## --- Nixpkgs ---
    nixpkgs-stable.url = "https://channels.nixos.org/nixos-26.05-small/nixexprs.tar.zst";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable-small/nixexprs.tar.zst";
    ferron.url = "github:ferronweb/ferron/develop-3.x";
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

          # scope 内层那些包 (windows/*) 的 `lib` 取自 pkgs (见 packages/pfm-fonts/default.nix),
          # 而那两条字体许可不在 nixpkgs 的 lib.licenses 里, 所以扩展要挂在本 flake 自己的 pkgs 上.
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
          packages = packages.callAll (path: args: pkgs.callPackage path ({ inherit (inputs) ferron; } // args));

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
          ferron = inputs.ferron.nixosModules.default;
          ferron-sites = {
            imports = [
              inputs.ferron.nixosModules.default
              (import (projectRoot + /modules/ferron-sites.nix))
            ];
          };
        };
      };
    };
}
