{
  config,
  pkgs,
  me,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../lib/disko_layout/single-device-ext4.nix
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [ ];
    age = {
      sshKeyPaths = [ ];
      keyFile = "/var/lib/sops-nix/keys.txt";
    };
    secrets = {
      "daidai.yaml".owner = me.userName;
    };
  };

  networking = {
    hostName = "oci";
    dhcpcd.extraConfig = ''
      nooption interface_mtu
    '';
    firewall.enable = true;
  };
  time.timeZone = "Asia/Singapore";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "tcp_bbr" ];
    kernelParams = [
      "console=tty1"
      "console=ttyAMA0,115200"
    ];
    kernel.sysctl = {
      # BBR congestion control requires FQ (Fair Queueing) packet pacing
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # TCP window buffers tuned for BDP (1 Gbps @ 250ms RTT ≈ 31.25 MB)
      # rmem_max / wmem_max 设置 OS 级别的 socket 缓冲区上限 (32MB)
      "net.core.rmem_max" = 33554432;
      "net.core.wmem_max" = 33554432;

      # 设定所有新建 socket 默认接收/发送缓冲区大小 (32MB，与 rmem_max/wmem_max 一致)
      # 依据：针对高带宽长肥管道（BDP 场景），确保非显式通过 setsockopt 设置 SO_RCVBUF/SO_SNDBUF 的应用，
      # 以及 UDP 等无自动调优机制的协议直接享有充足的初始缓冲区，避免突发吞吐时发生拥塞丢包
      "net.core.rmem_default" = 33554432;
      "net.core.wmem_default" = 33554432;

      "net.ipv4.tcp_rmem" = "4096 131072 33554432";
      "net.ipv4.tcp_wmem" = "4096 65536 33554432";

      # 启用 RFC 1323 TCP 窗口缩放 (Window Scaling)
      # 依据：标准 TCP 首部的接收窗口字段仅有 16 位，最大只支持 64KB (65535 字节) 窗口大小。
      # 在高 BDP 网络下，未开启窗口缩放会导致吞吐量受限于 64KB / RTT；
      # 开启后可通过比例因子将滑动窗口扩大至最大 1GB，使 TCP 能够充分利用上方配置的 32MB 缓冲区
      "net.ipv4.tcp_window_scaling" = 1;

      # UDP 内存全局配额调节参数：[min, pressure, max]（单位：内存页 Page，Linux 常规页为 4KB）
      # 计算逻辑：
      # - min (131072 页 = 512MB)：进入内存自动调节的门限，低于此配额时不进行内存回收或限制
      # - pressure (262144 页 = 1024MB / 1GB)：内核开始对 UDP socket 进行内存加压并限制缓冲区分配
      # - max (1048576 页 = 4096MB / 4GB)：整个系统分配给 UDP 协议栈的最大内存硬上限
      # 设定依据：本机部署 Hysteria 2 / TUIC / QUIC 等基于 UDP 的高吞吐代理，
      # 默认 UDP 内存限制较低容易在大并发与高带宽跑满时触发 UDP 丢包，此配置为 UDP 协议栈预留充足缓冲空间
      "net.ipv4.udp_mem" = "131072 262144 1048576";

      # Prevent cwnd collapse during idle intervals between video segment downloads
      "net.ipv4.tcp_slow_start_after_idle" = 0;

      # RFC 4821 PLPMTUD: dynamically detect and recover from Path MTU black holes
      "net.ipv4.tcp_mtu_probing" = 1;

      # Enable TCP Fast Open for both client and server (saves 1 RTT during handshake)
      "net.ipv4.tcp_fastopen" = 3;

      # Queue depth for burst traffic on high-bandwidth NIC
      "net.core.netdev_max_backlog" = 16384;
      "net.core.somaxconn" = 8192;
      "net.ipv4.tcp_max_syn_backlog" = 8192;

      # Fast cleanup of dead TCP connections (5 min instead of 2 hours default)
      "net.ipv4.tcp_keepalive_time" = 300;
      "net.ipv4.tcp_keepalive_intvl" = 30;
      "net.ipv4.tcp_keepalive_probes" = 5;
    };
  };

  # Key-only SSH: the host is public-facing
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
    KbdInteractiveAuthentication = false;
  };

  # Enable zram swap for VPS
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Prevent kernel lockup and SSH freeze under severe memory pressure
  services.earlyoom.enable = true;

  environment.systemPackages = with pkgs; [
    antigravity-cli
    codex
    yazi
  ];

  services.singbox-sub = {
    enable = true;
    publicDomain = "fq.${me.domain}";
  };

  services.daidai = {
    enable = true;
    configFile = config.sops.secrets."daidai.yaml".path;
  };

  systemd.services.daidai = {
    serviceConfig.User = me.userName;
    environment.HOME = "/home/${me.userName}";
  };
}
