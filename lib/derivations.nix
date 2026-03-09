{ lib, ... }:
let
  inherit (lib) isDerivation pipe;
in
{
  filterDerivations =
    predicate: scope:
    pipe scope [
      lib.attrValues
      (lib.filter isDerivation)
      (lib.filter predicate)
    ];
}
