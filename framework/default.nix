{
  lib,
  withSystem,
  flake-parts-lib,
  ...
}:
let
  dir = ./.;
  names = builtins.filter (n: lib.hasPrefix "flake-" n && lib.hasSuffix ".nix" n) (
    builtins.attrNames (builtins.readDir dir)
  );
in
{
  imports = map (n: flake-parts-lib.importApply (dir + "/${n}") { inherit withSystem; }) names;
}
