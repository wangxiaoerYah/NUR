_localFlake:
{ lib, config, ... }:
let
  mkColmenaHive =
    metaConfig: nodes: with builtins; rec {
      __schema = "v0.5";
      inherit metaConfig nodes;

      toplevel = lib.mapAttrs (_: v: v.config.system.build.toplevel) nodes;
      deploymentConfig = lib.mapAttrs (_: v: v.config.deployment) nodes;
      deploymentConfigSelected = names: lib.filterAttrs (name: _: elem name names) deploymentConfig;
      evalSelected = names: lib.filterAttrs (name: _: elem name names) toplevel;
      evalSelectedDrvPaths = names: lib.mapAttrs (_: v: v.drvPath) (evalSelected names);

      introspect =
        f:
        f {
          inherit lib;
          inherit ((head (attrValues nodes))) pkgs;
          inherit nodes;
        };
    };
in
{
  flake = {
    colmenaHive = mkColmenaHive { allowApplyAll = false; } config.flake.nixosConfigurations;
  };
}
