{ pkgs, ... }:
{
  imports = [ ./config.nix ];

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  home.packages = with pkgs;[
    sway-contrib.grimshot
    swaylock-effects
    pamixer
    swayidle
  ];

  systemd.user = {
    targets.sway-session.Unit.Wants = [ "xdg-desktop-autostart.target" ];
  };

  home = {
    sessionVariables = {
      QT_SCALE_FACTOR = "1";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      CLUTTER_BACKEND = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
      XDG_SESSION_DESKTOP = "sway";
      XDG_SESSION_TYPE = "wayland";
    };
  };
}
