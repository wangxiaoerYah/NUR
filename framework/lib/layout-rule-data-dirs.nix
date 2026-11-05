# 数据目录约定: assets/ 顶层只放白名单子目录且不许散落文件; secrets/ 只放 age 机密 / nix 规则 / 两个固定文件名
{ root }:
let
  assetsDir = root + "/assets";
  secretsDir = root + "/secrets";
  allowedAssets = [
    "agent"
    "install"
    "keys"
    "proxy"
    "public"
    "scripts"
  ];
  assetEntries = if builtins.pathExists assetsDir then builtins.readDir assetsDir else { };
  secretFiles =
    if builtins.pathExists secretsDir then
      builtins.filter (n: (builtins.readDir secretsDir).${n} == "regular") (builtins.attrNames (builtins.readDir secretsDir))
    else
      [ ];
  okSecret =
    n:
    builtins.match ".*\\.age" n != null
    || builtins.match ".*\\.nix" n != null
    || builtins.elem n [
      "Justfile"
      "keys.json"
    ];
in
map (n: "assets/ 顶层多出 ${n} (允许: ${builtins.concatStringsSep " / " allowedAssets}): ${assetsDir}/${n}") (
  builtins.filter (n: !(builtins.elem n allowedAssets) || assetEntries.${n} != "directory") (
    builtins.attrNames assetEntries
  )
)
++ map (n: "secrets/ 里有未登记的条目 ${n} (只允许 *.age / *.nix / Justfile / keys.json)") (
  builtins.filter (n: !okSecret n) secretFiles
)
