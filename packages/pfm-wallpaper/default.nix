{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  inherit (lib) licenses maintainers platforms;
in
stdenvNoCC.mkDerivation {
  pname = "pfm-wallpaper";
  version = "unstable-2026-10-10";

  src = fetchurl {
    url = "https://opensource.power-app.eu.org/wallpaper/wallpaper.png";
    hash = "sha256-2hKD0hMUTLQa0OXQHy1dcbtQnfX77G7nRFw7aGjNmak=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 $src $out/share/wallpapers/wallpaper.png

    runHook postInstall
  '';

  meta = {
    description = "PFM desktop wallpaper";
    homepage = "https://github.com/wangxiaoerYah/NUR/tree/main/packages/pfm-wallpaper";

    longDescription = ''
      Desktop wallpaper used by the Noctalia shell and the Noctalia greeter.
      The image is fetched from the author's own host; upstream publishes no
      version, so the content is pinned by hash and the version is a date.
    '';

    license = licenses.cc0;
    maintainers = with maintainers; [ yah ];
    platforms = platforms.all;
  };
}
