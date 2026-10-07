_localFlake: { fleet, lib, ... }: {
  perSystem =
    { pkgs, inputs', ... }:
    let
      commands = builtins.listToAttrs (
        map (_n: {
          name = builtins.elemAt (lib.splitString "." _n) 0;
          value = fleet.appsDir + "/" + _n;
        }) (builtins.attrNames (builtins.readDir fleet.appsDir))
      );

      pkg = _path: pkgs.callPackage _path { inherit pkgs inputs'; };
    in
    {
      apps = builtins.mapAttrs (
        _name: _path:
        let
          scriptDrv = pkgs.writeShellScriptBin _name (pkg _path);
        in
        {
          type = "app";
          program = "${scriptDrv}/bin/${_name}";
          meta = {
            description = "Custom executable for ${_name}";
          };
        }
      ) commands;
    };
}
