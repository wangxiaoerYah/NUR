_localFlake:
{
  config,
  fleet,
  lib,
  ...
}:
{
  flake.packages = lib.genAttrs fleet.systems (
    system:
    lib.mapAttrs' (n: v: lib.nameValuePair "nixos-${n}" v.config.system.build.toplevel) (
      lib.filterAttrs (_n: v: v.pkgs.stdenv.hostPlatform.system == system) config.flake.nixosConfigurations
    )
  );
  perSystem = { pkgs, config, ... }: {
    treefmt = fleet.treefmt { inherit pkgs; };
    apps.default = config.apps.colmena;
  };
}
