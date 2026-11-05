# mod/lib 只放纯函数 / 纯数据: 外层 lambda 不得收 config / pkgs (收了就不再是纯函数, 也不能在特殊场景复用)
{ lib, root }:
let
  dir = root + "/mod/lib";
  forbidden = [
    "config"
    "pkgs"
  ];
  files = if builtins.pathExists dir then builtins.attrNames (builtins.readDir dir) else [ ];
in
builtins.concatMap (
  n:
  let
    value = import "${dir}/${n}";
    args = if builtins.isFunction value then builtins.attrNames (builtins.functionArgs value) else [ ];
    bad = builtins.filter (a: builtins.elem a forbidden) args;
  in
  lib.optional (bad != [ ]) "mod/lib 只放纯函数/纯数据, 但 ${n} 收了 ${builtins.concatStringsSep ", " bad}"
) (builtins.filter (n: lib.hasSuffix ".nix" n) files)
