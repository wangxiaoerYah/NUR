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
    headers:
    (lib.mapAttrsToList (name: value: "header ${name} ${quote value}") headers.set)
    ++ (lib.mapAttrsToList (name: value: "header +${name} ${quote value}") headers.add)
    ++ (map (name: "header -${name}") headers.unset);

  siteNames = key: site: if site.host == null then [ key ] else lib.filter (n: n != "") (lib.splitString " " site.host);

  renderProxy =
    site: extra:
    let
      p = site.proxy;
      upstreamFields =
        lib.optional (p.upstreamLimit != null) "limit ${toString p.upstreamLimit}"
        ++ lib.optional (p.upstreamIdleTimeout != null) "idle_timeout \"${p.upstreamIdleTimeout}\""
        ++ lib.optional (p.upstreamConnectionTimeout != null) "connection_timeout \"${p.upstreamConnectionTimeout}\"";
      upstreamBody = lib.concatStringsSep "\n" upstreamFields;
      lines = [
        ("upstream ${site.upstream}" + lib.optionalString (upstreamFields != [ ]) " {\n${indent 1 upstreamBody}\n}")
      ]
      ++ lib.optional (p.keepalive != null) "keepalive ${lib.boolToString p.keepalive}"
      ++ lib.optional (p.http2 != null) "http2 ${lib.boolToString p.http2}"
      ++ lib.optional (p.maxRetries != null) "max_retries_per_upstream ${toString p.maxRetries}"
      ++ lib.optional (p.retryInterval != null) "retry_interval \"${p.retryInterval}\""
      ++ lib.optional (extra != "") extra;
    in
    "proxy {\n${indent 1 (lib.concatStringsSep "\n" lines)}\n}";

  renderSite =
    site:
    let
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
      ++ lib.optional site.dynamicCompressed "dynamic_compressed"
      ++ headerLines headers
      ++ lib.optional (site.upstream != null) (renderProxy site site.proxyExtraConfig)
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

  httpBlock =
    "http {\n"
    + indent 1 (
      lib.concatStringsSep "\n" ([ "protocols h1 h2 h3" ] ++ lib.optional (cfg.timeout != null) ''timeout "${cfg.timeout}"'')
    )
    + "\n}";

  globalContent =
    lib.optionalString cfg.disableHttpPort "default_http_port false\n"
    + lib.optionalString (cfg.proxyConcurrentConns != null) "concurrent_conns ${toString cfg.proxyConcurrentConns}\n"
    + httpBlock
    + "\n"
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
      default = false;
    };

    disableHttpPort = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    timeout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    proxyConcurrentConns = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
    };

    proxyUpstreamLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
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
            proxy = {
              keepalive = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = true;
              };
              http2 = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = false;
              };
              maxRetries = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = 1;
              };
              retryInterval = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              upstreamLimit = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = cfg.proxyUpstreamLimit;
              };
              upstreamIdleTimeout = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "60s";
              };
              upstreamConnectionTimeout = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "2s";
              };
            };
            root = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            index = lib.mkOption {
              type = lib.types.nullOr (lib.types.listOf lib.types.str);
              default = null;
            };
            noindex = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            dynamicCompressed = lib.mkOption {
              type = lib.types.bool;
              default = cfg.dynamicCompressed;
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
