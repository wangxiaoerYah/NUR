{ inputs, stdenv }: inputs.nixos-anywhere.packages.${stdenv.hostPlatform.system}.default
