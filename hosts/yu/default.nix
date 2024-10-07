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
    nativeSystemd = true;
  };

  environment = {
    systemPackages = with pkgs; [
      clipboard-jh
      fastfetch
    ];
  };

  sops = {
    secrets.SSH_PVKEY = {
      mode = "0600";
      owner = "${me.userName}";
      path = "/home/" + "${me.userName}" + "/.ssh/id_ed25519";
    };
    secrets.GPG_PVKEY = {
      mode = "0600";
      owner = "${me.userName}";
      path = "/home/" + "${me.userName}" + "/.gnupg/GPG_PVKEY";
    };
  };

  system.stateVersion = "23.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
