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
  hostLib = import ./lib/nixos-host.nix {
    self = config.flake;
    inherit
      fleet
      inputs
      lib
      withSystem
      ;
  };

  meta = hostLib.hostsMeta;
  hosts = builtins.attrNames meta;

  archOf = n: meta.${n}.hostPlatform or "x86_64-linux";
  runnerOf =
    a:
    {
      "x86_64-linux" = "ubuntu-latest";
      "aarch64-linux" = "ubuntu-26.04-arm";
    }
    .${a} or null;
  isGui = n: builtins.elem "gui" (meta.${n}.TAG or [ ]);
  arches = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  toplevelOf = h: ".#nixosConfigurations.${h}.config.system.build.toplevel";
  droidInstallable = ".#nixOnDroidConfigurations.default.config.build.activationPackage";

  mkEntry = hs: {
    runner = runnerOf (archOf (builtins.head hs));
    installables = lib.concatStringsSep " " (map toplevelOf hs);
    label = if lib.length hs == 1 then builtins.head hs else "${toString (lib.length hs)} 台";
  };

  droidEntry = {
    label = "droid";
    runner = "ubuntu-26.04-arm";
    installables = droidInstallable;
    "nix-flags" = "--impure";
    "extra-substituters" = "https://nix-on-droid.cachix.org";
    "extra-keys" = "nix-on-droid.cachix.org-1:56snoMJTXmDRC1Ei24CmKoUqvHJ9XCp+nidK7qkMQrU=";
  };

  mkMatrix =
    { arch, only }:
    let
      selected = builtins.filter (
        n: (only == [ ] || builtins.elem n only) && (arch == "" || arch == archOf n) && runnerOf (archOf n) != null
      ) hosts;
      singles = map (n: mkEntry [ n ]) (builtins.filter isGui selected);
      groups = lib.concatMap (
        a:
        let
          groupHosts = builtins.filter (n: archOf n == a && !isGui n) selected;
        in
        lib.optional (groupHosts != [ ]) (mkEntry groupHosts)
      ) arches;
      droid = lib.optional (arch == "" || arch == "droid") droidEntry;
    in
    builtins.toJSON { include = singles ++ groups ++ droid; };
in
{
  flake.ciMatrix = mkMatrix;
}
