{
  cacert,
  coreutils,
  curl,
  dockerTools,
  git,
  jq,
  nix,
  writeShellApplication,
}:
let
  bot = writeShellApplication {
    name = "nur-bot";
    runtimeInputs = [
      coreutils
      curl
      git
      jq
      nix
    ];
    text = builtins.readFile ./bot.sh;
  };
in
dockerTools.buildLayeredImage {
  name = "ghcr.io/wangxiaoeryah/nur-bot";
  tag = "main";
  includeNixDB = true;
  contents = [
    bot
    cacert
  ];
  config = {
    Entrypoint = [ "${bot}/bin/nur-bot" ];
    Env = [
      "HOME=/tmp"
      "NIX_CONFIG=experimental-features = nix-command flakes\nbuild-users-group ="
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
