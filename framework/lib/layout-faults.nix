{ lib }:
{ root, dirs }:
let
  validFile = n: builtins.match "[a-z0-9][a-z0-9.-]*\\.nix" n != null;
  validDir = n: builtins.match "[a-z0-9_][a-z0-9._-]*" n != null;

  dirFaults =
    dir: name:
    let
      entries = builtins.readDir dir;
      names = builtins.attrNames entries;
      files = builtins.filter (n: entries.${n} == "regular") names;
      subdirs = builtins.filter (n: entries.${n} == "directory") names;
      nixs = builtins.filter (n: lib.hasSuffix ".nix" n) files;
      plain = builtins.filter (n: !(lib.hasSuffix ".nix" n)) files;
      has = n: builtins.elem n nixs;
      badNamed = builtins.filter (n: !validFile n) nixs;
    in
    builtins.filter (x: x != null) [
      (if !validDir name then "目录名不合规 (只允许小写字母 / 数字 / 点 / 连字符): ${dir}" else null)
      (if badNamed != [ ] then "文件名不合规 ${builtins.toJSON badNamed}: ${dir}" else null)
      (
        if has "options.nix" && !(has "default.nix") && !(has "${name}.nix") then
          "选项没有本体 (目录里既无 default.nix 也无 ${name}.nix): ${dir}"
        else
          null
      )
      (if has "default.nix" && has "${name}.nix" then "default.nix 与 ${name}.nix 并存: ${dir}" else null)
      (if nixs != [ ] && builtins.elem ".gitkeep" files then ".gitkeep 与 .nix 并存 (占位无意义): ${dir}" else null)
      (
        if builtins.length subdirs == 1 && nixs == [ ] && plain == [ ] then
          "单子目录中间层 (内容应上提一层): ${dir}/${builtins.head subdirs}"
        else
          null
      )
    ];

  walk =
    rel:
    let
      dir = root + "/${rel}";
    in
    if !builtins.pathExists dir then
      [ ]
    else
      dirFaults dir (baseNameOf rel)
      ++ builtins.concatMap (n: walk "${rel}/${n}") (
        builtins.filter (n: (builtins.readDir dir).${n} == "directory") (builtins.attrNames (builtins.readDir dir))
      );

  hostFaults =
    let
      dir = root + "/hosts";
    in
    if !builtins.pathExists dir then
      [ ]
    else
      builtins.concatMap (
        h:
        builtins.filter (x: x != null) (
          map (f: if builtins.pathExists "${dir}/${h}/${f}" then null else "主机 ${h} 缺 ${f}: ${dir}/${h}") [
            "meta.nix"
            "configuration.nix"
          ]
        )
      ) (builtins.filter (n: (builtins.readDir dir).${n} == "directory") (builtins.attrNames (builtins.readDir dir)));
in
builtins.concatMap walk dirs ++ (if builtins.elem "hosts" dirs then hostFaults else [ ])
