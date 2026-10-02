{ projectRoot }:
final: prev:
let
  lib = prev.lib.extend (
    _final: prevAttrs: { licenses = prevAttrs.licenses // (import (projectRoot + /lib/licenses.nix) { }); }
  );

  packages = import (projectRoot + /lib/packages.nix) {
    inherit lib;
    dir = projectRoot + /packages;
  };
in
{ inherit lib; } // packages.callAll final.callPackage
