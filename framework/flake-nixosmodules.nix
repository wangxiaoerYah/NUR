_localFlake: { fleet, ... }: {
  flake = {
    nixosModules.default = import (fleet.src + "/mod/nixos/default.nix");
  };
}
