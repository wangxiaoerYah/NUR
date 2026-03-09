{
  lib,
  newScope,
  lndir,
  stdenvNoCC,
  inter,
  symbola,
  wqy_microhei,
  wqy_zenhei,
  ...
}:
let
  lib' = lib.extend (
    _final: prev: { licenses = prev.licenses // (import ../../lib/licenses.nix { }); }
  );

  inherit (lib') concatStringsSep makeScope packagesFromDirectoryRecursive;

  inherit (import ../../lib/derivations.nix { lib = lib'; }) filterDerivations;

  link =
    {
      pname,
      scope,
      condition ? (_: true),
      passthru ? { },
    }:
    stdenvNoCC.mkDerivation {
      inherit passthru pname;

      dontUnpack = true;
      version = "0";

      installPhase = ''
        runHook preInstall

        mkdir -p $out

        for drv in ${concatStringsSep " " (filterDerivations condition scope)}; do
          ${lndir}/bin/lndir -silent $drv $out
        done

        runHook postInstall
      '';
    };

  windowsPackages = makeScope newScope (
    self:
    let
      packages = packagesFromDirectoryRecursive {
        inherit (self) callPackage newScope;

        directory = ./windows;
      };
    in
    packages // { mkMicrosoftFontDerivation = self.callPackage ./windows/builder.nix { }; }
  );

  xiaomiPackages = makeScope newScope (
    self:
    packagesFromDirectoryRecursive {
      inherit (self) callPackage newScope;

      directory = ./xiaomi;
    }
  );

  inherit (windowsPackages) windows-fonts;

  xiaomi-fonts = link {
    pname = "xiaomi-fonts";
    scope = xiaomiPackages;
  };

  pfm-fonts = link {
    pname = "pfm-fonts";

    scope = {
      inherit
        inter
        symbola
        windows-fonts
        wqy_microhei
        wqy_zenhei
        xiaomi-fonts
        ;
    };

    passthru = {
      inherit windows-fonts xiaomi-fonts;
      microsoftPackages = lib'.filterAttrs (_: value: lib'.isDerivation value) windowsPackages;
    };
  };
in
pfm-fonts
