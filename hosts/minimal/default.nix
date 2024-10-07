{ pkgs, me, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "minimal";

  sops = {
    secrets.SSH_PVKEY = {
      mode = "0600";
      owner = "${me.userName}";
      path = "/home/" + "${me.userName}" + "/.ssh/id_ed25519"; # ssh-keygen -y -f id_ed25519 > id_ed25519.pub
    };
    secrets.GPG_PVKEY = {
      mode = "0600";
      owner = "${me.userName}";
      path = "/home/" + "${me.userName}" + "/.gnupg/GPG_PVKEY"; # gpg --import GPG_PVKEY
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelParams = [
      "quiet"
      "splash"
    ];
  };
}
