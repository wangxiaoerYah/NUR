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
    edgeone = "eo-connecting-ip";
  };

  realIpFor =
    site: if site.cdn == null || site.cdn == "none" then "{{remote.ip}}" else "{{request.header.${cdnHeader.${site.cdn}}}";

  baseSecureHeaders = {
    X-Content-Type-Options = "nosniff";
    Strict-Transport-Security = "max-age=31536000; includeSubDomains; preload";
    X-Frame-Options = "SAMEORIGIN";
    X-XSS-Protection = "1; mode=block";
  };

  globalConfig = ''
    log /var/log/ferron/access.log {
        access_log_rotate_size 10485760
        access_log_rotate_keep 7
    }
    error_log /var/log/ferron/error.log {
        error_log_rotate_size 10485760
        error_log_rotate_keep 7
    }
  ''
  + lib.optionalString cfg.dynamicCompressed "dynamic_compressed\n"
  + cfg.globalConfig;

  renderSite =
    site:
    let
      realIp = realIpFor site;
      proxyExtraConfig = lib.concatStrings (
        lib.optionalString (site.upstream != null) ''
          request_header X-Real-IP "${realIp}"
          request_header X-Forwarded-For "${realIp}"
          request_header X-Forwarded-Proto "https"
        ''
        + site.proxyExtraConfig
      );
    in
    {
      root = site.root;
      index = site.index;
      proxy = site.upstream;
      inherit proxyExtraConfig;
      spaFallback = site.spaFallback;
      httpsRedirect = site.httpsRedirect;
      tls = {
        enable = if site.tlsEnable == null then site.tlsCert != null else site.tlsEnable;
        cert = site.tlsCert;
        key = site.tlsKey;
      };
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
      config = lib.concatStringsSep "\n" (
        lib.optional (site.timeout != null) ''
          http {
              timeout "${site.timeout}"
          }
        ''
        ++ [ site.config ]
      );
    };

  siteNames = key: site: if site.host == null then [ key ] else lib.filter (n: n != "") (lib.splitString " " site.host);

  hostDefs = lib.flatten (
    lib.mapAttrsToList (key: site: map (name: { ${name} = renderSite site; }) (siteNames key site)) cfg.sites
  );
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

    keepDefaultVhost = lib.mkOption {
      type = lib.types.bool;
      default = false;
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
                  "edgeone"
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
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            tlsKey = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
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
      inherit (cfg) package extraConfig;
      inherit globalConfig;
      hosts = lib.mkMerge hostDefs;
    };

    services.ferron.hosts."*:80".config = lib.mkIf (!cfg.keepDefaultVhost) (lib.mkForce "");
  };
}
