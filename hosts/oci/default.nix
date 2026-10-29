{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "oci";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "console=tty1"
      "console=ttyAMA0,115200"
    ];
  };

  # Enable zram swap for VPS
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
