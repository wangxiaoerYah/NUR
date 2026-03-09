{ lib, dir }:
let
  entries = lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir);
in
{
  names = builtins.attrNames entries;

  # `callPackage` 由调用方给: flake 里是 `pkgs.callPackage`, overlay 里是 `final.callPackage`.
  callAll = callPackage: lib.mapAttrs (name: _: callPackage (dir + "/${name}") { }) entries;
}
