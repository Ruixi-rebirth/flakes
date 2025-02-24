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
    defaultUser = "${me.userName}";
    useWindowsDriver = true;
  };

  environment = {
    systemPackages = with pkgs; [
      clipboard-jh
      fastfetch
    ];
  };

  system.stateVersion = "23.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
