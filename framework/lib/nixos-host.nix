{
  fleet,
  inputs,
  lib,
  self,
  withSystem,
}:
let
  projectRoot = fleet.src;

  hostNames = builtins.attrNames (
    lib.filterAttrs (name: type: type == "directory" && name != "example" && !lib.hasPrefix "_" name) (
      builtins.readDir "${projectRoot}/hosts"
    )
  );
  # 事实文件过一遍 meta schema (mod/lib/meta-schema.nix): 字段名拼错 / 类型不符 / 未知字段
  # 都由 module 系统在求值期报错, 默认值也由 schema 给.
  evalMeta =
    name:
    (lib.evalModules {
      modules = [
        (import "${projectRoot}/mod/lib/meta-schema.nix" { inherit lib; })
        (import "${projectRoot}/hosts/${name}/meta.nix")
      ];
    }).config;
  # framework scenario (flake-checks 的 mkCheck) 用裸 meta, 也补一遍默认值, 写死的 attrs 不能靠 schema.
  withMetaDefaults =
    m:
    let
      schema = import "${projectRoot}/mod/lib/meta-schema.nix" { inherit lib; };
      defaults = lib.mapAttrs (_: o: o.default or null) schema.options;
    in
    defaults // m;
  hostsMeta = lib.genAttrs hostNames evalMeta;

  globalConfig = import (projectRoot + "/mod/lib/global-config.nix");
  modLib = import "${projectRoot}/mod/lib" { inherit lib projectRoot; };

  specialArgsFor =
    metaSet: name:
    modLib.specialArgs {
      inherit inputs projectRoot modLib;
      configSet = globalConfig;
      meta = metaSet.${name};
      allHostsMeta = metaSet;
      nodes = self.nixosConfigurations;
    };

  getAutoImports =
    hostPath:
    let
      files = builtins.readDir hostPath;
    in
    lib.mapAttrsToList (name: _: hostPath + "/${name}") (
      lib.filterAttrs (
        name: type:
        type == "regular"
        && lib.hasSuffix ".nix" name
        && !(lib.elem name [
          "configuration.nix"
          "meta.nix"
        ])
      ) files
    );

  mkHost =
    {
      name,
      meta,
      metaSet ? hostsMeta,
      extraModules ? [ ],
    }:
    let
      system = meta.hostPlatform;
      finalPkgs = withSystem system ({ pkgs, ... }: pkgs);
      nixpkgsInput = withSystem system ({ config, ... }: config.nixpkgs-options.pkgs.sourceInput);
    in
    nixpkgsInput.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.preservation.nixosModules.preservation
        inputs.home-manager.nixosModules.home-manager
        inputs.agenix.nixosModules.default
        inputs.self.nixosModules.colmena
        self.nixosModules.default
        (_: {
          mod.net.hostName = lib.mkForce name;
          home-manager.extraSpecialArgs = specialArgsFor metaSet name;
        })
      ]
      ++ extraModules;
      specialArgs = specialArgsFor metaSet name;
      pkgs = finalPkgs;
    };
in
{
  inherit
    hostNames
    hostsMeta
    modLib
    globalConfig
    mkHost
    getAutoImports
    ;
}
