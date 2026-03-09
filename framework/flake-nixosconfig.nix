_localFlake:
{
  fleet,
  inputs,
  lib,
  config,
  withSystem,
  ...
}:
let
  projectRoot = fleet.src;
  hostLib = import ./nixos-host.nix {
    self = config.flake;
    inherit
      fleet
      inputs
      lib
      withSystem
      ;
  };
in
{
  flake.nixosConfigurations = lib.genAttrs hostLib.hostNames (
    name:
    hostLib.mkHost {
      inherit name;
      meta = hostLib.hostsMeta.${name};
      extraModules = [
        "${projectRoot}/hosts/${name}/configuration.nix"
      ]
      ++ hostLib.getAutoImports "${projectRoot}/hosts/${name}";
    }
  );
}
