{
  config,
  pkgs,
  lib,
  me,
  ...
}:
let
  cfgSub = config.services.singbox-sub;

  # Reality handshake target / fallback site
  realitySni = "gateway.icloud.com";
  # Reality 公钥 (由 `nix shell nixpkgs#sing-box -c sing-box generate reality-keypair` 生成，PublicKey 填入此处，PrivateKey 存入 sops 的 singbox_reality_private_key)
  realityPublicKey = "333ml7s4Nj9yV2jz3ZL1J-G_1OX1bb6Yk-9ALFOsqB0";
  realityPort = 443;
  hy2Port = 8443;
  subPort = cfgSub.port;
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
  options.services.singbox-sub = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "启用本地 Caddy 订阅服务";
    };
    publicDomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "公网分发域名 (如 Cloudflare Worker 自定义域，为空时不输出)";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2080;
      description = "本地 Caddy 订阅服务监听端口";
    };
  };

  config = {
    # ============================================================================
    # 密钥体系说明 (Sops-nix 加密存储在 secrets/secrets.yaml):
    # - singbox_uuid:
    #   - 生成命令: `nix shell nixpkgs#sing-box -c sing-box generate uuid`
    #   - 双重关联作用:
    #     1) 作为 VLESS Reality 节点的客户端用户连接鉴权 UUID；
    #     2) 直接复用为 Caddy 订阅端点的防探测密钥路径 (/sub/<uuid>)，杜绝全网暴力嗅探。
    # - singbox_reality_private_key:
    #   - 生成命令: `nix shell nixpkgs#sing-box -c sing-box generate reality-keypair`
    #   - 对应的 PublicKey 填入文件顶部的 realityPublicKey 变量。
    # - singbox_hy2_password:
    #   - 生成命令: `nix shell nixpkgs#sing-box -c sing-box generate rand --base64 16`
    # - singbox_hy2_cert / singbox_hy2_key:
    #   - Hysteria 2 自签证书与私钥，通过 openssl 生成并存入 sops，详见 secrets/README.md。
    # ============================================================================
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

      output_json=false
      export_sub=false
      positional_hosts=()
      sub_domain="${cfgSub.publicDomain}"
      while [ $# -gt 0 ]; do
        case "$1" in
          --json|-j)
            output_json=true
            shift
            ;;
          --export)
            export_sub=true
            shift
            ;;
          --domain|-d)
            sub_domain="$2"
            shift 2
            ;;
          *)
            positional_hosts+=("$1")
            shift
            ;;
        esac
      done

      uuid=$(cat ${config.sops.secrets.singbox_uuid.path})
      hy2=$(cat ${config.sops.secrets.singbox_hy2_password.path})
      hy2_enc=$(printf %s "$hy2" | ${pkgs.jq}/bin/jq -sRr @uri)
      cert_sha256=$(${pkgs.openssl}/bin/openssl x509 -noout -fingerprint -sha256 -in "${certFile}" 2>/dev/null | cut -d= -f2 | tr -d :)

      # Discover all public IP addresses (IPv4 & IPv6)
      if [ "''${#positional_hosts[@]}" -gt 0 ]; then
        hosts=("''${positional_hosts[@]}")
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
      nodes_json_entries=()
      sub_urls_json_entries=()
      if [ -n "$sub_domain" ]; then
        sub_urls_json_entries+=("\"public\": \"https://''${sub_domain}/sub/''${uuid}\"")
      fi

      for host in "''${unique_hosts[@]}"; do
        if [[ "$host" == *:* ]]; then
          endpoint="[''${host}]"
          tag_host="''${host//:/-}"
          suffix="-IPv6-''${tag_host}"
          sub_url="http://[''${host}]:${toString subPort}/sub/''${uuid}"
          sub_urls_json_entries+=("\"ipv6\": \"''${sub_url}\"")
        else
          endpoint="''${host}"
          suffix=""
          if [ "''${#unique_hosts[@]}" -gt 1 ]; then
            suffix="-''${host//./-}"
          fi
          sub_url="http://''${host}:${toString subPort}/sub/''${uuid}"
          sub_urls_json_entries+=("\"ipv4\": \"''${sub_url}\"")
        fi

        tag_vless="OCI-VLESS-Reality''${suffix}"
        tag_hy443="OCI-Hysteria2-443''${suffix}"
        tag_hy8443="OCI-Hysteria2-8443''${suffix}"

        vless="vless://''${uuid}@''${endpoint}:${toString realityPort}?flow=xtls-rprx-vision&security=reality&sni=${realitySni}&fp=chrome&pbk=${realityPublicKey}&sid=&type=tcp#''${tag_vless}"
        hy443="hysteria2://''${hy2_enc}@''${endpoint}:${toString realityPort}/?sni=bing.com&pinSHA256=''${cert_sha256}#''${tag_hy443}"
        hy8443="hysteria2://''${hy2_enc}@''${endpoint}:${toString hy2Port}/?sni=bing.com&pinSHA256=''${cert_sha256}#''${tag_hy8443}"

        all_links+=("$vless" "$hy443" "$hy8443")

        nodes_json_entries+=(
          "{\"tag\": \"''${tag_vless}\", \"type\": \"vless\", \"protocol\": \"tcp\", \"host\": \"''${host}\", \"port\": ${toString realityPort}, \"url\": \"''${vless}\"}"
          "{\"tag\": \"''${tag_hy443}\", \"type\": \"hysteria2\", \"protocol\": \"udp\", \"host\": \"''${host}\", \"port\": ${toString realityPort}, \"url\": \"''${hy443}\"}"
          "{\"tag\": \"''${tag_hy8443}\", \"type\": \"hysteria2\", \"protocol\": \"udp\", \"host\": \"''${host}\", \"port\": ${toString hy2Port}, \"url\": \"''${hy8443}\"}"
        )
      done

      # Export base64 subscription file for Caddy (only when explicitly requested)
      if [ "$export_sub" = true ]; then
        mkdir -p "${subDir}"
        printf "%s\n" "''${all_links[@]}" | ${pkgs.coreutils}/bin/base64 -w0 > "${subDir}/''${uuid}"
        chmod 644 "${subDir}/''${uuid}"
      fi

      if [ "$output_json" = true ]; then
        # Structured JSON output
        sub_obj="{"$(IFS=,; echo "''${sub_urls_json_entries[*]}")"}"
        nodes_arr="["$(IFS=,; echo "''${nodes_json_entries[*]}")"]"
        ${pkgs.jq}/bin/jq -n \
          --arg uuid "$uuid" \
          --argjson sub "$sub_obj" \
          --argjson nodes "$nodes_arr" \
          '{
            uuid: $uuid,
            subscription_urls: $sub,
            node_count: ($nodes | length),
            nodes: $nodes
          }'
      else
        # Clean plain output
        echo "# Subscription"
        if [ -n "$sub_domain" ]; then
          echo "https://''${sub_domain}/sub/''${uuid}"
        fi
        for h in "''${unique_hosts[@]}"; do
          if [[ "$h" == *:* ]]; then
            echo "http://[''${h}]:${toString subPort}/sub/''${uuid}"
          else
            echo "http://''${h}:${toString subPort}/sub/''${uuid}"
          fi
        done
        echo
        echo "# Nodes"
        printf "%s\n" "''${all_links[@]}"
      fi
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
              # 此处使用的 uuid 即 sops 中的 singbox_uuid，与订阅分发路径 /sub/<uuid> 完全一致
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

  # ============================================================================
  # 订阅服务架构与 Cloudflare Worker 反向代理配置指南
  # ============================================================================
  # 为了避免境内 GFW 阻断及扫描 VPS 端口，同时为客户端提供标准、高可用的 HTTPS 订阅，
  # 本节点架构采用「本地 Caddy 静态生成 + Cloudflare Worker 前端分发」模式：
  #
  # 1. 节点与订阅生成:
  #    - singbox-links --export 会根据当前的 sops 密钥与动态 IP 自动生成 Base64 订阅文件，
  #      存放在 /var/lib/sing-box-sub/<uuid>（路径仅包含 UUID 密钥，防止路径扫描）。
  #    - 本机 Caddy 仅监听内部 HTTP 端口 (2080)，只响应 /sub/<uuid>，其它访问一律返回 404。
  #
  # 2. Cloudflare Worker + 自定义域名部署流程 (重要运维记录):
  #    第 1 步: 创建 Cloudflare Worker
  #      - 新建 Worker (如 fq-subscript)，编写透明代理脚本：
  #        const subscriptURL = "http://vps.ruixi2fp.top:2080";
  #        export default {
  #          async fetch(request) {
  #            const url = new URL(request.url);
  #            return fetch(subscriptURL + url.pathname);
  #          }
  #        };
  #
  #    第 2 步: 配置源站 DNS 解析记录 (灰云 / 仅 DNS)
  #      - 在 Cloudflare DNS 新增一条 A 记录（例如 vps.ruixi2fp.top），指向 VPS 真实公网 IPv4。
  #      - 【关键注意】: 代理状态必须设为「仅 DNS / 灰色云朵」，切勿开启橙色代理！
  #        原因: Cloudflare 的公网边缘反向代理仅支持 80/443 等标准端口；
  #        而灰云解析允许 Worker 直接通过源站的 2080 端口与 VPS 的 Caddy 建立回源 TCP 连接。
  #
  #    第 3 步: 绑定前端自定义域 (Custom Domain，非路由 Route)
  #      - 进入 Worker 页面 ->「设置 (Settings)」->「域和路由 (Domains & Routes)」。
  #      - 点击「添加 (Add)」-> 选择「自定义域 (Custom Domain)」，输入公共订阅域名 (如 fq.ruixi2fp.top)。
  #      - 【关键注意】: 务必使用「自定义域」而非「路由 (Route)」:
  #        自定义域能全自动托管 DNS、颁发 SSL 证书，并天然支持通配所有子路径 (/*)，
  #        避免了路由模式下因未写通配符导致 /sub/<uuid> 匹配失败而触发 522 超时的问题。
  #
  # 3. 最终通用订阅链接:
  #    https://fq.ruixi2fp.top/sub/<uuid>
  # ============================================================================

  # Lightweight Caddy server for subscription distribution
  services.caddy = lib.mkIf cfgSub.enable {
    enable = true;
    extraConfig = ''
      :${toString subPort} {
        # 路径关联: 提取 /sub/<uuid> 中的 UUID (即 sops 中的 singbox_uuid)，重写映射到磁盘静态文件
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
  systemd.services.singbox-sub-init = lib.mkIf cfgSub.enable {
    description = "Generate sing-box base64 subscription on boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "sops-nix.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.system.path}/bin/singbox-links --export";
      RemainAfterExit = true;
    };
  };

  # Firewall rules for sing-box and subscription
  networking.firewall = {
    allowedTCPPorts = [
      realityPort
    ] ++ lib.optional cfgSub.enable subPort;
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
};
}
