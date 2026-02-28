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

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    zstd
    openssl
    curl
    expat
    nss
    nspr
    icu
    libssh
    libxml2
    libusb1
    util-linux
    systemd
    libsodium
    attr
    xz
    bzip2
    acl
    # Graphics and rendering libraries
    libX11
    libXext
    libXdamage
    libXfixes
    libXcomposite
    libXcursor
    libXrender
    libXrandr
    libXi
    libXtst
    libXinerama
    libXScrnSaver
    libXv
    libxkbcommon
    libxkbfile
    libxcb
    libSM
    libICE
    libGL
    pulseaudio
    vulkan-loader
    alsa-lib
    dbus
    glib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    gdk-pixbuf
    pango
    gtk3
    libpng
    libbsd
    fontconfig
    freetype
    libdrm
    libgbm
    mesa
    wayland
    udev
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
    shells = [ pkgs.fish ];
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
      gptfdisk
      just
    ];
  };

  programs.fish.enable = true;

  services.xserver = {
    xkb.options = "caps:escape";
  };
  console.useXkbConfig = true;

  system.stateVersion = "25.11";
}
