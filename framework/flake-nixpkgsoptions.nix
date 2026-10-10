_localFlake:
{
  fleet,
  inputs,
  lib,
  ...
}:
{
  perSystem = _: {
    nixpkgs-options = {
      pkgs =
        { config, ... }:
        let
          isStable = config.sourceInput.outPath == inputs.nixpkgs-stable.outPath;
          patchDir = fleet.patchesDir + (if isStable then "/stable" else "/unstable");
          autoPatches =
            if builtins.pathExists patchDir then
              lib.mapAttrsToList (name: _: patchDir + "/${name}") (
                lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".patch" name) (builtins.readDir patchDir)
              )
            else
              [ ];

        in
        {

          patches = autoPatches;
          permittedInsecurePackages = [ "ventoy-1.1.17" ];

          overlays = [
            inputs.agenix.overlays.default
            inputs.nur.overlays.default
            inputs.self.overlays.default
          ]
          ++ (import ./nixpkgs-overlays { inherit inputs; })
          ++ fleet.extraOverlays;

          settings = {
            android_sdk.accept_license = true;
          };
        };
    };
  };
}
