{
  lib,
  enableLanzaboote ? false,
  ...
}:
{
  boot = {
    bootspec.enable = true;
    loader = {
      systemd-boot =
        if !enableLanzaboote then
          {
            enable = true;
            consoleMode = "auto";
          }
        else
          {
            enable = lib.mkForce false;
          };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 3;
    };
    lanzaboote = lib.mkIf enableLanzaboote {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
  };
}
