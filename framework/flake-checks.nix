_localFlake:
{
  fleet,
  inputs,
  lib,
  config,
  withSystem,
  ...
}:
let
  hostLib = import ./nixos-host.nix {
    self = config.flake;
    inherit
      fleet
      inputs
      lib
      withSystem
      ;
  };

  wants =
    what: actual: expected:
    if actual == expected then null else "${what}: 期望 ${builtins.toJSON expected}, 实际 ${builtins.toJSON actual}";

  inventoryFaults =
    let
      root = fleet.src;
      meta = hostLib.hostsMeta;
      names = builtins.attrNames meta;
      keys = builtins.fromJSON (builtins.readFile (root + "/secrets/keys.json"));
      rules = builtins.attrNames (import (root + "/secrets/secrets.nix"));

      validName = n: builtins.match "[a-z0-9]?([a-z0-9-]*[a-z0-9])?" n != null;
      badNames = builtins.filter (n: !validName n) names;

      hasPub = n: lib.hasPrefix "ssh-" (meta.${n}."SSH-ED25519" or "");
      expectKeys = lib.listToAttrs (map (n: lib.nameValuePair n meta.${n}."SSH-ED25519") (builtins.filter hasPub names));
      keyFaults =
        (map (n: "keys.json 缺 ${n}") (lib.filter (n: !keys ? ${n}) (builtins.attrNames expectKeys)))
        ++ (map (n: "keys.json 里 ${n} 与 meta.nix 的 SSH-ED25519 不一致") (
          builtins.filter (n: keys ? ${n} && keys.${n} != expectKeys.${n}) (builtins.attrNames keys)
        ))
        ++ (map (k: "keys.json 多一条 ${k} (没有这台主机)") (lib.filter (k: !expectKeys ? ${k}) (builtins.attrNames keys)));

      vnetHosts = lib.filter (n: lib.elem "vnet" (meta.${n}.TAG or [ ])) names;
      ruleOf = h: "wg_${h}.age";
      wgFaults =
        (map (h: "vnet 主机 ${h} 缺 secrets/${ruleOf h}") (
          builtins.filter (h: !builtins.pathExists (root + "/secrets/${ruleOf h}")) vnetHosts
        ))
        ++ (map (h: "vnet 主机 ${h} 在 secrets.nix 里没有规则 (它解不开别人的密钥)") (builtins.filter (h: !lib.elem (ruleOf h) rules) vnetHosts))
        ++ (map (r: "secrets.nix 残留规则 ${r} (对应主机已不是 vnet 或已不在 hosts/)") (
          builtins.filter (
            r:
            let
              h = lib.removePrefix "wg_" (lib.removeSuffix ".age" r);
            in
            h != "psk" && !lib.elem h vnetHosts
          ) (builtins.filter (r: lib.hasPrefix "wg_" r) rules)
        ));
    in
    builtins.filter (x: x != null) (
      (map (n: "主机目录名 ${n} 不是合法 hostname (只允许小写字母 / 数字 / 连字符)") badNames) ++ keyFaults ++ wgFaults
    );

  scenarios = {
    laptop-intel-nvidia = {
      gpu = {
        primary = "i915";
        cards = {
          "i915" = {
            vendor = "intel";
            busId = "PCI:0:2:0";
          };
          "rtx4060" = {
            vendor = "nvidia";
            driver = "nvidia";
            arch = "ada";
            busId = "PCI:1:0:0";
          };
        };
      };
      expect = cfg: [
        (wants "videoDrivers" cfg.services.xserver.videoDrivers [ "nvidia" ])
        (wants "branch" cfg.hardware.nvidia.branch "stable")
        (wants "open" cfg.hardware.nvidia.open true)
        (wants "prime.offload" cfg.hardware.nvidia.prime.offload.enable true)
        (wants "prime.nvidiaBusId" cfg.hardware.nvidia.prime.nvidiaBusId "PCI:1:0:0")
        (wants "prime.intelBusId" cfg.hardware.nvidia.prime.intelBusId "PCI:0:2:0")
        (wants "prime.offload.enableOffloadCmd" cfg.hardware.nvidia.prime.offload.enableOffloadCmd true)
        (wants "powerManagement.finegrained" cfg.hardware.nvidia.powerManagement.finegrained true)
        (wants "initrd 含 i915" (lib.elem "i915" cfg.boot.initrd.kernelModules) true)
        (wants "LIBVA_DRIVER_NAME" cfg.environment.sessionVariables.LIBVA_DRIVER_NAME "iHD")
      ];
    };

    apu-amd-nvidia = {
      gpu = {
        cards = {
          "apu" = {
            vendor = "amd";
            integrated = true;
            busId = "PCI:5:0:0";
          };
          "rtx4060" = {
            vendor = "nvidia";
            driver = "nvidia";
            arch = "ada";
            busId = "PCI:1:0:0";
          };
        };
      };
      expect = cfg: [
        (wants "prime.offload" cfg.hardware.nvidia.prime.offload.enable true)
        (wants "prime.amdgpuBusId" cfg.hardware.nvidia.prime.amdgpuBusId "PCI:5:0:0")
        (wants "prime.nvidiaBusId" cfg.hardware.nvidia.prime.nvidiaBusId "PCI:1:0:0")
        (wants "initrd 含 amdgpu" (lib.elem "amdgpu" cfg.boot.initrd.kernelModules) true)
        (wants "LIBVA_DRIVER_NAME 不设" (cfg.environment.sessionVariables.LIBVA_DRIVER_NAME or null) null)
      ];
    };

    desktop-dual-discrete = {
      gpu = {
        cards = {
          "rx-570" = {
            vendor = "amd";
          };
          "rtx4060" = {
            vendor = "nvidia";
            driver = "nvidia";
            arch = "ada";
          };
        };
      };
      expect = cfg: [
        (wants "prime.offload" cfg.hardware.nvidia.prime.offload.enable false)
        (wants "prime.sync" cfg.hardware.nvidia.prime.sync.enable false)
        (wants "videoDrivers" cfg.services.xserver.videoDrivers [ "nvidia" ])
        (wants "initrd 含 amdgpu" (lib.elem "amdgpu" cfg.boot.initrd.kernelModules) true)
      ];
    };

    single-maxwell = {
      gpu.cards."gtx750ti" = {
        vendor = "nvidia";
        driver = "nvidia";
        arch = "maxwell";
      };
      expect = cfg: [
        (wants "branch" cfg.hardware.nvidia.branch "legacy_580")
        (wants "open" cfg.hardware.nvidia.open false)
        (wants "nouveau 被拉黑" (lib.elem "nouveau" cfg.boot.blacklistedKernelModules) true)
        (wants "prime.offload" cfg.hardware.nvidia.prime.offload.enable false)
      ];
    };

    single-blackwell-container = {
      gpu = {
        cards."rtx5090" = {
          vendor = "nvidia";
          driver = "nvidia";
          arch = "blackwell";
        };
        containerToolkit = true;
      };
      expect = cfg: [
        (wants "branch" cfg.hardware.nvidia.branch "latest")
        (wants "open" cfg.hardware.nvidia.open true)
        (wants "containerToolkit" cfg.hardware.nvidia-container-toolkit.enable true)
      ];
    };

    integrated-only = {
      gpu = { };
      expect = cfg: [
        (wants "hardware.graphics.enable" cfg.hardware.graphics.enable true)
        (wants "videoDrivers 保持默认" cfg.services.xserver.videoDrivers [
          "modesetting"
          "fbdev"
        ])
        (wants "initrd 不含显卡模块" (lib.any (
          m:
          lib.elem m [
            "i915"
            "amdgpu"
            "nouveau"
          ]
        ) cfg.boot.initrd.kernelModules) false)
      ];
    };

    nvidia-without-arch = {
      gpu.cards."rtx4060" = {
        vendor = "nvidia";
        driver = "nvidia";
      };
      expect = _: [ ];
      expectFailure = true;
    };

    prime-without-bus-id = {
      gpu = {
        cards = {
          "i915" = {
            vendor = "intel";
          };
          "rtx4060" = {
            vendor = "nvidia";
            driver = "nvidia";
            arch = "ada";
          };
        };
      };
      expect = _: [ ];
      expectFailure = true;
    };
  };

  frameworkScenarios = {
    vnet-not-server = {
      meta = {
        TAG = [ "vnet" ];
        WG-PUB = "placeholder";
        IPv4 = [ "10.99.0.9/24" ];
      };
      expectFailure = true;
      expectFailureMessage = "vnet 只能叠在 server 上";
    };
    vnet-without-wg-key = {
      meta = {
        TAG = [
          "server"
          "vnet"
        ];
        IPv4 = [ "10.99.0.9/24" ];
      };
      expectFailure = true;
      expectFailureMessage = "没有 WG-PUB";
    };
    vnet-without-static-address = {
      meta = {
        TAG = [
          "server"
          "vnet"
        ];
        WG-PUB = "placeholder";
      };
      expectFailure = true;
      expectFailureMessage = "没有任何静态地址";
    };

    tag-not-in-vocabulary = {
      meta = {
        TAG = [
          "server"
          "sevrer"
        ];
        IPv4 = [ "10.99.0.9/24" ];
      };
      expect = cfg: [
        (wants "只有那一条词表 warning" (builtins.length (builtins.filter (w: lib.hasInfix "词表" w) cfg.warnings)) 1)
        (wants "warning 点到主机名与那个 tag" (lib.any (w: lib.hasInfix "sevrer" w) cfg.warnings) true)
        (wants "server 仍然有 sshd" cfg.services.openssh.enable true)
      ];
    };
  };

  templateScenario = {
    template-example = {
      meta = {
        TAG = [ "server" ];
        IPv4 = [ "192.0.2.10/24" ];
        IPv4-Gateway = "192.0.2.1";
        IPv6 = [ "2001:db8::10/64" ];
        IPv6-Gateway = "2001:db8::1";
      };
      modules = [
        "${fleet.src}/hosts/example/configuration.nix"
        "${fleet.src}/hosts/example/container-example.nix"
        "${fleet.src}/hosts/example/service-nginx.nix"
      ];
      expect = cfg: [
        (wants "nginx 前端开关" cfg.mod.services.nginx.enable true)
        (wants "站点进了 mod.services.nginx" (cfg.mod.services.nginx.sites ? "example.com") true)
        (wants "vhost 指向命名上游" cfg.services.nginx.virtualHosts."example.com".locations."/".proxyPass "http://example-com")
        (wants "上游块带长连接池" (lib.hasInfix "keepalive " cfg.services.nginx.upstreams.example-com.extraConfig) true)
        (wants "容器名按框架推成 hostname" (cfg.virtualisation.oci-containers.containers.example-nginx.hostname or ""
        ) "example-nginx.containers.template-example.internal")
      ];
    };
  };

  mkCheck =
    pkgs: system: name: sc:
    let
      meta = {
        CPU_CORES = 8;
        hostPlatform = system;
      }
      // (sc.meta or { });
      metaSet = hostLib.hostsMeta // {
        ${name} = meta;
      };
      cfg =
        (hostLib.mkHost {
          inherit name meta metaSet;
          extraModules = [
            { mod.net.useDHCP = true; }
          ]
          ++ (sc.modules or [ ])
          ++ lib.optional (sc ? gpu) {
            mod.hardware.gpu = sc.gpu // {
              enable = true;
            };
          };
        }).config;

      assertionsOk = lib.all (a: a.assertion) cfg.assertions;
      failedMessages =
        let
          r = builtins.tryEval (map (a: a.message) (builtins.filter (a: !a.assertion) cfg.assertions));
        in
        if r.success then r.value else [ "(断言消息本身求值失败)" ];
      assertionsHeld = builtins.tryEval (if assertionsOk then true else throw "assertions failed");
      failures = builtins.filter (x: x != null) (
        (if sc ? expect then sc.expect cfg else [ ])
        ++ (
          if sc.expectFailure or false then
            (
              if assertionsHeld.success then
                [ "期望断言拦下这组配置, 但它通过了" ]
              else if sc ? expectFailureMessage && !(lib.any (m: lib.hasInfix sc.expectFailureMessage m) failedMessages) then
                [ "断言失败了, 但不是因为「${sc.expectFailureMessage}」:" ] ++ failedMessages
              else
                [ ]
            )
          else
            (if assertionsHeld.success then [ ] else [ "断言不该失败, 但它失败了:" ] ++ failedMessages)
        )
      );
    in
    builtins.seq (if failures == [ ] then true else throw "场景 ${name} 不满足:\n${lib.concatStringsSep "\n" failures}") (
      pkgs.runCommand "scenario-check-${name}" { } ''
        touch $out
      ''
    );
  lintChecks = pkgs: {
    lint-statix = pkgs.runCommand "lint-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
      statix check ${fleet.src}
      touch $out
    '';
    lint-deadnix = pkgs.runCommand "lint-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
      deadnix --fail --no-underscore ${fleet.src}
      touch $out
    '';
    lint-nil = pkgs.runCommand "lint-nil" { nativeBuildInputs = [ pkgs.nil ]; } ''
      bad=0
      for f in $(find ${fleet.src} -name '*.nix'); do
        msg=$(nil diagnostics "$f" 2>&1 || true)
        if printf '%s' "$msg" | grep -qE 'warning\[|error\['; then
          printf '\n%s\n%s\n' "$f" "$msg" >&2
          bad=1
        fi
      done
      if [ "$bad" != 0 ]; then
        exit 1
      fi
      touch $out
    '';
    lint-nixf = pkgs.runCommand "lint-nixf" { nativeBuildInputs = [ pkgs.nixf-diagnose ]; } ''
      nixf-diagnose $(find ${fleet.src} -name '*.nix')
      touch $out
    '';
  };
  inventoryChecks = pkgs: {
    inventory-sync =
      builtins.seq
        (
          if inventoryFaults == [ ] then
            true
          else
            throw "机群清单不一致 (主机名 / keys.json / wg 密钥):
${lib.concatStringsSep "
" inventoryFaults}"
        )
        (
          pkgs.runCommand "check-inventory-sync" { } ''
            touch $out
          ''
        );
  };
in
{
  perSystem = { pkgs, system, ... }: {
    checks =
      lintChecks pkgs
      // inventoryChecks pkgs
      // lib.mapAttrs' (name: sc: lib.nameValuePair "gpu-${name}" (mkCheck pkgs (sc.meta.hostPlatform or system) name sc)) (
        lib.filterAttrs (_: sc: (sc.meta.hostPlatform or system) == system) scenarios
      )
      // lib.mapAttrs' (
        name: sc: lib.nameValuePair "framework-${name}" (mkCheck pkgs (sc.meta.hostPlatform or system) name sc)
      ) (lib.filterAttrs (_: sc: (sc.meta.hostPlatform or system) == system) (frameworkScenarios // templateScenario));
  };
}
