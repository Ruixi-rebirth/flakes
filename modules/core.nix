{
  pkgs,
  user,
  config,
  lib,
  ...
}:
{
  programs.git.enable = true;

  # NOTE: https://github.com/Mic92/sops-nix#initrd-secrets
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [ ];
    age = {
      sshKeyPaths = [ ];
      keyFile = "/var/lib/sops-nix/keys.txt"; # You must back up this keyFile yourself
      generateKey = true;
    };
    secrets = {
      Element_securityKey = {
        owner = "${user}";
        path = "/home/" + "${user}" + "/.config/element_SK/Element_securityKey";
      };
      OPENAI_API_KEY = {
        owner = "${user}";
      };
      ANTHROPIC_API_KEY = {
        owner = "${user}";
      };
    };
  };
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

  services.resolved.enable = true;
  networking = {
    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    firewall.allowedTCPPorts = [
      22 # sshd
      6600 # mpd
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

  services = {
    openssh = {
      enable = true;
    };
    dbus.enable = true;
  };

  environment = {
    binsh = "${pkgs.dash}/bin/dash";
    shells = with pkgs; [ fish ];
    systemPackages = with pkgs; [
      gcc
      clang
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
      rustscan
      onefetch
      jq
    ];
  };

  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = "$6$lxmdznvXPgvRA.uq$R7Up1Eo1lrhaAbAGizrj/0dsbcU9DGKKVKLsA3bCrGYWkw/NkaQT.s41xTSqFkBZDXbucV00T2nN652D36AyG0";
  };
  programs.fish = {
    enable = lib.mkIf (config.networking.hostName != "minimal") true;
    shellInit = ''
      export ANTHROPIC_API_KEY="$(cat ${config.sops.secrets.ANTHROPIC_API_KEY.path})"
      export OPENAI_API_KEY="$(cat ${config.sops.secrets.OPENAI_API_KEY.path})"
    '';
  };
  users.users.${user} = {
    initialHashedPassword = "$6$lxmdznvXPgvRA.uq$R7Up1Eo1lrhaAbAGizrj/0dsbcU9DGKKVKLsA3bCrGYWkw/NkaQT.s41xTSqFkBZDXbucV00T2nN652D36AyG0";
    shell = lib.mkIf (config.networking.hostName != "minimal") pkgs.fish or pkgs.bash;
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo = {
      enable = true;
      extraConfig = ''
        ${user} ALL=(ALL) NOPASSWD:ALL
      '';
    };
    doas = {
      enable = true;
      extraConfig = ''
        permit nopass :wheel
      '';
    };
  };

  system.stateVersion = "23.11";
}
