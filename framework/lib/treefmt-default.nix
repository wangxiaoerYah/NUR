{ pkgs, ... }: {
  projectRootFile = "flake.nix";
  programs = {
    nixfmt = {
      enable = pkgs.lib.meta.availableOn pkgs.stdenv.buildPlatform pkgs.nixfmt.compiler;
      package = pkgs.nixfmt;
      strict = true;
      width = 120;
      priority = 3;
    };
    shfmt = {
      enable = true;
      indent_size = 2;
    };
    shellcheck.enable = true;
    taplo.enable = true;
    prettier = {
      enable = true;
      settings = {
        tabWidth = 2;
        useTabs = false;
        printWidth = 120;
      };
    };
    just.enable = true;
    fish_indent.enable = true;
    statix = {
      enable = true;
      priority = 1;
    };
    deadnix = {
      enable = true;
      no-underscore = true;
      priority = 2;
    };
  };
  settings.formatter = {
    shellcheck.options = [
      "-s"
      "bash"
    ];
  };
}
