{ pkgs, user, config, lib, ... }:
{
  # NOTE: https://github.com/Mic92/sops-nix#initrd-secrets
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.age.sshKeyPaths = [ ];
  sops.gnupg.sshKeyPaths = [ ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt"; # You must back up this keyFile yourself
  sops.age.generateKey = true;
  # issue: https://github.com/Mic92/sops-nix/issues/149
  # workaround:
  systemd.services.decrypt-sops = {
    description = "Decrypt sops secrets";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "2s";
    };
    script = config.system.activationScripts.setupSecrets.text;
  };

  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [
      22 #sshd
      6600 #mpd
    ];
    hosts = {
      "185.199.109.133" = [ "raw.githubusercontent.com" ];
      "185.199.111.133" = [ "raw.githubusercontent.com" ];
      "185.199.110.133" = [ "raw.githubusercontent.com" ];
      "185.199.108.133" = [ "raw.githubusercontent.com" ];
    };
  };

  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ALL = "en_US.UTF-8";
      LANGUAGE = "en_US.UTF-8";
    };
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
    ];
  };

  security.rtkit.enable = true;
  services = {
    openssh = {
      enable = true;
    };
  };

  environment = {
    binsh = "${pkgs.dash}/bin/dash";
    shells = with pkgs; [ fish ];
    systemPackages = with pkgs; [
      gcc
      clang
      git
      gdb
      neovim
      wget
      neofetch
      eza
      p7zip
      atool
      unzip
      zip
      rar
      ffmpeg
      xdg-utils
      pciutils
      killall
      socat
      sops
      lsof
    ];
  };
  services.dbus.enable = true;

  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = "$6$b7YjMXfdES4soCMc$UTQMG0Zft.fXs4q1aXp69z8/sfKkKWu8dt/ZN5oj5ifyJ/vIdMpiX09jQ1T8kRli3Pb2zMpPKvpxFfgHXzo9V0";
  };
  programs.fish.enable = true;
  users.users.${user} = {
    initialHashedPassword = "$6$b7YjMXfdES4soCMc$UTQMG0Zft.fXs4q1aXp69z8/sfKkKWu8dt/ZN5oj5ifyJ/vIdMpiX09jQ1T8kRli3Pb2zMpPKvpxFfgHXzo9V0";
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" ];
  };

  security.polkit.enable = true;
  security.sudo = {
    enable = true;
    extraConfig = ''
      ${user} ALL=(ALL) NOPASSWD:ALL
    '';
  };
  security.doas = {
    enable = true;
    extraConfig = ''
      permit nopass :wheel
    '';
  };

  system.stateVersion = "23.11";
}
