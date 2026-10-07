_localFlake:
{
  inputs,
  lib,
  flake-parts-lib,
  ...
}:
let
  instanceOptions = _: {
    options = {
      sourceInput = lib.mkOption { default = inputs.nixpkgs-stable; };
      allowUnfree = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      patches = lib.mkOption {
        type = with lib.types; listOf path;
        default = [ ];
      };
      overlays = lib.mkOption { default = [ ]; };
      permittedInsecurePackages = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
      };
      allowInsecurePredicate = lib.mkOption {
        type = lib.types.anything;
        default = null;
      };
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
    };
  };
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      lib,
      system,
      config,
      ...
    }:
    {
      options.nixpkgs-options = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOptions);
        default = { };
      };

      config = {
        _module.args = lib.mapAttrs (
          _n: _v:
          let
            patchedSrc =
              if _v.patches == [ ] then
                _v.sourceInput
              else
                (import _v.sourceInput { inherit system; }).applyPatches {
                  name = "nixpkgs-patched";
                  src = _v.sourceInput;
                  inherit (_v) patches;
                };

            pkgConfig = {
              inherit (_v) allowUnfree permittedInsecurePackages;
            }
            // lib.optionalAttrs (_v.allowInsecurePredicate != null) { inherit (_v) allowInsecurePredicate; }
            // _v.settings;
          in
          import patchedSrc {
            inherit system;
            config = pkgConfig;
            inherit (_v) overlays;
          }
        ) config.nixpkgs-options;
      };
    }
  );
}
