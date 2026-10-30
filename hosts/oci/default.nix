{ pkgs, ... }:
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
  };

  networking = {
    hostName = "oci";
    dhcpcd.extraConfig = ''
      nooption interface_mtu
    '';
    firewall.enable = true;
  };

  time.timeZone = "UTC";

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
      "net.core.rmem_max" = 33554432;
      "net.core.wmem_max" = 33554432;
      "net.ipv4.tcp_rmem" = "4096 131072 33554432";
      "net.ipv4.tcp_wmem" = "4096 65536 33554432";

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

  environment.systemPackages = with pkgs; [
    antigravity-cli
  ];
}
