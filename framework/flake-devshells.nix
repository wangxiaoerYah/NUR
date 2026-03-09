_localFlake: { lib, ... }: {
  perSystem = { pkgs, self', ... }: {
    devShells.default =
      (
        apps:
        pkgs.mkShell {
          buildInputs =
            (lib.mapAttrsToList (
              n: _:
              pkgs.writeShellScriptBin n ''
                exec nix run .#${n} -- "$@"
              ''
            ) apps)
            ++ (with pkgs; [
              statix
              deadnix
              nil
              shellcheck
              nix-diff
              just
            ]);
        }
      )
        self'.apps;
  };
}
