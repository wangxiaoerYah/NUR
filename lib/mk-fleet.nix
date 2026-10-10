{ inputs }:
{
  src,
  systems ? [
    "x86_64-linux"
    "aarch64-linux"
  ],
  appsDir ? src + "/mod/flake/scripts",
  patchesDir ? src + "/mod/flake/patches",
  extraOverlays ? [ ],
  treefmt ? (import ../framework/lib/treefmt-default.nix),
}:
inputs.flake-parts.lib.mkFlake { inherit inputs; } (
  { ... }: {
    _module.args.fleet = {
      inherit
        src
        appsDir
        patchesDir
        systems
        treefmt
        extraOverlays
        ;
    };
    inherit systems;
    imports = [
      ../framework
      inputs.treefmt-nix.flakeModule
    ];
  }
)
