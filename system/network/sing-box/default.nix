{
  config,
  pkgs,
  me,
  ...
}:
let
  # Reality handshake target / fallback site
  realitySni = "gateway.icloud.com";
  realityPublicKey = "333ml7s4Nj9yV2jz3ZL1J-G_1OX1bb6Yk-9ALFOsqB0";
  realityPort = 443;
  hy2Port = 8443;
  subPort = 2080;
  subDir = "/var/lib/sing-box-sub";

  # Hysteria 2 certificate/key are kept in sops so a new machine needs no manual cert generation
  certFile = config.sops.secrets.singbox_hy2_cert.path;
  keyFile = config.sops.secrets.singbox_hy2_key.path;

  secretPath = name: { _secret = config.sops.secrets.${name}.path; };

  mkHy2 =
    { tag, port }:
    {
      type = "hysteria2";
      inherit tag;
      listen = "::";
      listen_port = port;
      users = [
        {
          password = secretPath "singbox_hy2_password";
        }
      ];
      tls = {
        enabled = true;
        certificate_path = certFile;
        key_path = keyFile;
      };
      masquerade = "https://bing.com";
    };
in
{
  sops.secrets = {
    singbox_uuid.owner = me.userName;
    singbox_reality_private_key = { };
    singbox_hy2_password.owner = me.userName;
    singbox_hy2_cert = {
      owner = "sing-box";
      mode = "0444";
    };
    singbox_hy2_key.owner = "sing-box";
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "singbox-links" ''
      set -euo pipefail

      # Auto sudo if cannot read root-only secret files
      if [ "$(id -u)" -ne 0 ] && { [ ! -r "${config.sops.secrets.singbox_uuid.path}" ] || [ ! -r "${certFile}" ]; }; then
        exec sudo "$0" "$@"
      fi

      uuid=$(cat ${config.sops.secrets.singbox_uuid.path})
      hy2=$(cat ${config.sops.secrets.singbox_hy2_password.path})
      hy2_enc=$(printf %s "$hy2" | ${pkgs.jq}/bin/jq -sRr @uri)
      cert_sha256=$(${pkgs.openssl}/bin/openssl x509 -noout -fingerprint -sha256 -in "${certFile}" 2>/dev/null | cut -d= -f2 | tr -d :)

      # Discover all public IP addresses (IPv4 & IPv6)
      if [ "$#" -gt 0 ]; then
        hosts=("$@")
      else
        mapfile -t local_ips < <(${pkgs.iproute2}/bin/ip -j -4 addr show scope global | ${pkgs.jq}/bin/jq -r '.[].addr_info[].local')
        hosts=()
        for ip in "''${local_ips[@]}"; do
          pub_ip=$(${pkgs.curl}/bin/curl -4s --interface "$ip" --max-time 3 https://icanhazip.com 2>/dev/null || true)
          if [ -n "$pub_ip" ]; then
            hosts+=("$pub_ip")
          fi
        done
        if [ "''${#hosts[@]}" -eq 0 ]; then
          fallback=$(${pkgs.curl}/bin/curl -4s --max-time 3 https://icanhazip.com 2>/dev/null || echo "127.0.0.1")
          hosts+=("$fallback")
        fi

        # Discover public IPv6 addresses
        mapfile -t v6_ips < <(${pkgs.iproute2}/bin/ip -j -6 addr show scope global | ${pkgs.jq}/bin/jq -r '.[].addr_info[]? | select(.scope == "global" and .local != null) | .local')
        for ip6 in "''${v6_ips[@]}"; do
          hosts+=("$ip6")
        done
      fi

      # Deduplicate hosts
      mapfile -t unique_hosts < <(printf "%s\n" "''${hosts[@]}" | sort -u)

      all_links=()
      for host in "''${unique_hosts[@]}"; do
        if [[ "$host" == *:* ]]; then
          # IPv6 standard bracket formatting
          endpoint="[''${host}]"
          tag_host="''${host//:/-}"
          suffix="-IPv6-''${tag_host}"
        else
          endpoint="''${host}"
          suffix=""
          if [ "''${#unique_hosts[@]}" -gt 1 ]; then
            suffix="-''${host//./-}"
          fi
        fi

        vless="vless://''${uuid}@''${endpoint}:${toString realityPort}?flow=xtls-rprx-vision&security=reality&sni=${realitySni}&fp=chrome&pbk=${realityPublicKey}&sid=&type=tcp#OCI-VLESS-Reality''${suffix}"
        hy443="hysteria2://''${hy2_enc}@''${endpoint}:${toString realityPort}/?sni=bing.com&pinSHA256=''${cert_sha256}#OCI-Hysteria2-443''${suffix}"
        hy8443="hysteria2://''${hy2_enc}@''${endpoint}:${toString hy2Port}/?sni=bing.com&pinSHA256=''${cert_sha256}#OCI-Hysteria2-8443''${suffix}"

        all_links+=("$vless" "$hy443" "$hy8443")

        echo "# [Host: ''${host}] VLESS + Reality (TCP ${toString realityPort})"
        echo "$vless"
        echo
        echo "# [Host: ''${host}] Hysteria 2 (UDP ${toString realityPort})"
        echo "$hy443"
        echo
        echo "# [Host: ''${host}] Hysteria 2 (UDP ${toString hy2Port})"
        echo "$hy8443"
        echo
      done

      # Export base64 subscription file
      mkdir -p "${subDir}"
      printf "%s\n" "''${all_links[@]}" | ${pkgs.coreutils}/bin/base64 -w0 > "${subDir}/''${uuid}"
      chmod 644 "${subDir}/''${uuid}"

      echo "=================================================="
      echo "  📱 客户端订阅链接 (通用 Base64):"
      for h in "''${unique_hosts[@]}"; do
        if [[ "$h" == *:* ]]; then
          echo "  • IPv6: http://[''${h}]:${toString subPort}/sub/''${uuid}"
        else
          echo "  • IPv4: http://''${h}:${toString subPort}/sub/''${uuid}"
        fi
      done
      echo "=================================================="
    '')
  ];

  services.sing-box = {
    enable = true;
    package = pkgs.sing-box;
    settings = {
      log = {
        level = "warn";
        timestamp = true;
      };
      inbounds = [
        {
          type = "vless";
          tag = "vless-in";
          listen = "::";
          listen_port = realityPort;
          users = [
            {
              uuid = secretPath "singbox_uuid";
              flow = "xtls-rprx-vision";
            }
          ];
          tls = {
            enabled = true;
            server_name = realitySni;
            reality = {
              enabled = true;
              handshake = {
                server = realitySni;
                server_port = realityPort;
              };
              private_key = secretPath "singbox_reality_private_key";
            };
          };
        }
      ]
      ++ map mkHy2 [
        {
          tag = "hy2-in";
          port = hy2Port;
        }
        {
          tag = "hy2-443-in";
          port = realityPort;
        }
      ];
      dns.servers = [
        {
          type = "local";
          tag = "local";
        }
      ];
      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
      ];
      route = {
        default_domain_resolver = "local";
        rules = [
          { action = "sniff"; }
          {
            ip_is_private = true;
            action = "reject";
          }
          {
            port = 25;
            action = "reject";
          }
        ];
      };
    };
  };

  # Allow sing-box to bind to privileged ports (443) without running as root and raise fd limits
  systemd.services.sing-box.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    LimitNOFILE = 1048576;
    NoNewPrivileges = true;
    ProtectHome = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
  };

  # Lightweight Caddy server for subscription distribution
  services.caddy = {
    enable = true;
    extraConfig = ''
      :${toString subPort} {
        @sub path_regexp sub ^/sub/([a-zA-Z0-9-]+)$
        handle @sub {
          header Content-Type "text/plain; charset=utf-8"
          rewrite * /{re.sub.1}
          root * ${subDir}
          file_server
        }
        handle {
          respond 404
        }
      }
    '';
  };

  # Automatic generation of subscription file at boot / activation
  systemd.services.singbox-sub-init = {
    description = "Generate sing-box base64 subscription on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "sops-nix.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${config.system.path}/bin/singbox-links'";
      RemainAfterExit = true;
    };
  };

  # Firewall rules for sing-box and subscription
  networking.firewall = {
    allowedTCPPorts = [
      realityPort
      subPort
    ];
    allowedUDPPorts = [
      realityPort
      hy2Port
    ];
    extraCommands = ''
      # TCP MSS Clamping to prevent Path MTU black holes
      iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
      ip6tables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || ip6tables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    '';
    extraStopCommands = ''
      iptables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
      ip6tables -t mangle -D POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    '';
  };
}
