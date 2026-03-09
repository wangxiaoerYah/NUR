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
  inherit (hostLib) hostsMeta modLib globalConfig;

  specialArgsFor = modLib.specialArgs {
    inherit inputs projectRoot modLib;
    configSet = globalConfig;
    allHostsMeta = hostsMeta;
    meta = {
      PLATFORM = "nixondroid";
      hostPlatform = "aarch64-linux";
      TAG = [ "client" ];
    };
  };
in
{
  flake.nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    modules = [
      (projectRoot + "/mod/nixondroid/mod-droid")
      ({ config, ... }: {
        imports = [ (projectRoot + "/mod/nixos/meta-loader.nix") ];
        mod.net.hostName = "droid";
        system.stateVersion = globalConfig.nixondroid.stateVersion;
        home-manager = {
          config.home.stateVersion = config.system.stateVersion;
          extraSpecialArgs = specialArgsFor;
        };
      })
      (projectRoot + "/mod/nixondroid/nix-on-droid.nix")
    ];

    extraSpecialArgs = specialArgsFor;
    pkgs = import inputs.nixpkgs-stable {
      system = "aarch64-linux";
      config = {
        allowUnfree = true;
      };
    };
    home-manager-path = inputs.home-manager.outPath;
  };
}
