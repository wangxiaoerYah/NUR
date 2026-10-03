{ ferron, pkgs }: ferron.packages.${pkgs.stdenv.hostPlatform.system}.ferron-bin
