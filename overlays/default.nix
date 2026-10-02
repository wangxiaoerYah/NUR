# 挂本 flake 自己的产物, 不用宿主的 nixpkgs 重编一遍 —— 重编出来的 store 路径与 CI 缓存里的完全不同
# (实测: 那样 `windows-fonts` 会重下 3.88 GB 的 Windows 安装映像).
{ self }: _final: prev: self.packages.${prev.stdenv.hostPlatform.system}
