{
  pkgs,
  me,
  lib,
  ...
}:
{
  networking.hostName = "yu";

  wsl = {
    enable = true;
    defaultUser = me.userName;
    useWindowsDriver = true;
  };

  environment = {
    systemPackages = with pkgs; [
      clipboard-jh
      fastfetch
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
