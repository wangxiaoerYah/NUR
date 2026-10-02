# 挂本 flake 自己的产物, 不用宿主的 nixpkgs 重编一遍 —— 重编出来的 store 路径与 CI 缓存里的完全不同
# (实测: 那样 `windows-fonts` 会重下 3.88 GB 的 Windows 安装映像).
#
# 本 flake 只出 x86_64-linux 与 aarch64-linux; 别处 (比如 Steam 用的 i686-linux) 也会被套上这个
# overlay, 那时没有对应产物, 就不挂 (落回空集, 而不是 eval 报 attribute missing).
{ self }: _final: prev: self.packages.${prev.stdenv.hostPlatform.system} or { }
