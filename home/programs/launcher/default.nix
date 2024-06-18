{ pkgs, ... }:
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
  };
  home.file = {
    ".config/rofi/off.sh".source = ./off.sh;
    ".config/rofi/launcher.sh".source = ./launcher.sh;
    ".config/rofi/launcher_theme.rasi".source = ./launcher_theme.rasi;
    ".config/rofi/powermenu.sh".source = ./powermenu.sh;
    ".config/rofi/powermenu_theme.rasi".source = ./powermenu_theme.rasi;
  };
}
