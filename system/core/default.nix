{
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./security.nix
    ./user.nix
  ];

  programs.git.enable = true;

  programs.nix-ld.enable = true;

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
      nix-tree
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
      tldr
    ];
  };

  programs.fish.enable = true;

  services.xserver = {
    xkb.options = "caps:escape";
  };
  console.useXkbConfig = true;

  system.stateVersion = "23.11";
}
