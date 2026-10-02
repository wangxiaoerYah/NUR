{
  cascadia-code,
  lib,
  nerd-fonts,
  newScope,
  lndir,
  noto-fonts-color-emoji,
  stdenvNoCC,
  symbola,
  wqy_microhei,
  wqy_zenhei,
  ...
}:
let
  inherit (lib) concatStringsSep makeScope packagesFromDirectoryRecursive;

  inherit (import ../../lib/derivations.nix { inherit lib; }) filterDerivations;

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
        cascadia-code
        noto-fonts-color-emoji
        symbola
        windows-fonts
        wqy_microhei
        wqy_zenhei
        xiaomi-fonts
        ;

      # Nerd 图标字形 (两种 family: `Symbols Nerd Font` / `Symbols Nerd Font Mono`).
      nerd-fonts-symbols = nerd-fonts.symbols-only;
    };

    passthru = {
      inherit windows-fonts xiaomi-fonts;
      microsoftPackages = lib.filterAttrs (_: value: lib.isDerivation value) windowsPackages;

      # 构建时下的大件 (固定输出): 它们是构建输入, 不在产物的引用闭包里, 推缓存时要单独带上.
      sources = {
        windows-fonts = windows-fonts.src;
        misans-global = xiaomiPackages.misans-global.src;
      };
    };
  };
in
pfm-fonts
