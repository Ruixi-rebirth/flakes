{ pkgs, ... }:
{
  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    extest.enable = true;
    package = pkgs.steam.override {
      extraPkgs =
        pkgs: with pkgs; [
          wqy_zenhei
          nss
          nspr
          libxkbfile
          xcb-util-cursor
          libxkbcommon
          libGL
          dbus
          # Additional XCB and Qt-related dependencies for the emulator
          xorg.xcbutil
          xorg.xcbutilwm
          xorg.xcbutilimage
          xorg.xcbutilkeysyms
          xorg.xcbutilrenderutil
          qt5.qtwayland
          libpulseaudio
          alsa-lib
          android-tools
        ];
    };
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
  environment.systemPackages = [
    pkgs.protontricks
  ];
}
