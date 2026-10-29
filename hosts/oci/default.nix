{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "oci";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      443
    ];
    allowedUDPPorts = [
      443
      8443
    ];
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [ "tcp_bbr" ];
    kernelParams = [
      "console=tty1"
      "console=ttyAMA0,115200"
    ];
    kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.rmem_max" = 33554432;
      "net.core.wmem_max" = 33554432;
      "net.core.rmem_default" = 1048576;
      "net.core.wmem_default" = 1048576;
      "net.ipv4.tcp_rmem" = "4096 131072 33554432";
      "net.ipv4.tcp_wmem" = "4096 65536 33554432";
      "net.ipv4.udp_rmem_min" = 16384;
      "net.ipv4.udp_wmem_min" = 16384;
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_fastopen" = 3;
      "net.core.netdev_max_backlog" = 16384;
    };
  };

  # Enable zram swap for VPS
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
