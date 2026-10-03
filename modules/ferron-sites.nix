{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.pfm.ferron;

  cdnHeader = {
    cloudflare = "cf-connecting-ip";
  };

  realIpFor =
    site: if site.cdn == null || site.cdn == "none" then "{{remote.ip}}" else "{{request.header.${cdnHeader.${site.cdn}}}}";

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
    headers:
    (lib.mapAttrsToList (name: value: "header ${name} ${quote value}") headers.set)
    ++ (lib.mapAttrsToList (name: value: "header +${name} ${quote value}") headers.add)
    ++ (map (name: "header -${name}") headers.unset);

  siteNames = key: site: if site.host == null then [ key ] else lib.filter (n: n != "") (lib.splitString " " site.host);

  renderSite =
    site:
    let
      realIp = realIpFor site;
      proxyLines =
        lib.optionalString (site.upstream != null) ''
          request_header X-Real-IP "${realIp}"
          request_header X-Forwarded-For "${realIp}"
          request_header X-Forwarded-Proto "https"
        ''
        + site.proxyExtraConfig;
      headers = {
        set =
          (lib.optionalAttrs site.secureHeaders baseSecureHeaders)
          // (lib.optionalAttrs site.noindex { X-Robots-Tag = "noindex, nofollow"; })
          // site.headers.set;
        add = site.headers.add;
        unset =
          lib.optionals site.secureHeaders [
            "Server"
            "Via"
            "X-Powered-By"
          ]
          ++ site.headers.unset;
      };
    in
    lib.concatStringsSep "\n" (
      lib.optional (site.tlsEnable == false || (site.tlsCert == null && site.tlsEnable == null)) "tls false"
      ++ lib.optional (site.tlsCert != null && site.tlsKey != null) "tls ${site.tlsCert} ${site.tlsKey}"
      ++ lib.optional (site.httpsRedirect != null) "https_redirect ${lib.boolToString site.httpsRedirect}"
      ++ lib.optional (site.root != null) "root ${site.root}"
      ++ lib.optional (site.index != null) "index ${lib.concatStringsSep " " site.index}"
      ++ lib.optional site.spaFallback ''
        rewrite r"^/.*" "/" {
            last
            directory false
            file false
        }
      ''
      ++ lib.optional cfg.dynamicCompressed "dynamic_compressed"
      ++ headerLines headers
      ++ lib.optional (site.upstream != null) (
        "proxy ${site.upstream}" + lib.optionalString (proxyLines != "") " {\n${indent 1 proxyLines}\n}"
      )
      ++ lib.optional (site.timeout != null) ''
        http {
            timeout "${site.timeout}"
        }
      ''
      ++ lib.optional (site.config != "") site.config
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

  globalContent = ''
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
  ''
  + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}\n";
in
{
  options.pfm.ferron = {
    enable = lib.mkEnableOption "ferron site layer";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ferron-bin;
    };

    dynamicCompressed = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    globalConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    extraConfig = lib.mkOption {
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
            root = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            index = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
            };
            cdn = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "none"
                  "cloudflare"
                ]
              );
              default = null;
            };
            noindex = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            secureHeaders = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            tlsEnable = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
            };
            tlsCert = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
            tlsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
            httpsRedirect = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
            };
            spaFallback = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            timeout = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            headers = {
              set = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
              };
              add = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
              };
              unset = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
            };
            proxyExtraConfig = lib.mkOption {
              type = lib.types.lines;
              default = "";
            };
            config = lib.mkOption {
              type = lib.types.lines;
              default = "";
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
      inherit (cfg) package;
      openFirewall = false;
      configFile = pkgs.writeText "ferron.conf" confText;
    };
  };
}
