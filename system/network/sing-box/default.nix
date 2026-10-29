{
  config,
  pkgs,
  ...
}:
let
  # Reality handshake target / fallback site
  realitySni = "gateway.icloud.com";
  realityPublicKey = "333ml7s4Nj9yV2jz3ZL1J-G_1OX1bb6Yk-9ALFOsqB0";
  realityPort = 443;
  hy2Port = 8443;

  # Derived from the sing-box user instead of hardcoding /var/lib/sing-box
  stateDir = config.users.users.sing-box.home;
  certFile = "${stateDir}/cert.pem";
  keyFile = "${stateDir}/key.pem";

  secretPath = name: { _secret = config.sops.secrets.${name}.path; };
in
{
  sops.secrets = {
    singbox_uuid = { };
    singbox_reality_private_key = { };
    singbox_hy2_password = { };
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "singbox-links" ''
      set -euo pipefail

      # Auto sudo if cannot read root-only secret files
      if [ "$(id -u)" -ne 0 ] && [ ! -r "${config.sops.secrets.singbox_uuid.path}" ]; then
        exec sudo "$0" "$@"
      fi
      host="''${1:-$(${pkgs.curl}/bin/curl -4s --max-time 3 https://icanhazip.com 2>/dev/null || echo "127.0.0.1")}"
      uuid=$(cat ${config.sops.secrets.singbox_uuid.path})
      hy2=$(cat ${config.sops.secrets.singbox_hy2_password.path})
      hy2_enc=$(printf %s "$hy2" | ${pkgs.jq}/bin/jq -sRr @uri)

      vless="vless://''${uuid}@''${host}:${toString realityPort}?flow=xtls-rprx-vision&security=reality&sni=${realitySni}&fp=chrome&pbk=${realityPublicKey}&type=tcp#OCI-VLESS-Reality"
      hy="hysteria2://''${hy2_enc}@''${host}:${toString hy2Port}/?sni=bing.com&insecure=1#OCI-Hysteria2"

      echo "# VLESS + Reality (TCP ${toString realityPort})"
      echo "$vless"
      echo
      echo "# Hysteria 2 (UDP ${toString hy2Port})"
      echo "$hy"
    '')
  ];

  services.sing-box = {
    enable = true;
    package = pkgs.sing-box;
    settings = {
      log = {
        level = "info";
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
        {
          type = "hysteria2";
          tag = "hy2-in";
          listen = "::";
          listen_port = hy2Port;
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
        }
      ];
      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
        {
          type = "block";
          tag = "block";
        }
      ];
      route = {
        rules = [
          {
            ip_is_private = true;
            outbound = "block";
          }
          {
            port = 25;
            outbound = "block";
          }
        ];
      };
    };
  };

  # Allow sing-box to bind to privileged ports (443) without running as root
  systemd.services.sing-box.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
  };

  # Generate self-signed certificate for Hysteria 2 before sing-box starts
  systemd.services.sing-box-certs = {
    description = "Generate self-signed certificate for sing-box Hysteria 2";
    wantedBy = [ "sing-box.service" ];
    before = [ "sing-box.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "sing-box";
      StateDirectoryMode = "0700";
    };
    script = ''
      if [ ! -f "${certFile}" ] || [ ! -f "${keyFile}" ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
          -nodes -keyout "${keyFile}" \
          -out "${certFile}" -days 3650 \
          -subj "/CN=bing.com"
        chown sing-box:sing-box "${keyFile}" "${certFile}"
        chmod 600 "${keyFile}"
        chmod 644 "${certFile}"
      fi
    '';
  };

  # Firewall rules for sing-box
  networking.firewall = {
    allowedTCPPorts = [ realityPort ];
    allowedUDPPorts = [
      realityPort
      hy2Port
    ];
    extraCommands = ''
      iptables -t nat -A PREROUTING -p udp --dport ${toString realityPort} -j REDIRECT --to-ports ${toString hy2Port} 2>/dev/null || true
      ip6tables -t nat -A PREROUTING -p udp --dport ${toString realityPort} -j REDIRECT --to-ports ${toString hy2Port} 2>/dev/null || true
    '';
    extraStopCommands = ''
      iptables -t nat -D PREROUTING -p udp --dport ${toString realityPort} -j REDIRECT --to-ports ${toString hy2Port} 2>/dev/null || true
      ip6tables -t nat -D PREROUTING -p udp --dport ${toString realityPort} -j REDIRECT --to-ports ${toString hy2Port} 2>/dev/null || true
    '';
  };
}
