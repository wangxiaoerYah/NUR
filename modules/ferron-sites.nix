{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.pfm.ferron;

  quote = s: "\"" + lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";

  indent =
    level: text:
    let
      pad = lib.concatStrings (lib.replicate level "    ");
    in
    pad + lib.replaceStrings [ "\n" ] [ "\n${pad}" ] text;

  baseSecureHeaders = {
    X-Content-Type-Options = "nosniff";
    Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload";
    X-Frame-Options = "SAMEORIGIN";
    X-XSS-Protection = "1; mode=block";
  };

  headerLines =
    site:
    lib.mapAttrsToList (name: value: "header ${name} ${quote value}") (
      baseSecureHeaders // lib.optionalAttrs site.noindex { X-Robots-Tag = "noindex, nofollow"; }
    )
    ++ map (name: "header -${name}") [
      "Server"
      "Via"
      "X-Powered-By"
    ];

  siteNames = key: site: if site.host == null then [ key ] else lib.filter (n: n != "") (lib.splitString " " site.host);

  renderSite =
    site:
    lib.concatStringsSep "\n" (
      lib.optional (site.tlsCert != null && site.tlsKey != null) "tls ${site.tlsCert} ${site.tlsKey}"
      ++ headerLines site
      ++ lib.optional (site.upstream != null) "proxy ${site.upstream}"
    );

  siteBlocks = lib.concatMap (
    key:
    let
      site = cfg.sites.${key};
      body = renderSite site;
    in
    map (name: ''
      ${name} {
      ${indent 1 body}
      }
    '') (siteNames key site)
  ) (builtins.attrNames cfg.sites);

  globalContent =
    lib.optionalString cfg.disableHttpPort "default_http_port false\n"
    + ''
      log /var/log/ferron/access.log {
          access_log_rotate_size 10485760
          access_log_rotate_keep 7
      }
      error_log /var/log/ferron/error.log {
          error_log_rotate_size 10485760
          error_log_rotate_keep 7
      }
    ''
    + cfg.globalConfig;

  confText = ''
    {
    ${indent 1 globalContent}
    }

    ${lib.concatStringsSep "\n" siteBlocks}
  '';
in
{
  options.pfm.ferron = {
    enable = lib.mkEnableOption "ferron site layer";

    disableHttpPort = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    globalConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    sites = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            upstream = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            noindex = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            tlsCert = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
            tlsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
          };
        }
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.ferron = {
      enable = true;
      package = pkgs.ferron-bin;
      openFirewall = false;
      configFile = pkgs.writeText "ferron.conf" confText;
    };
  };
}
