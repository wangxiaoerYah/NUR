_: _final: prev: {
  act = prev.act.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ prev.makeWrapper ];
    postFixup = ''

      wrapProgram $out/bin/act \
      --set DOCKER_HOST "unix:///run/podman/podman.sock"
    '';
  });

  wechat = prev.symlinkJoin {
    name = "wechat-${prev.wechat.version}";
    paths = [ prev.wechat ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/wechat
      makeWrapper ${prev.wechat}/bin/wechat $out/bin/wechat --set QT_IM_MODULE fcitx
    '';
  };

  google-chrome = prev.google-chrome.override { commandLineArgs = "--wayland-text-input-version=3"; };

  # GitHub runner 缺少 userns,无法运行
  protontricks = prev.protontricks.overrideAttrs (_: {
    doInstallCheck = false;
  });

  # 在 nix-on-droid 上 /etc 全是指向 store 的符号链接, 上游两条测试断言的是 /etc/passwd 不在 store
  mcp-nixos = prev.mcp-nixos.overridePythonAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_etc_passwd_rejected"
      "test_invalid_path_outside_store"
    ];
  });
}
