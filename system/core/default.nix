{
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./security.nix
    ./sops.nix
    ./user.nix
  ];

  programs.git.enable = true;

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

  programs.fish = {
    enable = true;
    shellInit = ''
      export ANTHROPIC_API_KEY="$(cat ${config.sops.secrets.ANTHROPIC_API_KEY.path})"
      export OPENAI_API_KEY="$(cat ${config.sops.secrets.OPENAI_API_KEY.path})"
      export Config_dae="$(cat ${config.sops.secrets."config.dae".path})"
      export Element_securityKey="$(cat ${config.sops.secrets."Element_securityKey".path})"
      export CACHIX_AUTH_TOKEN="$(cat ${config.sops.secrets.CACHIX_AUTH_TOKEN.path})"
      export CACHIX_SIGNING_KEY="$(cat ${config.sops.secrets.CACHIX_SIGNING_KEY.path})"
      export GITHUB_TOKEN="$(cat ${config.sops.secrets.GITHUB_TOKEN.path})"
      export SSH_PVKEY="$(cat ${config.sops.secrets.SSH_PVKEY.path})"
      export GPG_PVKEY="$(cat ${config.sops.secrets.GPG_PVKEY.path})"
    '';
  };

  services.xserver = {
    xkb.options = "caps:escape";
  };
  console.useXkbConfig = true;

  system.stateVersion = "23.11";
}
