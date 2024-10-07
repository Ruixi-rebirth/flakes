{ config, pkgs, user, lib, ... }:
{
  networking.hostName = "yu";

  wsl = {
    enable = true;
    defaultUser = user;
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
      owner = "${user}";
      path = "/home/" + "${user}" + "/.ssh/id_ed25519";
    };
    secrets.GPG_PVKEY = {
      mode = "0600";
      owner = "${user}";
      path = "/home/" + "${user}" + "/.gnupg/GPG_PVKEY";
    };
  };

  system.stateVersion = "23.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
