# 主题文件是上游仓库里 `mellow-wechat-dark` 那一个目录的三个文件原样拷进来的 (BSD-2-Clause,
# 见同目录 LICENSE), 不打包上游其余 9 个主题, 也不做 sed 改写; 装出来的主题标识是
# `wechat-dark` (上游目录名去掉 mellow), classicui.conf 里的 `Theme` 写的就是这个名字.
#
# 来源: https://github.com/sanweiya/fcitx5-mellow-themes
# rev:  2c93b0ea3418a55c03f526d963c84a7ccde2c1e9 (2026-09-10, 上游不打 tag)
# 来源里的 theme.conf 版本: 1.10.1
{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "fcitx-pfm-theme";
  version = "1.10.1";

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
