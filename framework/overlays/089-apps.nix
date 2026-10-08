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
}
