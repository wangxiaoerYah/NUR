{ self }: _final: prev: self.packages.${prev.stdenv.hostPlatform.system} or { }
