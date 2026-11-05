# 目录分层约定: mod/ 与 mod/nixos/ 的顶层只放固定分层 (新增分层要同步这里与 skill module-style §2)
{ lib, root }:
let
  allowed = {
    mod = [
      "flake"
      "home-manager"
      "lib"
      "nixondroid"
      "nixos"
      "virtualisation"
    ];
    "mod/nixos" = [
      "framework"
      "services"
      "system"
    ];
  };
  at =
    rel:
    let
      dir = root + "/${rel}";
    in
    if !(builtins.pathExists dir) then
      [ ]
    else
      map (n: "${rel}/ 顶层多出 ${n} (允许: ${lib.concatStringsSep " / " allowed.${rel}}): ${dir}/${n}") (
        builtins.filter (n: (builtins.readDir dir).${n} == "directory" && !(builtins.elem n allowed.${rel})) (
          builtins.attrNames (builtins.readDir dir)
        )
      );
in
lib.concatMap at (builtins.attrNames allowed)
