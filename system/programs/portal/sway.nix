{
  config,
  lib,
  me,
  pkgs,
  ...
}:
let
  swayEnabled = lib.attrByPath [
    "home-manager"
    "users"
    me.userName
    "wayland"
    "windowManager"
    "sway"
    "enable"
  ] false config;
in
lib.mkIf swayEnabled {
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "dmenu";
        chooser_cmd = "${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt='Share: ' --minimal-lines";
      };
    };
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = "wlr";
      "org.freedesktop.impl.portal.Screenshot" = "wlr";
      "org.freedesktop.impl.portal.Inhibit" = "none";
    };
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
