{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
  ...
}:
let
  inherit (lib) licenses maintainers platforms;

  version = "4.003-unstable-2023-10-19";

  src = fetchurl {
    hash = "sha256-IyKgHjE4Zho9dpgM/YFn9wS76mBEXflKAMedPWroW1c=";
    url = "https://hyperos.mi.com/font-download/MiSans_Global_ALL.zip";
  };

  meta = {
    description = "MiSans Global font collection (all languages)";
    homepage = "https://hyperos.mi.com/font/zh/details/sc";
    license = licenses.mi-sans-font-license;

    longDescription = ''
      Provides the whole MiSans Global collection from Xiaomi: MiSans (simplified Chinese),
      MiSans TC, L3, Latin, Thai, Lao, Khmer, Myanmar, Tibetan, Devanagari, Gujarati,
      Gurmukhi and Arabic, each in OpenType and TrueType plus a variable font.

      The package uses the MiSans Font Intellectual Property
      License Agreement and is treated as non-redistributable in
      this repository. Do not publish the built font files through a
      binary cache.
    '';

    maintainers = with maintainers; [ yah ];
    platforms = platforms.all;
    redistributable = false;
  };
in
stdenvNoCC.mkDerivation {
  inherit meta src version;

  pname = "misans-global";

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  postUnpack = ''
    mkdir -p fonts

    while IFS= read -r -d "" archive; do
      unzip -q -o "$archive" -d fonts
    done < <(find . -name '*.zip' -not -path './__MACOSX/*' -print0)

    rm -rf fonts/__MACOSX
  '';

  installPhase = ''
    runHook preInstall

    while IFS= read -r -d "" font; do
      case "$font" in
        *.otf) subdir=opentype ;;
        *) subdir=truetype ;;
      esac

      install -Dm444 "$font" "$out/share/fonts/$subdir/xiaomi/$(basename "$font")"
    done < <(find fonts -type f \( -iname '*.otf' -o -iname '*.ttf' -o -iname '*.ttc' \) -print0)

    runHook postInstall
  '';
}
