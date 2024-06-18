{ pkgs, lib, config, ... }:
{
  boot = {
    bootspec.enable = true;
    loader = {
      systemd-boot =
        if !config.boot.lanzaboote.enable then {
          enable = true;
          consoleMode = "auto";
        } else {
          enable = lib.mkForce false;
        };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 3;
    };
    lanzaboote = {
      enable = false;
      pkiBundle = "/etc/secureboot";
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
