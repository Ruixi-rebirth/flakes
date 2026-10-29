{
  pkgs,
  me,
  ...
}:
{
  imports = [
    ./security.nix
    ./user.nix
    ./nix-ld.nix
    ../programs/cli.nix
  ];

  programs.git = {
    enable = true;
    config = {
      user = {
        name = me.githubUserName;
        email = me.email;
      };
      safe.directory = [ "*" ];
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
    shells = [ pkgs.fish ];
  };

  programs.fish.enable = true;

  services.xserver = {
    xkb.options = "caps:escape";
  };
  console.useXkbConfig = true;

  system.stateVersion = "26.05";
}
