{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "fcitx-pfm-theme";
  version = "0.0.1";

  src = ./theme;

  dontConfigure = true;
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/fcitx5/themes/wechat-dark
    cp -r $src/. $out/share/fcitx5/themes/wechat-dark
    install -Dm444 ${./LICENSE} $out/share/licenses/$pname/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "pfm theme";
    homepage = "https://github.com/wangxiaoerYah/NUR/tree/main/packages/fcitx-pfm-theme";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ yah ];
    platforms = lib.platforms.all;
  };
}
