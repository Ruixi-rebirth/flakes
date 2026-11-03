{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../lib/disko_layout/single-device-luks.nix
  ];

  networking.hostName = "minimal";

  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelParams = [
      "quiet"
      "splash"
    ];
  };
}
