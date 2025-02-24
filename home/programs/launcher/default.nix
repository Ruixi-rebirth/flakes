{ pkgs, appearance, ... }:
{
  programs.rofi = {
    enable = true;
  };
  home.packages = with pkgs; [
    rofi-calc
    rofi-emoji
    rofi-nerdy
  ];
  home.file = {
    ".config/rofi/off.sh".source = ./off.sh;
    ".config/rofi/clipboard.sh".source = ./clipboard.sh;
    ".config/rofi/launcher.sh".source = ./launcher.sh;
    ".config/rofi/powermenu.sh".source = ./powermenu.sh;
    ".config/rofi/launcher_theme.rasi".text = import ./launcher_theme.nix { inherit appearance; };
    ".config/rofi/powermenu_theme.rasi".text = import ./powermenu_theme.nix { inherit appearance; };
    ".config/rofi/clipboard_theme.rasi".text = import ./clipboard_theme.nix { inherit appearance; };
  };
}
