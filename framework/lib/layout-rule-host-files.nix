# 主机目录的文件命名约定: 只认 configuration.nix / meta.nix / service-<名>.nix / container-<名>.nix
{ root }:
let
  dir = root + "/hosts";
  hostDirs = if builtins.pathExists dir then builtins.attrNames (builtins.readDir dir) else [ ];
  allowed = [
    "configuration.nix"
    "meta.nix"
  ];
  okFile = n: builtins.elem n allowed || builtins.match "(service|container)-[a-z0-9-]+\\.nix" n != null;
in
builtins.concatMap (
  h:
  let
    entries = builtins.readDir "${dir}/${h}";
  in
  builtins.filter (x: x != null) (
    map (
      n:
      if entries.${n} != "regular" || okFile n then
        null
      else
        "主机 ${h} 里有不合命名约定的文件 (只允许 configuration.nix / meta.nix / service-<名>.nix / container-<名>.nix): ${dir}/${h}/${n}"
    ) (builtins.attrNames entries)
  )
) (builtins.filter (h: (builtins.readDir dir).${h} == "directory") hostDirs)
