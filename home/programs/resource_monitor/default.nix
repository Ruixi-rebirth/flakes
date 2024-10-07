{ pkgs, ... }:
{
  programs = {
    btop = {
      enable = true;
      settings = {
        color_theme = "nord";
      };
    };
  };
  home.file = {
    ".config/btop/themes/nord.theme".source = ./theme.nix;
  };
}
