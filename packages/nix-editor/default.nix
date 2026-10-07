{ inputs, stdenv }: inputs.nix-editor.packages.${stdenv.hostPlatform.system}.default
